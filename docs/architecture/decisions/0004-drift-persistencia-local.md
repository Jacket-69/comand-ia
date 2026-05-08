---
adr: 0004
title: Drift como motor de persistencia local (spike Sprint 1; fallback Hive)
status: accepted
date: 2026-04-27
deciders: Benjamín López, Fernando Godoy
tags: [adr, frontend, persistencia, offline-first]
---

# ADR 0004 — Drift como motor de persistencia local (spike Sprint 1; fallback Hive)

## Contexto

COMAND-IA es **offline-first** (RNF-REL-001, RNF-REL-002): la toma de pedido debe funcionar sin internet y los pedidos no se pierden por desconexión mientras la app permanezca abierta. Esto exige una solución de storage local que cumpla:

- **Persistir entre reinicios** de la app (no solo memoria).
- Soportar **queries** para recuperar la cola FIFO de operaciones pendientes (`pending_op`) y reconstruir vistas locales del menú y mesas.
- **Funcionar en Flutter web** (IndexedDB) además de mobile (SQLite) — alineado con [ADR-0001](0001-flutter-multiplataforma.md).
- Type-safety razonable para evitar errores de schema en compilación.

Los pedidos tienen estructura **relacional clara**: `customer_order` → `order_item` → snapshot de `menu_item`. Forzar esa estructura en un store key-value introduce queries en memoria sobre todos los pedidos, lo que escala mal con la jornada.

Drift es un ORM type-safe que compila queries SQL en mobile y opera sobre IndexedDB en web. Hive es un key-value store más simple y con mejor historial en Flutter web, pero sin queries relacionales. SQLite directo con `sqflite` no soporta web. ObjectBox no es viable en Flutter web sin compromisos.

## Decisión

Adoptamos **Drift** como motor de persistencia local. En **Sprint 1 dedicamos un día de spike** a validar que Drift compila y opera correctamente en Flutter web (CanvasKit + IndexedDB) con un caso real (cola `pending_op` y cache de `menu_item`).

**Gate de fallback explícito:** si la fricción supera **4 h efectivas de bloqueo sin solución estable**, migramos a Hive con queries en memoria para "pedidos del día" y abrimos `0004-superseded` con un nuevo ADR que registre el cambio.

## Alternativas consideradas

### Opción A — Hive (key-value)
- **Pros:** API mínima; muy maduro en Flutter web; sin codegen obligatorio.
- **Contras:** Sin queries relacionales — `pending_op` y `order_item` requieren scan en memoria; sin type-safety en queries; sin schema versionado.
- **Por qué se mantiene como fallback (no se descartó):** Para el caso degradado donde Drift web no sea viable; "pedidos del día" en memoria es aceptable como mitigación temporal.

### Opción B — sqflite (SQLite directo, sin ORM)
- **Pros:** Más cercano al SQL puro; conocido.
- **Contras:** No soporta Flutter web — incumple [ADR-0001](0001-flutter-multiplataforma.md) que exige los 4 targets.
- **Por qué se descartó:** Falla el requisito de cobertura web.

### Opción C — Drift (elegida)
- **Pros:** ORM type-safe; queries compiladas; soporta SQLite (mobile/desktop) e IndexedDB (web) con la misma API; schema versionado.
- **Contras explícitos:** Drift en Flutter web está en desarrollo activo y puede tener issues con multi-tab, modos privados o IndexedDB en algunos navegadores; codegen agrega overhead a `build_runner`; el spike de validación es necesario.

### Opción D — ObjectBox
- **Pros:** Performance alto en mobile; relaciones a nivel de objeto.
- **Contras:** Soporte web limitado; lock-in al motor; menos comunidad Flutter que Drift.
- **Por qué se descartó:** Misma razón que sqflite respecto al soporte web maduro.

## Consecuencias

### Positivas
- Type-safety en queries: errores de schema se detectan en compilación.
- La misma interfaz de repositorio (SOLID-O / [ADR-0003](0003-riverpod-codegen.md)) permite cambiar a Hive sin tocar el dominio.
- `pending_op` se modela como tabla relacional con índices por `venue_id` y `created_at` → orden FIFO eficiente (ACID-7).
- Schema versionado: las migraciones locales se manejan con `drift_dev` igual que las de Postgres en `supabase/migrations/`.

### Negativas / costo
- Drift en Flutter web es área activa: pueden aparecer bugs de IndexedDB en algunos navegadores; mitigado con el spike de Sprint 1 y el fallback Hive.
- Codegen extra (`drift_dev` además de `riverpod_generator`) → el ciclo de `build_runner` es más largo.
- Si el spike falla, hay costo de migración a Hive que invalida parte del schema diseñado para Drift.

### Neutras
- La cola `pending_op` vive **solo en local** — no existe en el schema Postgres. Verificado por test pgTAP en `supabase/tests/`.
- Los archivos `*.g.dart` de Drift se commitean al repo, alineado con la convención de Riverpod ([ADR-0003](0003-riverpod-codegen.md)).

## Cumplimiento / verificación

- Spike Sprint 1: [COMA-004](../spikes/COMA-004-drift-web.md) cerrado con `spike-done` el 2026-05-07. Drift opera sobre IndexedDB en CanvasKit con INSERT/SELECT/DELETE persistentes entre recargas y consistentes entre pestañas; no se gatilla el fallback a Hive.
- Si el spike falla → ADR sucesor antes de cerrar Sprint 1. *(No aplicó.)*
- Tests de integración (Sprint 3+): pedido offline persiste y sobrevive a reinicio (RNF-REL-002, CA-003).
- Test pgTAP: `pending_op` no existe en schema público de Supabase (ver `supabase/tests/`).

## Referencias

- [SRS § 4.4 Reliability](../../requirements/srs.md) — RNF-REL-001, RNF-REL-002.
- [SRS § 5 Casos de aceptación](../../requirements/srs.md) — CA-003, CA-004.
- [Sync offline-first](../../sync/offline-first.md).
- ADRs relacionados: [ADR-0001](0001-flutter-multiplataforma.md), [ADR-0008](0008-sync-offline-first-fifo-lww.md).
