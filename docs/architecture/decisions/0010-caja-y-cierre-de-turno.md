---
adr: 0010
title: Caja y cierre de turno
status: proposed
date: 2026-05-13
deciders: Benjamin Lopez, Claude, Codex
tags: [adr, persistencia, caja, seguridad]
---

# ADR 0010 — Caja y cierre de turno

## Contexto

El alcance vigente separa tomar pedidos de cobrar. El garzon puede enviar la cuenta a caja, pero la cajera necesita una sesion auditable con apertura, pagos, movimientos manuales y cierre con arqueo. La division de cuenta no es un pedido nuevo: son varios pagos contra un mismo `customer_order`.

La propina y el descuento pertenecen al pedido completo, aunque se paguen en cuotas o con metodos distintos. Por eso no deben vivir en `order_payment`.

## Decision

Agregamos un modelo de caja compuesto por `cash_session`, `cash_movement` y `order_payment`, mas el estado `to_pay` entre `ready` y `closed`.

- `cash_session`: turno de caja de un cajero, con apertura, cierre, monto declarado, esperado y diferencia.
- `cash_movement`: ingreso/retiro/ajuste de efectivo que no corresponde a un pago de pedido.
- `order_payment`: pago parcial o total aplicado a un `customer_order`.
- `customer_order.tip_amount_cents` y `customer_order.discount_amount_cents`: montos del pedido, incluidos en `total_cents`.

Reglas de negocio:

- Solo puede existir una `cash_session` abierta por `cashier_id`.
- `close_cash_session(session_id, declared_amount_cents)` calcula `expected_amount_cents` y `difference_cents`.
- `register_payment(order_id, cash_session_id, method, amount_cents)` valida pedido `to_pay`, sesion abierta y que la suma no exceda `customer_order.total_cents`.
- Cuando la suma de pagos alcanza el total, el pedido pasa a `closed`.
- `to_pay` significa que el garzon ya envio la cuenta a caja y la cajera puede procesarla.

## Alternativas consideradas

### Opcion A — Guardar un solo `payment_method` en `customer_order`
- **Pros:** Simple; ya existe en `0001_init.sql`.
- **Contras:** No permite dividir cuenta, auditar caja ni calcular arqueo por turno.
- **Por que se descarto:** No cubre el flujo de cajera ni el cierre de caja.

### Opcion B — Propina/descuento por pago
- **Pros:** Parece natural cuando cada persona paga su parte.
- **Contras:** La propina y el descuento modifican el total del pedido, no la forma de pago; se duplican al dividir cuenta.
- **Por que se descarto:** Rompe invariantes contables.

### Opcion C — Modelo explicito de caja (elegida)
- **Pros:** Soporta division de cuenta, arqueo y auditoria; roles claros.
- **Contras:** Requiere RPCs transaccionales para no aceptar pagos inconsistentes.
- **Por que se eligio:** Es el minimo robusto para un POS real.

## Consecuencias

### Positivas
- La caja queda trazable por turno y cajero.
- Division de cuenta no requiere duplicar pedidos.
- El cierre compara monto declarado contra esperado.

### Negativas / costo
- Las operaciones de caja requieren online obligatorio.
- El frontend debe distinguir `ready`, `to_pay` y `closed`.

### Neutras
- `customer_order.payment_method` queda como columna legacy hasta una migracion de limpieza posterior.
- El arqueo esperado cuenta pagos en efectivo y movimientos de caja; pagos no-efectivo se auditan por `order_payment`.

## Cumplimiento / verificacion

- Migracion `0003_cash_sessions.sql`.
- Constraint unica parcial: una sesion `open` por `cashier_id`.
- RPCs `close_cash_session()` y `register_payment()` cubiertas por pgTAP.
- RLS: solo `cashier`, `manager` y `owner` insertan pagos.

## Referencias

- [ADR-0009](0009-roles-granulares-y-permisos.md)
- [database/model.md](../../database/model.md)
- [api/contracts.md](../../api/contracts.md)
