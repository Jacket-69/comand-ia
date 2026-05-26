# Estrategia de testing

> Pirámide, cobertura por capa y herramientas. Lo que se testea y cómo. Promovido de la sección 10 de la antigua `ARCHITECTURE.md`.

## Pirámide

```
        /\
       /  \
      / E2E \           5–10%   flujos críticos punta a punta
     /------\
    / Integr \          20–30%  adaptadores, BD real, realtime, HTTP
   /----------\
  /    Unit    \        60–70%  lógica de dominio pura
 /--------------\
```

## Niveles

| Nivel | Herramienta | Objetivo de cobertura | Frecuencia |
|---|---|---|---|
| **Unit (dominio)** | `flutter_test` + `mocktail` | ≥70% en `domain/` (RNF-MAIN-001) | Cada PR |
| **Widget** | `flutter_test` + `pumpWidget` | ≥50% en `presentation/` | Cada PR |
| **Golden** | `golden_toolkit` + `alchemist` | 10–15 pantallas core | `main` + nightly |
| **Integration** | `integration_test` | 3–5 flujos críticos (toma de pedido, sync, dashboard) | Nightly + pre-release |
| **RLS / SQL** | pgTAP | 100% policies cubiertas | Nightly |

**Cobertura global mínima:** ≥60%. Reporte lcov en cada PR; si cae, CI falla.

## Por capa

| Capa | Qué se prueba |
|---|---|
| `lib/features/<feature>/domain/` | Reglas de negocio puras, UseCases, validaciones. Sin Flutter, sin Supabase, sin Drift. |
| `lib/features/<feature>/data/` | Datasources Supabase y Drift; serialización DTO; manejo de errores. Tests con datasource fake o instancia local. |
| `lib/features/<feature>/presentation/` | Controllers Riverpod (con `ProviderContainer.overrideWith` y mocks); widget tests sobre screens críticas. |
| `supabase/` | pgTAP sobre RLS, triggers (`compute_order_total`, `set_updated_at`), RPCs (`verify_pin`, `dashboard_kpis`), ausencia de `pending_op` en schema público. |

## Flujos críticos cubiertos por integration tests

1. **Toma de pedido offline → sync** — red simulada off → pedido en `pending_op` → red on → vacía FIFO en orden → KDS lo ve. Cubre CA-003, CA-004, RF-ORDER-002..004.
2. **Cierre de pedido terminal** — pedido `closed` no acepta UPDATE. Cubre CA-006, ACID-4, RF-ORDER-007.
3. **Aislamiento cross-venue** — token de venue B no ve datos de venue A. Cubre CA-002, CA-007, RNF-SEC-001..002.
4. **Dashboard con seed determinista** — KPIs y top items coinciden con dataset seed. Cubre CA-101..103.
5. **Export CSV** — separador `;`, UTF-8-BOM, sin datos cross-venue. Cubre CA-105.

## Test data

- **Seed determinista** (`supabase/seed.sql`) con casos representativos por regla:
  - 2 venues (A y B) para tests cross-venue.
  - Usuarios owner + staff por venue.
  - `staff_pin` con PIN conocido (solo en seed; nunca en prod).
  - Mesas, categorías, ítems del menú con precios variados.
  - Pedidos demo en distintos estados (`open`, `sent`, `preparing`, `ready`, `closed`) y con distribución horaria que valida la hora pico.
- **Fixtures inmutables** versionados en el repo. Cambiar el seed requiere ADR si afecta tests existentes.
- **Factories** en Dart para variantes en tests unitarios; nada de datos hardcoded duplicados en cada test.

## Qué no se testea

- Frameworks de terceros (Riverpod, Drift, supabase-dart). Asumimos que funcionan.
- Getters/setters triviales.
- Casos imposibles por construcción del tipo.
- UI estática (un mensaje literal en una `Text`).

## Flaky tests

- 1 fallo en 10 corridas → marcar `@Skip` con issue P2 abierto.
- No se permite flakiness en `main`.
- Si la suite supera 5 min en CI → dividir en jobs paralelos.

## Comandos locales

```bash
flutter test                                            # toda la suite Flutter
flutter test --coverage                                 # con cobertura
flutter test --tags integration                         # solo integration tests
dart run tool/check_coverage.dart coverage/lcov.info \
  --global-min=60 --domain-min=70                       # gate de cobertura
supabase db reset                                       # aplica migraciones + seed
supabase test db                                        # pgTAP completo
```

## Referencias

- [SRS § 4.6 Maintainability](../requirements/srs.md) — RNF-MAIN-001..004.
- Los criterios de aceptación (CA) están definidos en cada issue del board (issues COMA).
- [Definition of Done](definition-of-done.md).
