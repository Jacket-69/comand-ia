---
adr: 0009
title: Roles granulares y permisos operativos
status: proposed
date: 2026-05-13
deciders: Benjamin Lopez, Claude, Codex
tags: [adr, seguridad, permisos, persistencia]
---

# ADR 0009 — Roles granulares y permisos operativos

## Contexto

El schema inicial distingue solo `owner` y `staff`. Ese corte sirve para validar multi-tenancy, pero no representa la operacion real de un POS gastronomico: quien toma pedidos no necesariamente cobra, quien cobra no necesariamente ajusta stock, y cocina debe poder marcar preparacion sin acceder a caja ni configuracion.

El nuevo alcance de COMAND-IA define cinco roles: `owner`, `manager`, `cashier`, `waiter` y `kitchen`. Todos operan dentro de un `venue`; el owner entra por magic link y los roles no-owner usan PIN hasheado en `staff_pin`.

## Decision

Expandimos `app_role` a los cinco roles operativos y usamos esos roles como base de RLS, RPCs y validaciones de triggers.

`staff` queda como valor legado del ENUM durante la etapa forward-only, pero no se usa para nuevas filas: la migracion cambia el default a `waiter` y normaliza filas existentes `staff -> waiter`.

### Matriz rol x capacidad

| Capacidad | owner | manager | cashier | waiter | kitchen |
|---|---:|---:|---:|---:|---:|
| Configurar `venue` y usuarios | si | no | no | no | no |
| Leer menu, mesas y pedidos del venue | si | si | si | si | si |
| Crear pedido y agregar items/modifiers | si | si | no | si | no |
| Marcar items `preparing` / `ready` | si | si | no | no | si |
| Enviar pedido a caja (`to_pay`) | si | si | no | si | no |
| Abrir/cerrar `cash_session` | si | si | si | no | no |
| Registrar `order_payment` | si | si | si | no | no |
| Aplicar propina | si | si | si | no | no |
| Aplicar descuento bajo umbral | si | si | si | si | no |
| Aplicar descuento sobre umbral | si | si | no | no | no |
| Anular pedido o item listo | si | si | no | no | no |
| Crear/editar recetas e insumos | si | si | no | no | no |
| Registrar compras, mermas o ajustes de stock | si | si | no | no | no |
| Leer disponibilidad de stock | si | si | si | si | si |

El umbral de descuento permitido para `waiter` vive en `venue.max_waiter_discount_cents`. Su default es `0`, de modo que el garzon no puede aplicar descuentos salvo que owner/manager lo habilite.

### PIN

Los roles `manager`, `cashier`, `waiter` y `kitchen` se autentican por PIN. `staff_pin` mantiene `pin_hash`, contador de intentos, bloqueo temporal y validacion mediante `verify_pin()` `SECURITY DEFINER`. El cliente nunca lee `pin_hash`.

### RLS

Las policies usan `current_app_user()` / `current_app_role()` como equivalente local a claims de JWT. En Supabase esto evita depender de claims custom aun no emitidos por el frontend y mantiene una sola fuente de verdad: `app_user.role`.

## Alternativas consideradas

### Opcion A — Mantener `owner | staff`
- **Pros:** Menos cambios de schema y frontend.
- **Contras:** No permite defender caja, inventario ni descuentos por rol; obliga a esconder capacidades solo en UI.
- **Por que se descarto:** Caja e inventario requieren separacion real de responsabilidades.

### Opcion B — Roles solo en JWT custom
- **Pros:** Policies mas directas con `current_setting('jwt.claims.role')`.
- **Contras:** Hay que sincronizar claims con `app_user`; el PIN staff no calza bien con el owner magic-link inicial.
- **Por que se descarto:** Para el MVP la tabla `app_user` ya es la fuente confiable de venue y rol.

### Opcion C — Roles granulares en `app_user` (elegida)
- **Pros:** RLS testeable en SQL; roles editables por owner; no depende de claims custom.
- **Contras:** Las policies llaman funciones helper y requieren cuidado para no crear recursion RLS.
- **Por que se eligio:** Encaja con ADR-0005 y con el flujo actual de `verify_pin()`.

## Consecuencias

### Positivas
- Los permisos reflejan la operacion real del local.
- Caja, cocina e inventario dejan de depender de controles de UI.
- Cada tabla nueva puede declarar rol minimo en RLS y pgTAP.

### Negativas / costo
- El valor legado `staff` no puede eliminarse del ENUM sin una migracion destructiva posterior.
- Las funciones `SECURITY DEFINER` deben mantenerse pequenas y auditables.

### Neutras
- El frontend debe regenerar tipos Supabase y adaptar labels de rol.
- El owner sigue siendo el unico rol con poder de configuracion de venue.

## Cumplimiento / verificacion

- Migracion `0002_pos_extensions.sql` agrega roles, helper `current_app_role()` y policies de `customer_order`.
- Tests pgTAP verifican que las nuevas tablas con `venue_id` tienen RLS/policies y que las policies clave existen.
- Code review: cualquier RPC nueva declara rol minimo y valida `current_venue_id()`.

## Referencias

- [ADR-0005](0005-multi-tenancy-rls-deny-by-default.md)
- [Glosario](../../product/glossary.md)
- [database/rls.md](../../database/rls.md)
