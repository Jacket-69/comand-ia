# Seguridad — baseline

> Controles, responsabilidades y manejo de secretos. Consolida SRS § 4.5, ARCHITECTURE § 6 (RLS) y la política de secretos del repo. Decisión clave: [ADR-0005](../architecture/decisions/0005-multi-tenancy-rls-deny-by-default.md).

## Reglas no negociables

- **Secretos fuera del repo.** GitHub Secrets para CI; `--dart-define-from-file=.env` para local. `.env.example` documenta los nombres, no los valores. Nunca commitear `.env*`.
- **Principio de menor privilegio.** Las anon keys de Supabase no permiten operaciones de admin. Las service role keys se usan solo en CI (workflows) y en seeds locales.
- **Validar input en el backend.** En tipo BaaS-only, "el backend" es la combinación de **RLS + checks de schema + RPCs SECURITY DEFINER**. El frontend valida para UX; Postgres valida para seguridad.
- **Autorización por recurso.** Todo acceso a datos pasa por RLS deny-by-default por `venue_id`. Nada asume "el usuario está autenticado, así que puede ver todo".
- **No loggear PIN, JWT, payload completo de pedidos con datos del cliente.** Si hace falta logear que algo pasó, logear el evento con identificadores opacos (`venue_id`, `order_id`).
- **HTTPS obligatorio** en todos los entornos, incluido staging.
- **Migraciones SQL forward-only en MVP** (RNF-SEC-005).

## Aplicación al stack

### Multi-tenant deny-by-default (RLS)

Toda tabla con datos de negocio tiene `venue_id` y RLS habilitada con al menos una policy USING. Detalle en [database/rls.md](../database/rls.md). Verificación pgTAP nightly (ACID-5).

```sql
CREATE POLICY "venue_isolation" ON <tabla>
  USING (venue_id = current_venue_id());
```

### PIN de garzón

- Hash con `pgcrypto.crypt()`. Nunca en texto plano (RNF-SEC-003, ACID-6).
- Tabla `staff_pin` con SELECT bloqueado completamente — el cliente no puede leer `pin_hash`.
- Validación vía RPC `verify_pin(venue_id, pin, display_name)` SECURITY DEFINER.
- Bloqueo tras 5 intentos fallidos consecutivos (RF-AUTH-003): el RPC retorna `auth_status = blocked`.

### Magic link (owner)

- Supabase Auth (GoTrue). Link expira en 24 h.
- TLS obligatorio en el envío del email (configuración Supabase, no del repo).

### Credenciales y tokens

| Secreto | Dónde vive | Rotación |
|---|---|---|
| `SUPABASE_ANON_KEY` | GitHub Secrets + `.env` local | Cuando rota Supabase. |
| `SUPABASE_SERVICE_ROLE_KEY` | GitHub Secrets (solo workflows) | Manual al cierre de semestre o si hay leak. |
| `SUPABASE_DB_PASSWORD` | GitHub Secrets | Manual al cierre de semestre o si hay leak. |
| `SENTRY_DSN` | GitHub Secrets + `.env` local | Solo si Sentry o GitGuardian detecta leak. |
| `SENTRY_AUTH_TOKEN` | GitHub Secrets | Manual al cierre de semestre. |
| `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID` | GitHub Secrets | Manual al cierre de semestre. |
| `CODECOV_TOKEN` | GitHub Secrets | Solo si hay leak. |

Si alguien commitea por error un secreto:

1. Rotar el secreto inmediatamente.
2. Eliminar del historial con `git filter-repo` o `bfg-repo-cleaner` si la rama se pushó.
3. Documentar el incidente en `CHANGELOG.md` (sección Security).
4. Revisar lefthook + secret scan para entender por qué no lo cazó.

## Verificaciones automáticas

- **Secret scan en CI** (en `analyze-and-test`):
  ```bash
  ! git grep -nE 'BEGIN (RSA|OPENSSH|PRIVATE) KEY|sk-[A-Za-z0-9]{20,}|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}' -- ':!pubspec.lock'
  ```
