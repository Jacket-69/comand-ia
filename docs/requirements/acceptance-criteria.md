# Criterios de aceptación — Given-When-Then

> Casos verificables que cierran las historias del [SRS](srs.md) y del [user-stories.md](user-stories.md). Si un caso falla, el sprint no está "Done".

---

## Capa 1 — Operación

### CA-001 — PIN bloqueado tras 5 intentos fallidos
- **Cubre:** RF-AUTH-003, HU-A03.
- **Given** un garzón con PIN configurado y `failed_attempts = 0`,
- **When** ingresa un PIN incorrecto 5 veces consecutivas y al 6° intento ingresa el PIN correcto,
- **Then** el sistema retorna `auth_status = blocked` y rechaza el acceso, aunque el PIN del 6° intento sea válido.

### CA-002 — Aislamiento de mesas por venue
- **Cubre:** RF-TENANT-002, HU-T02, RNF-SEC-002.
- **Given** un garzón autenticado en venue A,
- **When** navega a la vista de mesas,
- **Then** solo ve las mesas de venue A; nunca las de venue B (filas inaccesibles por RLS).

### CA-003 — Pedido offline persiste
- **Cubre:** RF-ORDER-002, RNF-REL-001, HU-O02.
- **Given** la red está desconectada,
- **When** el garzón completa un pedido y lo confirma,
- **Then** la UI muestra OK; el pedido queda en `pending_op` (Drift); no hay pérdida de datos al reabrir la app.

### CA-004 — Sync FIFO al reconectarse
- **Cubre:** RF-ORDER-003, HU-O03.
- **Given** existe un pedido en `pending_op` tras CA-003,
- **When** la red se restablece,
- **Then** `pending_op` se vacía en orden FIFO; el pedido llega a Supabase; el KDS lo muestra en ≤2 s (RNF-PERF-004).

### CA-005 — Realtime KDS → garzón
- **Cubre:** RF-KDS-002, HU-K02.
- **Given** un pedido visible en KDS,
- **When** el cocinero marca el pedido como `ready`,
- **Then** el garzón ve el cambio en su vista de mesas en ≤2 s sin recargar.

### CA-006 — Estado `closed` es terminal
- **Cubre:** RF-ORDER-007, HU-O06, ACID-4.
- **Given** un pedido con `status = closed`,
- **When** el garzón intenta agregar un ítem,
- **Then** el sistema rechaza la operación con error de estado terminal; el trigger SQL bloquea cualquier UPDATE de items, total o método de pago.

### CA-007 — Aislamiento SQL cross-venue
- **Cubre:** RF-TENANT-002, RNF-SEC-002.
- **Given** un usuario autenticado de venue B,
- **When** intenta `SELECT * FROM customer_order` sin filtro explícito,
- **Then** retorna 0 filas (RLS bloquea); test pgTAP automatizado.

---

## Capa 2 — Analítica

### CA-101 — Dashboard carga rápido con 30 días
- **Cubre:** RF-ANALY-007, RNF-PERF-003, HU-AN07.
- **Given** dataset seed estándar con 30 días de pedidos,
- **When** el owner abre el dashboard con filtro `30d`,
- **Then** los datos son visibles en ≤1.5 s (medido desde request hasta render completo).

### CA-102 — Filtro temporal sin refresh
- **Cubre:** RF-ANALY-005, HU-AN05.
- **Given** el owner está en el dashboard,
- **When** cambia el filtro de `7d` a `today`,
- **Then** los datos se actualizan sin recarga de página (cambio reactivo del state).

### CA-103 — Top 5 ítems determinista
- **Cubre:** RF-ANALY-002, HU-AN02.
- **Given** dataset seed con distribución conocida,
- **When** el owner consulta el dashboard,
- **Then** el ranking de top 5 ítems coincide con el ordenamiento esperado del seed.

### CA-104 — Aislamiento del dashboard por owner
- **Cubre:** RF-TENANT-002, RNF-SEC-002.
- **Given** un owner del venue A,
- **When** abre su dashboard,
- **Then** solo ve datos de venues que posee (`owner_id = auth.uid()`); nunca de venue B.

### CA-105 — Export CSV compatible con Excel chileno
- **Cubre:** RF-ANALY-006, HU-AN06.
- **Given** el owner está en el dashboard con filtro `30d`,
- **When** exporta a CSV,
- **Then** el archivo se descarga con separador `;`, encoding UTF-8-BOM, sin datos de otros venues; abre correctamente en Excel chileno con caracteres especiales.

---

## Verificación cruzada

| CA | Tipo de test | Ubicación |
|---|---|---|
| CA-001 | Integration test del PinAuthDataSource | `test/features/auth/` |
| CA-002 | Widget test sobre `TableGridScreen` con datasource fake | `test/features/orders/` |
| CA-003 | Integration test con red simulada desconectada | `integration_test/` |
| CA-004 | Integration test con reconexión simulada | `integration_test/` |
| CA-005 | Manual + e2e si se llega a Sprint 8 | `integration_test/` |
| CA-006 | Test pgTAP del trigger `block_closed_order_update` + integration test del repo | `supabase/tests/`, `test/` |
| CA-007 | Test pgTAP cross-venue | `supabase/tests/` |
| CA-101 | Manual (medición red browser) | demo Avance 2 |
| CA-102 | Widget test con `ProviderContainer` | `test/features/analytics/` |
| CA-103 | Test pgTAP sobre RPC `dashboard_kpis` con seed | `supabase/tests/` |
| CA-104 | Test pgTAP cross-venue sobre RPC `dashboard_kpis` | `supabase/tests/` |
| CA-105 | Integration test del `CsvExporter` | `test/features/analytics/` |

## Criterios de cierre por sprint

Un sprint no está "Done" si:

- Algún CA cubierto por sus historias no pasa.
- Algún test pgTAP de RLS retorna verde con datos de otro venue.
- La cobertura cae bajo 60% global o 70% en `domain/`.

## Referencias

- [SRS](srs.md), [user-stories.md](user-stories.md).
- [quality/testing-strategy.md](../quality/testing-strategy.md).
- [quality/definition-of-done.md](../quality/definition-of-done.md).
