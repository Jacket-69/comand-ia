# Metodología aplicada — COMAND-IA

- **Talla:** M · Estándar
- **Tipo:** BaaS-only — frontend Flutter sobre Supabase gestionado; el "backend" son schema, RLS y RPCs
- **Proceso:** Scrumban
- **Estilo:** Clean Architecture liviana + DDD liviano por feature (vertical slices); monolito de cliente sobre BaaS (ver [ADR-0001](architecture/decisions/0001-flutter-multiplataforma.md), [ADR-0002](architecture/decisions/0002-supabase-baas-backend.md))
- **Fuente canónica:** vault › `Conocimiento/Procesos/Metodología de Proyectos`
- **Fecha de arranque formal:** 2026-06-10 (bootstrap retroactivo; el proyecto arrancó 2026-04-27)

## Desviaciones del default

Solo lo que se aparta **por contexto**, más allá de lo que la matriz por tipo ya justifica.

### Por tipo BaaS-only (justificadas por la matriz, no son opt-outs adicionales)

- `docs/api/openapi.yaml` **no aplica** → la fuente de verdad del contrato es `docs/api/contracts.md` (schema + RPCs + tipos generados con `supabase gen types`).
- `/healthz` y `/readyz` **no aplican** → no hay servicio propio que healthchequear.
- `docs/operations/runbook.md` acotado a lo que controlamos: rollback de migraciones y rollback de tag frontend en Vercel.
- `docs/operations/observability.md` parcial: Sentry cliente + Supabase Dashboard.
- Twelve-Factor parcial: §4 (backing services), §7 (port binding) y §8 (concurrency) los maneja Supabase.
- Release process variante BaaS/SPA: tag → CDN → smoke 1–5 min (no la variante Backend HTTP).

### Por contexto académico (proyecto evaluado por un profesor, sin clientes reales)

Estas prácticas están en opt-out durante el semestre. Se levantan documentándolo en un ADR si el proyecto continúa con clientes reales post-defensa (2026-07-07).

| Práctica | Razón del opt-out |
|---|---|
| Threat modeling formal STRIDE | RLS + secret scan + chequeo OWASP en code review alcanzan para el contexto |
| OWASP SAMM | Overhead desproporcionado para n=2 sin prod real |
| `docs/operations/incident-response.md` | Sin SLA real durante el semestre |
| Renovate / Dependabot automático | Chequeo manual mensual de deps es suficiente |
| Métricas DORA accionables | n=2 personas — ruido estadístico, no señal |
| `docs/database/backup-policy.md` propio | Supabase free tier hace retención automática |
| Rollback ensayado en prod | Sin prod con clientes durante el semestre |
| `exit-notes.md` (Fase 6) | Opt-in al cierre del semestre (2026-07-08) |

## Docs activos (por talla M × BaaS-only)

- [x] README · DoD · CI
- [x] `docs/product/vision.md`
- [x] `docs/requirements/srs.md`
- [x] `docs/architecture/` — overview, c4-context, c4-container, invariants, layout-tree
- [x] `docs/architecture/decisions/` — ADRs MADR (0001–0013)
- [x] `docs/api/contracts.md` (reemplaza openapi.yaml — BaaS-only)
- [x] `docs/database/` — model, migrations, rls
- [x] `docs/sync/offline-first.md`
- [x] `docs/quality/definition-of-done.md`
- [x] `docs/quality/testing-strategy.md`
- [x] `docs/security/security.md`
- [x] `docs/devops/ci-cd.md`
- [x] `docs/devops/release-process.md`
- [x] `docs/operations/observability.md`
- [x] `docs/operations/runbook.md`
- [x] `docs/coding-standards.md`
- [ ] `docs/operations/incident-response.md` — opt-out académico
- [ ] `docs/database/backup-policy.md` — opt-out académico (Supabase retención automática)
- [ ] `exit-notes.md` — opt-in al cierre del semestre (2026-07-08)
