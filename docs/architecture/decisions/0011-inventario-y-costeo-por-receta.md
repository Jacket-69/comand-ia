---
adr: 0011
title: Inventario y costeo por receta
status: proposed
date: 2026-05-13
deciders: Benjamin Lopez, Claude, Codex
tags: [adr, persistencia, inventario]
---

# ADR 0011 — Inventario y costeo por receta

## Contexto

El producto promete que el dueño deje de comprar por intuicion y conozca margen real por plato. Para eso no basta con listar productos del menu: cada `menu_item` necesita una receta que consuma `stock_item` al momento operativo correcto.

La decision de alcance ya fija que el consumo ocurre cuando un `order_item` pasa a `ready`. Si se descuenta al confirmar, se castiga stock por platos que nunca se prepararon; si se descuenta al cobrar, cocina puede dejar stock ficticio durante el servicio.

## Decision

Modelamos inventario con `stock_item`, `menu_item_recipe` y `stock_movement` append-only. El stock actual se calcula con la funcion `stock_current(stock_item_id)` y se expone tambien mediante la vista `stock_item_current`.

Elegimos funcion/vista normal sobre vista materializada porque el MVP prioriza consistencia inmediata y bajo volumen; una vista materializada requeriria refrescos y podria mostrar stock obsoleto justo durante servicio.

Reglas:

- `stock_item.unit_of_measure`: `gram | kilogram | milliliter | liter | unit`.
- `menu_item_recipe`: relacion N:M con cantidad `qty NUMERIC(12,3)`.
- `stock_movement.type`: `entry | consumption | adjustment | waste`.
- Al actualizar `order_item.status` a `ready`, el trigger inserta un `stock_movement` `consumption` por cada insumo de la receta, con `qty = recipe.qty * order_item.quantity`.
- Si el item pasa de `ready` a `cancelled`, el trigger inserta movimientos inversos vinculados por `related_movement_id`.
- `menu_item_cost(menu_item_id)` devuelve el costo de produccion actual como suma de receta por costo unitario actual.

## Alternativas consideradas

### Opcion A — Columna `stock_qty` mutable en `stock_item`
- **Pros:** Lectura simple.
- **Contras:** Dificil de auditar; anulaciones y mermas sobrescriben historia.
- **Por que se descarto:** El stock debe ser explicable y reversible.

### Opcion B — Vista materializada de stock actual
- **Pros:** Lectura rapida para inventarios grandes.
- **Contras:** Requiere refresh; puede quedar atrasada en servicio; agrega complejidad operacional.
- **Por que se descarto:** El volumen academico/micro no justifica stale data.

### Opcion C — Movimientos append-only + funcion (elegida)
- **Pros:** Auditabilidad, reversas explicitas y consistencia inmediata.
- **Contras:** Cada lectura calcula una suma; puede requerir materializacion futura si crece el volumen.
- **Por que se eligio:** Es la base contable mas simple y defendible.

## Consecuencias

### Positivas
- Stock y costo por plato quedan derivados de fuentes auditables.
- Cancelaciones post-`ready` no borran consumo; generan reversa.
- El owner puede explicar mermas, compras y consumo por pedido.

### Negativas / costo
- Requiere recetas cargadas para que el descuento automatico tenga efecto.
- `stock_current()` puede necesitar indices y/o materializacion en venues con mucho volumen.

### Neutras
- El stock negativo no se bloquea en MVP; se alerta como deuda operacional para no impedir servicio.
- Compras estructuradas con `supplier` y `purchase_order` quedan diferidas.

## Cumplimiento / verificacion

- Migracion `0004_inventory.sql`.
- Trigger `trg_order_item_ready_stock_consumption`.
- Trigger `trg_order_item_cancelled_stock_reverse`.
- pgTAP verifica existencia de tablas, RLS, funcion de costo y triggers.

## Referencias

- [Glosario](../../product/glossary.md)
- [database/model.md](../../database/model.md)
- [docs/api/contracts.md](../../api/contracts.md)
