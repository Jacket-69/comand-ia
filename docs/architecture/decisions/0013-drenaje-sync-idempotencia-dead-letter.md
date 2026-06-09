---
adr: 0013
title: Drenaje de pending_op — idempotencia por UUID, dead-letter y snapshots del cliente
status: accepted
date: 2026-06-09
deciders: Benjamín López
tags: [adr, arquitectura, sync, offline-first]
---

# ADR 0013 — Drenaje de `pending_op`: idempotencia por UUID, dead-letter para errores permanentes y snapshots del cliente

## Contexto

ADR-0008 fijó el esqueleto del sync (cola FIFO local + LWW server-side) pero dejó sin resolver cuatro huecos que COMA-008 necesita cerrar para implementar el `SyncService`:

1. **Idempotencia.** Si la op llega a Supabase pero la app muere antes de borrar la fila de `pending_op`, el reintento duplicaría el pedido o sus ítems.
2. **Errores permanentes.** El flujo solo decía "si Supabase falla → `attempts++` y backoff". Con FIFO estricto (ACID-7), una op rechazada en forma permanente (FK inválida, pedido cerrado) bloquearía la cola del venue para siempre: el backoff jamás la arregla.
3. **Snapshots.** El trigger `validate_order_item` re-snapshoteaba `name_snapshot`/`price_cents_snapshot` desde `menu_item` en cada INSERT. Para un INSERT online eso es correcto; para el drenaje offline pisa el precio capturado al momento del pedido si el menú cambió antes de la sync — contradice la intención de ACID-2 y el criterio "el envío respeta los snapshots de `order_item`" del issue.
4. **Disparador.** "Escucha conectividad" sugería un paquete de detección de red (`connectivity_plus`) que no está en las dependencias.

## Decisión

1. **Idempotencia por UUID de cliente + upsert ignorante.** Todos los payloads llevan los UUID generados en cliente, incluidos los de `order_item` (los productores se corrigieron para capturar el ítem retornado por `addItem`). Los INSERT remotos usan upsert con `ignoreDuplicates` (`ON CONFLICT DO NOTHING`): un reintento tras éxito parcial es un no-op que retorna éxito. El cierre verifica el estado remoto antes de escribir: si ya está `closed`, la op se da por aplicada (ACID-4 como estado terminal idempotente).

2. **Dead-letter para errores permanentes.** `pending_ops` (Drift, v4) gana `status` (`pending` | `dead`) y `last_error`. El gateway clasifica los errores según la tabla de contracts.md: datos inválidos (`23502`, `23503`, `23514`, `22P02`, `P0001`) → la op se marca `dead` con su diagnóstico y la cola sigue; red, `42501` (RLS/sesión), `PGRST*` y códigos desconocidos → recuperable: `attempts++`, backoff, la op no se pierde. Ante la duda se clasifica recuperable: jamás se descartan datos por un error no identificado. Retirar una op con veredicto terminal no es reordenar la FIFO: es impedir un head-of-line blocking eterno.

3. **El snapshot del cliente manda.** Migración `0003_client_snapshots`: en INSERT, `validate_order_item` respeta `name_snapshot`/`price_cents_snapshot` provistos y solo los rellena desde `menu_item` cuando `name_snapshot` viene vacío (sentinel del seed y de inserts server-side). En UPDATE siguen congelados desde OLD. ACID-2 queda anclado al momento del pedido, que es su intención original.

4. **Sin paquete de conectividad.** El `SyncService` se dispara por: cambios en la cola (watch de Drift sobre `pending_ops`), cambios de sesión (`onAuthStateChange`) y el timer del backoff. El primer intento fallido ya programa el reintento; "volvió la red" se descubre intentando. Cero dependencias nuevas.

5. **Drenaje solo con sesión utilizable.** `ensureReady()` exige sesión Supabase y visibilidad de la propia fila `app_user` (con RLS deny-by-default, si no la vemos, ningún write va a pasar). Sin sesión no se consumen `attempts` de las ops: el fallo no es culpa de ellas.

## Alternativas descartadas

- **RPC de sync batch (`apply_op`)**: centralizaría idempotencia server-side, pero contradice el contrato BaaS-only sin RPCs artesanales (contracts.md) y agrega superficie SQL para un MVP de 2 personas.
- **Saltar la op fallida y seguir (skip sin dead-letter)**: pierde el diagnóstico y reordena la semántica de la cola silenciosamente.
- **Reintentar para siempre toda op** (sin distinción permanente/recuperable): una sola op envenenada congela el venue completo; el banner de "sync degradada" no compensa la pérdida de todo lo que viene detrás.
- **`connectivity_plus`**: estado de red ≠ alcanzabilidad de Supabase (cautive portals, DNS, caídas del servicio); el reintento con backoff mide lo que importa.
- **Aceptar el re-snapshot server-side y reconciliar después**: viola el criterio de aceptación del issue y registra precios que el comensal nunca vio.

## Consecuencias

- `pending_op` deja de ser solo cola: las filas `dead` son evidencia forense visible para el owner (futura UI de diagnóstico).
- El seed de Supabase sigue funcionando sin cambios (usa el sentinel `''` y el trigger rellena).
- Una op `dead` implica divergencia local↔remoto aceptada y registrada (el pedido vive local aunque el remoto lo haya rechazado); la reconciliación fina queda para la historia de realtime/pull.
- El estado del pedido remoto no se re-deriva al avanzar ítems (el enum `update_order_status` existe pero nadie lo encola): pendiente para la historia de realtime (KDS remoto).
- Verificación: tests del `SyncService` (FIFO 5 ops, backoff, dead-letter, degraded, multi-venue), pgTAP `client_snapshots.sql` (snapshot respetado/rellenado/inmutable, ACID-4 intacto) y test de migración Drift v1→v4.
