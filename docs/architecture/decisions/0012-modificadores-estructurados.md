---
adr: 0012
title: Modificadores estructurados con comentario libre
status: proposed
date: 2026-05-13
deciders: Benjamin Lopez, Claude, Codex
tags: [adr, persistencia, pedidos]
---

# ADR 0012 — Modificadores estructurados con comentario libre

## Contexto

Los pedidos gastronomicos tienen personalizaciones repetibles y analizables: agregado de queso, salsa, punto de coccion, tamaño, opcion vegana. Tambien existen instrucciones raras y de baja frecuencia que no conviene modelar como catalogo.

La decision de producto confirma que `modifier` y `comment` conviven: el primero es estructurado, valorizable y analizable; el segundo es texto libre opcional.

## Decision

Agregamos `menu_item_modifier_group`, `menu_item_modifier` y `order_item_modifier`. Mantenemos `order_item.comment TEXT NULL` para personalizaciones libres.

Reglas:

- `menu_item_modifier_group` pertenece a un `menu_item` y define `is_required` y `selection` (`single | multiple`).
- `menu_item_modifier` pertenece a un grupo y define `price_delta_cents`, que puede ser positivo, cero o negativo.
- `order_item_modifier` captura el modificador aplicado y guarda `price_delta_cents_snapshot`.
- El total del pedido se calcula como `SUM(order_item.quantity * (price_cents_snapshot + SUM(order_item_modifier.price_delta_cents_snapshot))) + tip - discount`.
- Los modificadores aplicados son inmutables cuando el pedido deja `open`.

## Alternativas consideradas

### Opcion A — Solo `comment` libre
- **Pros:** Rapido de implementar; flexible.
- **Contras:** No permite precio delta, analitica ni control de opciones obligatorias.
- **Por que se descarto:** No sirve para POS con caja ni margen real.

### Opcion B — Texto libre con parsing posterior
- **Pros:** Mantiene UI simple.
- **Contras:** Parsing fragil, no auditable, mala experiencia para cocina/caja.
- **Por que se descarto:** Introduce IA innecesaria en un flujo que debe ser deterministico.

### Opcion C — Modificadores estructurados + `comment` (elegida)
- **Pros:** Cubre opciones repetibles y excepciones; total calculable; data analizable.
- **Contras:** Requiere UI de grupos y validaciones por selection.
- **Por que se eligio:** Es el equilibrio correcto para locales micro sin perder flexibilidad.

## Consecuencias

### Positivas
- Caja cobra exactamente lo que se pidio.
- BI puede medir preferencias y upgrades.
- Cocina recibe opciones claras sin perder instrucciones libres.

### Negativas / costo
- Requiere snapshot de precio para preservar historico si cambia el menu.
- La validacion completa de `single/multiple` debe vivir en RPC y UI.

### Neutras
- `comment` no participa del total.
- Los nombres de modifier se leen del catalogo; si se requiere snapshot de nombre, se agregara en migracion futura.

## Cumplimiento / verificacion

- Migracion `0005_modifiers.sql`.
- Trigger `compute_order_total()` incluye modificadores, propina y descuento.
- RPC `apply_order_item_modifier()` captura `price_delta_cents_snapshot`.
- pgTAP verifica RLS, triggers y tablas.

## Referencias

- [Glosario](../../product/glossary.md)
- [database/model.md](../../database/model.md)
- [api/contracts.md](../../api/contracts.md)
