---
adr: 0008
title: Sync offline-first — cola FIFO local + LWW por updated_at server-side
status: accepted
date: 2026-04-27
deciders: Benjamín López
tags: [adr, arquitectura, sync, offline-first]
---

# ADR 0008 — Sync offline-first: cola FIFO local + LWW por `updated_at` server-side

## Contexto

La toma de pedido debe **funcionar sin internet** (RNF-REL-001) y **no perder pedidos por desconexión** mientras la app permanezca abierta (RNF-REL-002). Al reconectarse, las operaciones pendientes deben llegar a Supabase **en orden** y **sin pérdida**.

Cuando dos dispositivos modifican la misma fila offline (ej: el mismo pedido editado simultáneamente desde dos tablets), se necesita una política de **resolución de conflictos**. Las alternativas canónicas son:

- **CRDT** — estructuras de datos que convergen automáticamente.
- **Operational Transforms (OT)** — secuencia de operaciones aplicadas en orden equivalente.
- **Last Write Wins (LWW)** — gana la escritura con timestamp más reciente.

El caso de uso real es **un garzón por mesa** durante la mayor parte del tiempo. La edición concurrente del mismo pedido desde dos dispositivos es un caso degenerado, no el flujo normal. La complejidad de CRDT u OT no se justifica para este perfil de uso.

Adicionalmente, los relojes de cliente **no son confiables** (drift, manipulación, time zones inconsistentes). Cualquier política basada en timestamp debe usar el **timestamp del servidor**, no del cliente.

## Decisión

Adoptamos **cola FIFO local en Drift (`pending_op`) + LWW por `updated_at` server-side**.

Flujo de sync (6 pasos):

1. UI llama `OrderRepository.create(order)`.
2. Repo persiste en Drift (local-cache) → emite stream → UI re-renderiza con dato local.
3. Repo encola en `pending_op { op_type, payload, created_at, attempts: 0 }`.
4. `SyncService` (Riverpod background provider) escucha conectividad: si hay red, toma ops FIFO de `pending_op` y llama supabase-dart SDK.
5. Si Supabase falla: `attempts++`; backoff exponencial `2^attempts` segundos (máx. 5 min); si `attempts > 10`, notifica al owner via estado observable.
6. Si Supabase OK: el server retorna `updated_at`; LWW: si servidor tiene `updated_at` > local → local adopta el valor del servidor; borra la op de `pending_op`.

`updated_at` se actualiza en Postgres vía trigger `set_updated_at()` en cada UPDATE; **el cliente nunca genera ese timestamp**. La cola FIFO `pending_op` vive **solo en local** (Drift); no existe en Supabase.

## Alternativas consideradas

### Opción A — CRDT (Conflict-free Replicated Data Types)
- **Pros:** Convergencia automática sin pérdida de escrituras concurrentes; no requiere servidor para resolver conflictos.
- **Contras:** Implementación compleja para un equipo de 2 (estructuras LWW-Set, RGA, OR-Set, etc.); las libs Flutter maduras son escasas; la representación serializada es más pesada que un payload simple.
- **Por qué se descartó:** Sobre-ingeniería para el caso de uso real; el costo de implementarlo y mantenerlo supera el beneficio.

### Opción B — Operational Transforms
- **Pros:** Probado en editores colaborativos (Google Docs).
- **Contras:** Aún más complejo que CRDT; requiere servidor central que aplique transformaciones.
- **Por qué se descartó:** Mismas razones que CRDT, agravadas.

### Opción C — Push Replication con timestamp del cliente
- **Pros:** Implementación más simple (un campo `client_updated_at`).
- **Contras:** Drift de relojes cliente → conflictos no determinísticos; vulnerable a manipulación.
- **Por qué se descartó:** El timestamp del cliente no es confiable.

### Opción D — Cola FIFO + LWW con `updated_at` server-side (elegida)
- **Pros:** Implementación simple; FIFO garantiza causalidad dentro de un dispositivo; el servidor es la fuente de verdad temporal; trivial de testear.
- **Contras explícitos:** LWW puede perder la escritura más antigua en caso de edición concurrente desde dos dispositivos; `pending_op` solo en local, si el storage local se borra (cache flush, reinstall) las ops pendientes se pierden.

## Consecuencias

### Positivas
- Implementación simple: no requiere CRDT ni OT.
- Orden FIFO garantiza causalidad dentro de un mismo dispositivo (ACID-7).
- El timestamp de servidor como fuente de verdad evita drift de relojes del cliente.
- Backoff exponencial protege a Supabase de tormentas de reintentos al reconectar muchos dispositivos.
- Fácil de testear: integration tests con red desconectada (CA-003) y reconexión (CA-004).

### Negativas / costo
- LWW puede perder la escritura más antigua en casos de edición concurrente desde dos dispositivos. Para el caso de uso (un garzón por mesa, no edición simultánea del mismo pedido), este riesgo es aceptable y documentado.
- `pending_op` existe solo en Drift (local); si el storage local se borra (cache flush, reinstall, modo privado), las ops pendientes se pierden. Mitigación: documentado en onboarding del owner; el caso es excepcional.
- El backoff exponencial puede demorar la sync de un dispositivo que tuvo varios fallos seguidos; aceptable por la naturaleza del flujo (las pocas operaciones perdidas se reenvían cuando vuelve la red).

### Neutras
- `pending_op` no existe en Supabase → test pgTAP verifica esa ausencia (ver `supabase/tests/`).
- El campo `created_at` de `pending_op` lo genera el cliente, pero solo se usa para ordenar la cola **dentro del mismo dispositivo**, no para resolver conflictos cross-device.

## Cumplimiento / verificación

- Integration tests (Sprint 3+):
  - Red desconectada: pedido se persiste en `pending_op` y la UI confirma OK (CA-003).
  - Tras reconexión: `pending_op` se vacía en orden FIFO (CA-004).
  - KDS recibe el pedido en ≤2s desde la sync (RNF-PERF-004).
- Test pgTAP: `pending_op` no existe en schema público de Supabase.
- Code review: el cliente nunca escribe `updated_at`; lo recibe del servidor.
- ACID-7 documentado en `docs/architecture/invariants.md`.

## Referencias

- [SRS § 4.4 Reliability](../../requirements/srs.md) — RNF-REL-001..003.
- [SRS § 5 Casos de aceptación](../../requirements/srs.md) — CA-003, CA-004, CA-005.
- [Sync offline-first](../../sync/offline-first.md).
- ADRs relacionados: [ADR-0002](0002-supabase-baas-backend.md) (backend), [ADR-0004](0004-drift-persistencia-local.md) (storage local).
