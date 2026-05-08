# Changelog

Todos los cambios notables a este proyecto se documentan acá.

Formato basado en [Keep a Changelog 1.1.0](https://keepachangelog.com/es-ES/1.1.0/).
Versionado: una entrada por **entrega académica** del semestre (no SemVer estricto durante desarrollo).

## [Unreleased]

### Added
- Reorganización de `docs/` al árbol canónico de la metodología in-house (`Estructura de docs.md`): `product/`, `requirements/`, `architecture/`, `database/`, `quality/`, `security/`, `devops/`, `operations/`, `api/`.
- Migración de los 8 ADRs de `docs/decisiones.md` a archivos MADR separados en `docs/architecture/decisions/`.
- `CHANGELOG.md` en raíz siguiendo Keep a Changelog 1.1.0.

### Removed
- `docs/SRS.md`, `docs/ARCHITECTURE.md`, `docs/decisiones.md`, `docs/ROADMAP.md` — migrados al árbol canónico (los antiguos se borran sin redirect; los punteros viejos se actualizan en el mismo cambio).
- Otros archivos planos en `docs/` que ya no calzan con la organización por dominio.

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