- **pgTAP nightly** sobre `pg_policies` — toda tabla con `venue_id` tiene policy.
- **pgTAP cross-venue** — token de venue B no ve datos de venue A.
- **pgTAP `staff_pin`** — SELECT directo sobre `pin_hash` retorna 0 filas.

## Threat modeling

**STRIDE formal queda en opt-out por contexto académico** (ver [opt-outs académicos](../../README.md#metodología-aplicada)). En su reemplazo, el equipo aplica un check informal **antes de mergear features que tocan auth, datos del cliente o el contrato del backend**:

| STRIDE | Pregunta | Respuesta esperada en COMAND-IA |
|---|---|---|
| Spoofing | ¿Pueden suplantar al usuario? | Auth Supabase + RPC `verify_pin()` con bloqueo de 5 intentos. |
| Tampering | ¿Pueden alterar datos en tránsito o reposo? | TLS para todas las conexiones; triggers SQL para invariantes (ACID-2..4). |
| Repudiation | ¿Pueden negar haber hecho la operación? | `audit_log` (mínimo en MVP) registra mutaciones importantes. |
| Information disclosure | ¿Pueden ver datos que no deberían? | RLS deny-by-default por `venue_id`; `staff_pin` con SELECT bloqueado. |
| Denial of service | ¿Pueden tirar el sistema? | Rate limiting de Supabase (free tier); backoff exponencial en sync. |
| Elevation of privilege | ¿Pueden ganar permisos extra? | RLS valida policy en cada query; `verify_pin()` retorna sesión limitada por rol. |

Si una feature crítica futura justifica STRIDE formal, escribir `docs/security/threat-model.md` con el análisis específico (la matriz lo lista como "aplica con foco en RLS" para BaaS-only).

## OWASP Top 10 — cobertura

Cubrimos los puntos relevantes para el tipo de proyecto:

- **A01 Broken Access Control** — RLS deny-by-default + RPC SECURITY DEFINER. Cubierto por pgTAP cross-venue.
- **A02 Cryptographic Failures** — TLS forzado; PIN con `pgcrypto.crypt()`; sin almacenamiento local de tokens en plano.
- **A03 Injection** — supabase-dart SDK usa parámetros tipados (sin string concat). Las RPCs usan plpgsql tipado.
- **A04 Insecure Design** — multi-tenant by default desde Sprint 1, no "después".
- **A05 Security Misconfiguration** — CORS y políticas vienen del proveedor; revisamos al deploy. Free tier mantiene defaults razonables.
- **A07 Identification and Authentication Failures** — bloqueo tras 5 intentos; magic link con expiración 24 h.
- **A09 Logging Insufficient** — `audit_log` mínimo + Sentry para excepciones.

OWASP SAMM queda en opt-out total para academia.

## Datos sensibles

- **Datos del cliente final del local** (nombres, emails) → no se almacenan en MVP. Las mesas son anónimas.
- **PIN de garzón** → hash + bloqueado, jamás en logs (ver arriba).
- **Email del owner** → almacenado en `auth.users` (gestión Supabase) y referenciado en `app_user`. Sin extracción a logs.
- **Imágenes de menú** → almacenadas en bucket `menu-images` con URL firmada por TTL.

## Referencias

- [SRS § 4.5 Security](../requirements/srs.md) — RNF-SEC-001..005.
- [database/rls.md](../database/rls.md) — policies por tabla.
- [database/model.md](../database/model.md) — schema y triggers.
- [api/contracts.md](../api/contracts.md) — RPCs SECURITY DEFINER.
- [operations/observability.md](../operations/observability.md) — qué se loguea y qué no.
- [release-process.md](../devops/release-process.md) — manejo de variables por entorno.
- Threat model — opt-in (ver README § Metodología aplicada): análisis STRIDE por feature crítica cuando aplique.
- Gestión de secretos — secrets fuera del repo: detalle de rotación cuando aplique.
