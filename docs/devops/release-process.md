# Release process — variante BaaS/SPA

> Cómo se libera COMAND-IA. Variante **BaaS/SPA** del frame de la metodología (no la de Backend HTTP): la app web es lo único que controlamos publicar; el backend Supabase es producto gestionado y los cambios de schema viajan vía migraciones SQL versionadas, no como deploys de servicio.

## Entornos

| Entorno | URL | Base de datos | Disparador |
|---|---|---|---|
| **Local dev** | `localhost:port` | `supabase start` (Docker) | Manual (`flutter run -d chrome`) |
| **Preview (PR)** | `comand-ia-pr-NNN.vercel.app` | Supabase staging compartido | Automático en cada PR |
| **Staging** | `staging.comand-ia.app` | Supabase staging | Push a `main` |
| **Prod** | `comand-ia.app` | Supabase prod | Tag `v*` |

Para el semestre académico, los entornos relevantes son **local + preview + staging**. Prod queda configurado pero **sin clientes reales hasta post-defensa**.

## Variables de entorno

Definidas en `.env.example` (versionado). El archivo `.env` real está en `.gitignore`. Los secretos en GitHub Actions se configuran en Settings › Secrets:

- `SUPABASE_URL` · `SUPABASE_ANON_KEY` · `SUPABASE_SERVICE_ROLE_KEY` · `SUPABASE_DB_PASSWORD`
- `VERCEL_TOKEN` · `VERCEL_ORG_ID` · `VERCEL_PROJECT_ID`
- `SENTRY_DSN` · `SENTRY_AUTH_TOKEN`
- `CODECOV_TOKEN`

Twelve-Factor parcial: configuración por entorno vía variables; los puntos 4 (backing services), 7 (port binding) y 8 (concurrency) los maneja Supabase.

## Flujo de release (variante BaaS/SPA)

### 1. Cambio en `main`

- PR mergeado vía squash → push a `main` automático.
- GitHub Actions corre el pipeline completo (ver [ci-cd.md](ci-cd.md)).
- Vercel despliega `main` a `staging.comand-ia.app`.
- Supabase staging recibe migraciones via `supabase db push --linked` desde el workflow de CI.

### 2. Tag de release a prod

```bash
git tag v0.X.0
git push --tags
```

- GitHub Actions detecta el tag → corre pipeline + smoke tests + publish a `comand-ia.app`.
- Supabase prod recibe migraciones via `supabase db push` con el flag de prod (verificado por el equipo antes del tag).
- CHANGELOG.md se actualiza en el mismo PR que cierra el sprint.

### 3. Smoke post-deploy (1–5 min)

Tras cada deploy a staging o prod:

| Check | Método | Tiempo objetivo |
|---|---|---|
| App carga sin errores | curl al index, status 200 | <30 s |
| Login owner (magic link) | manual: solicitar magic link en staging y completar flow | <2 min |
| Login garzón (PIN) | manual: PIN seed determinista | <30 s |
| Toma pedido happy path | manual desde tablet/desktop | <2 min |
| Edge function `/health` | uptimerobot ping | inmediato |

Si **alguno falla** → rollback (ver siguiente sección) y abrir issue con label `incident`.

## Rollback

### Frontend (Vercel)

```bash
# Rollback de tag (re-deploy versión anterior verificada)
vercel rollback <previous-deployment-url>
```

Tiempo de rollback: <1 min. Vercel guarda los últimos N deployments.

### Backend (Supabase) — migraciones

**No hay rollback automático** — las migraciones son forward-only en MVP (RNF-SEC-005). Si una migración rompe staging o prod:

1. Identificar la migración problemática en `supabase/migrations/`.
2. Escribir una **nueva migración correctiva** (`NNNN_fix_<slug>.sql`) que revierta el efecto.
3. Aplicar la migración correctiva al entorno afectado.
4. Documentar en `CHANGELOG.md` y en commit.

Para casos catastróficos durante el semestre académico (sin clientes reales), `supabase db reset` recrea el schema desde cero — aceptable porque el dataset de staging se regenera con `seed.sql`.

### Backend (Supabase) — datos

Supabase free tier provee retención automática de backups (point-in-time recovery limitado). Para academia es suficiente; un backup-policy propio queda **en opt-out** ([opt-outs académicos](../../README.md#metodología-y-opt-outs)).

## Versionado

- **SemVer relajado durante el semestre.** Una entrada en `CHANGELOG.md` por entrega académica:
  - `v0.1.0-avance-1` (2026-04-28) — scaffolding ejecutable.
  - `v0.2.0-avance-2` (2026-05-26) — Capa 1 demoable.
  - `v1.0.0-defensa` (2026-07-07) — Capa 1 + Capa 2 MVP.
- Post-defensa, si el proyecto continúa, pasa a SemVer estricto.

## Cadencia y horarios

- **Deploy a staging:** automático en cada push a `main`. Sin restricción de horario.
- **Deploy a prod (tag):** durante el semestre solo se hace al cierre de cada hito académico (entregas y defensa). Post-defensa, se decide cadencia real con clientes.
- **No deploys los viernes después de las 18:00 ni los días previos a entregas.**

## Métricas DORA

En **opt-out** durante el semestre (n=2 personas, ruido estadístico). Se observan como hábito mental:

- Cadencia de PRs (ojo si una rama vive >5 días).
- Tamaño de PR (preferir cambios chicos).
- Tiempo desde merge a staging visible.

## Referencias

- [ci-cd.md](ci-cd.md) — pipeline de CI.
- [branching-strategy.md](branching-strategy.md) — flujo Git y Conventional Commits.
- [operations/runbook.md](../operations/runbook.md) — qué hacer cuando staging o prod se rompen.
- [operations/observability.md](../operations/observability.md) — qué monitorear post-deploy.
- [database/migrations.md](../database/migrations.md) — política forward-only.
- ADR relacionados: [ADR-0002](../architecture/decisions/0002-supabase-baas-backend.md), [ADR-0007](../architecture/decisions/0007-github-flow-conventional-commits.md).
