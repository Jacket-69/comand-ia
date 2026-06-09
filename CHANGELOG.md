# Changelog

Todos los cambios notables a este proyecto se documentan acá.

Formato basado en [Keep a Changelog 1.1.0](https://keepachangelog.com/es-ES/1.1.0/).
Versionado: una entrada por **entrega académica** del semestre (no SemVer estricto durante desarrollo).

## [Unreleased]

### Added
- Sincronización offline → Supabase (COMA-008): `SyncService` drena la cola FIFO `pending_op` por venue con backoff exponencial (2^attempts s, cap 5 min), idempotencia por UUID de cliente, dead-letter para errores permanentes y adopción LWW del `updated_at` del servidor. Estado observable de "sync degradada" para el owner. Migración Drift v4 (`status`/`last_error` en `pending_ops`) y migración Supabase `0003_client_snapshots` (el trigger respeta los snapshots capturados offline, ACID-2). Detalle en ADR-0013.
- Reorganización de `docs/` al árbol canónico de la metodología in-house (`Estructura de docs.md`): `product/`, `requirements/`, `architecture/`, `database/`, `quality/`, `security/`, `devops/`, `operations/`, `api/`.
- Migración de los 8 ADRs de `docs/decisiones.md` a archivos MADR separados en `docs/architecture/decisions/`.
- `CHANGELOG.md` en raíz siguiendo Keep a Changelog 1.1.0.
- Spike COMA-004: prototipo Drift en Flutter web (`lib/core/local/spike_db.dart`, ruta `/spike`, worker `web/drift_worker.dart` + `sqlite3.wasm`). Resultado: Drift viable en CanvasKit + IndexedDB; ADR-0004 confirmado, fallback Hive no se activa. Detalle en [docs/architecture/spikes/COMA-004-drift-web.md](docs/architecture/spikes/COMA-004-drift-web.md).
- Expansión del dominio a operación POS real: ADRs 0009-0012 (roles granulares, caja y cierre de turno, inventario con costeo por receta, modificadores estructurados) + actualización de `vision`, `glossary` y `srs`.
- Perfil de metodología declarado en el README: **Estándar (M) × BaaS-only**.

### Changed
- Reestructuración de `docs/` al perfil **Estándar × BaaS-only**: `roadmap.md` y `storyboards.md` reducidos a punteros al board (la fuente de verdad de sprints/estado son los milestones e issues, no archivos `.md`).

### Removed
- `docs/SRS.md`, `docs/ARCHITECTURE.md`, `docs/decisiones.md`, `docs/ROADMAP.md` — migrados al árbol canónico (los antiguos se borran sin redirect; los punteros viejos se actualizan en el mismo cambio).
- Otros archivos planos en `docs/` que ya no calzan con la organización por dominio.
- `architecture/c4-components.md` (C4 nivel 3 = talla L, no requerido en M), `requirements/user-stories.md` y `requirements/acceptance-criteria.md` (historias y criterios viven en el board de issues), `quality/sqa-plan.md` (fuera de la planta M) y `devops/branching-strategy.md` (duplicaba `CONTRIBUTING.md`).

## [v0.1.0-avance-1] — 2026-04-28

Entrega académica Avance 1 (scaffolding ejecutable):

### Added
- Bootstrap Flutter 3.x con `auth/` y `orders/` como features iniciales.
- Schema Supabase v0 alineado con SRS: `venue`, `app_user`, `staff_pin`, `menu_category`, `menu_item`, `dining_table`, `customer_order`, `order_item`, `audit_log`.
- RLS deny-by-default por `venue_id` en todas las tablas con datos de negocio.
- `verify_pin()` SECURITY DEFINER para autenticación de garzón sin exponer `pin_hash`.
- Triggers `set_updated_at()` y `compute_order_total()`.
- Suite pgTAP que verifica policies cross-venue y ausencia de `pending_op` en schema público.
- CI GitHub Actions: format + analyze + tests + cobertura mínima (60% global / 70% dominio) + secret scan + `supabase db reset` + `supabase test db`.
- Lefthook con format y analyze pre-commit.
- Seed determinista para owner, garzón, mesas, menú y pedidos demo.
- Documentación inicial: `README.md`, `CONTRIBUTING.md` y los documentos planos correspondientes bajo `docs/` (SRS, ARCHITECTURE, decisiones, ROADMAP).
