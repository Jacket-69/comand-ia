# Invariantes — ACID + SOLID

> Contratos de integridad y diseño que el sistema mantiene siempre. Son deuda técnica si se rompen y deben verificarse en CI o code review.

## ACID — contratos de integridad de datos

| ID | Invariante |
|---|---|
| **ACID-1** | `customer_order.venue_id` y `dining_table.venue_id` siempre coinciden (FK + CHECK). Un pedido no puede apuntar a una mesa de otro venue. |
| **ACID-2** | `order_item` snapshotea `name_snapshot` y `price_cents_snapshot` al INSERT. Inmutables aunque se edite el menú después. Aseguran que la auditoría histórica de pedidos no cambie con el tiempo. |
| **ACID-3** | `customer_order.total_cents` es **derivado**. El trigger `compute_order_total()` lo recalcula. **El cliente nunca escribe este campo directamente.** |
| **ACID-4** | `status = 'closed'` es **terminal**. Un trigger bloquea cualquier UPDATE de items, total o método de pago en un pedido cerrado. |
| **ACID-5** | Toda tabla pública con `venue_id` tiene RLS habilitada y al menos una policy USING. Verificado en CI con pgTAP. Ver [database/rls.md](../database/rls.md). |
| **ACID-6** | El PIN no se persiste ni registra en texto plano. El cliente solo llama `verify_pin(venue_id, pin, display_name)` por TLS; la columna `pin_hash` no es seleccionable desde el cliente (RLS bloquea SELECT en `staff_pin`). |
| **ACID-7** | `pending_op` es **FIFO estricto por `venue_id`**. El `SyncService` no reordena las operaciones pendientes. Ver [sync/offline-first.md](../sync/offline-first.md). |

Cada invariante tiene un test que la respalda:

- ACID-1, ACID-2, ACID-4 → triggers + tests pgTAP en `supabase/tests/`.
- ACID-3 → test pgTAP que verifica `total_cents` post-mutación de `order_item`.
- ACID-5 → query nightly sobre `pg_policies` (ver [database/rls.md](../database/rls.md)).
- ACID-6 → test pgTAP que SELECT directo sobre `staff_pin.pin_hash` retorna 0 filas.
- ACID-7 → integration test del `SyncService` con cola de 5 operaciones y reconexión.

## SOLID en Flutter

| Principio | Aplicación |
|---|---|
| **S** (Single Responsibility) | Cada feature tiene `domain/`, `data/`, `presentation/` separadas. Un UseCase = una sola operación de negocio. |
| **O** (Open/Closed) | Los repositorios extienden interfaces abstractas. Cambiar Drift→Hive ([ADR-0004](decisions/0004-drift-persistencia-local.md)) no modifica la capa de dominio. |
| **L** (Liskov Substitution) | Los mocks (mocktail) cumplen exactamente el contrato de la interfaz abstracta. Los tests de dominio pasan con mock y con implementación real. |
| **I** (Interface Segregation) | Los repositorios exponen métodos específicos por feature. No hay super-interfaz monolítica que fuerce implementar métodos irrelevantes. |
| **D** (Dependency Inversion) | Los controllers Riverpod inyectan la **interfaz abstracta** del repositorio, no la implementación concreta. La inyección ocurre en el provider. |

## Reglas de imports

Reflejan SOLID-S y SOLID-D al nivel de archivos:

- `presentation/` ➝ solo importa `domain/`.
- `data/` ➝ solo importa `domain/`.
- `domain/` ➝ no importa Flutter, Supabase, Drift, ni `dart:io|dart:html`.
- Sin imports cruzados entre features (`features/auth/` no importa de `features/orders/`).

Verificado en code review (DoD). Si surge regresión persistente, agregar lint rule de imports.

## Cuándo se rompen los invariantes

- **Nunca se rompen "temporalmente".** Si un PR no puede mantenerlos, abre ADR sucesor antes de mergear.
- Los invariantes ACID son **bloqueantes en CI**: si pgTAP detecta violación, el PR no mergea.
- Los principios SOLID son **bloqueantes en code review**: PR sin cumplimiento → vuelve a `in progress`.
