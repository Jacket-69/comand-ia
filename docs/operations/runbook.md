# Runbook — COMAND-IA

> Qué hacer cuando algo se rompe. **Reducido al alcance BaaS-only**: cubrimos lo que controlamos (frontend + migraciones + tags) y dejamos al proveedor lo que él opera. Para el flujo normal de release ver [release-process.md](../devops/release-process.md).

## Health checks

| Check | URL / Comando | Respuesta esperada |
|---|---|---|
| App web staging | `curl -I https://staging.comand-ia.app` | HTTP 200 |
| App web prod | `curl -I https://comand-ia.app` | HTTP 200 |
| Edge function `/health` | `curl https://<supabase-url>/functions/v1/health` | `{"status":"ok","ts":"..."}` |
| Supabase Dashboard | Login al panel | Sin alertas en banner. |

uptimerobot monitorea `/health` cada 5 min (alerta por email + SMS si cae 2 chequeos consecutivos).

## Síntomas → acciones

| Síntoma observable | Diagnóstico rápido | Acción |
|---|---|---|
| App web responde 500/503 | Vercel Dashboard › Deployments. ¿Último deploy falló? | `vercel rollback <previous-deployment>` (rollback de tag, <1 min). |
| App carga pero muestra "Sin datos" en todos los venues | Supabase Dashboard › Logs. ¿Errores `42501` (RLS)? | Verificar que la última migración no rompió `current_venue_id()`. Migración correctiva en nuevo PR. |
| KDS no recibe pedidos en tiempo real | Supabase Dashboard › Realtime. ¿Conexiones simultáneas > 200? | Reducir uso o esperar; free tier es el límite. Documentar incidente. |
| Login owner no llega el magic link | Supabase Dashboard › Auth › Logs. ¿Email rechazado? | Reintentar; si persiste, consultar configuración SMTP del proyecto en Supabase. |
| Login garzón retorna `blocked` con PIN correcto | RPC `verify_pin` retorna `blocked` por 5 fallos previos. | Owner desbloquea: `UPDATE staff_pin SET failed_attempts = 0, locked_until = NULL WHERE app_user_id = ...`. Mejor: agregar UI de desbloqueo (post-Avance 2). |
| `flutter test` local falla con "Drift schema mismatch" | El schema Drift cambió y no se regeneró. | `dart run build_runner build --delete-conflicting-outputs`. |
| `supabase db reset` falla en CI | Una migración nueva tiene SQL inválido. | Ejecutar localmente `supabase db reset` y leer el error; corregir migración o agregar correctiva. |
| Sentry muestra spike de errores Network | Probablemente el dispositivo del garzón perdió red. | Verificar `pending_op` no esté creciendo sin límite; el sync debería retomar. Si > 10 fallos seguidos, owner ve banner. |
| Pipeline CI verde pero preview Vercel rota | Build Vercel usa otra versión de Flutter o lockfile. | Revisar `pubspec.lock` versionado y la versión de Flutter en Vercel project settings. |

## Backups

**Sin backup-policy propio en MVP** ([opt-out documentado](../../README.md#metodología-aplicada)). Supabase free tier provee retención automática limitada (point-in-time recovery según el plan). Para datos de demo durante el semestre, basta `seed.sql` regenerable con `supabase db reset`.

Si entra una feature con datos reales del cliente que no se puedan regenerar (post-defensa), levantar el opt-out y escribir `docs/database/backup-policy.md`.

## Rollback

### Frontend (Vercel)

```bash
# Rollback al deployment anterior verificado
vercel rollback <previous-deployment-url>
```

Tiempo objetivo: <1 min. Vercel guarda los últimos N deployments.

### Backend (Supabase) — migraciones

**No hay rollback automático** — las migraciones son forward-only en MVP (RNF-SEC-005, ACID-5).

1. Identificar la migración problemática en `supabase/migrations/`.
2. Escribir nueva migración correctiva (`NNNN_fix_<slug>.sql`) que revierta el efecto.
3. PR con la correctiva, CI verde, review, merge.
4. `supabase db push` al entorno afectado.
5. Documentar en `CHANGELOG.md` y commit.

Para casos catastróficos durante el semestre académico (sin clientes reales), `supabase db reset` recrea el schema desde cero y el seed regenera datos demo — aceptable porque no hay datos productivos que proteger.

## Incidentes — qué documentar

`docs/operations/incident-response.md` formal queda en **opt-out** durante el semestre (sin SLA real). Aún así, si pasa algo notable en una demo o entrega:

1. Abrir issue `incident: <título>` en GitHub Project.
2. Anotar: detección, impacto, acción tomada, tiempo de recuperación, root cause si se conoce.
3. Si fue por un cambio reciente: ADR sucesor o documentación en CHANGELOG (sección Security si aplica).

## Comandos de salud (antes de demo o cierre de sprint)

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze --fatal-warnings
flutter test --coverage
dart run tool/check_coverage.dart coverage/lcov.info --global-min=60 --domain-min=70
flutter build web --no-pub
supabase db reset
supabase test db
```

## Comandos para desarrollo diario

```bash
supabase start                  # Supabase local en Docker
flutter run -d chrome           # app en navegador
# ... iterar ...
supabase stop                   # al terminar la sesión
```

## Lo que NO está en el runbook (y por qué)

- **`/healthz`/`/readyz`** propios — no aplican a BaaS-only (matriz de la metodología).
- **Escalado horizontal** — Supabase lo maneja según plan; nada que el equipo opere.
- **Patches al backend** — Supabase rota por cuenta del proveedor.
- **Failover entre regiones** — fuera de scope MVP.

## Referencias

- [release-process.md](../devops/release-process.md) — flujo normal de despliegue y rollback.
- [observability.md](observability.md) — qué se monitorea y cómo.
- [database/migrations.md](../database/migrations.md) — política forward-only y migraciones correctivas.
- [security/security.md](../security/security.md) — manejo de secretos durante un incidente.
- [opt-out documentado](../../README.md#metodología-aplicada) — opt-outs vigentes (incident-response formal, backup-policy propio).
