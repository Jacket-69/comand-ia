# Historias de usuario por épica

> Historias derivadas de los RFs del [SRS](srs.md). Cada historia es un slice vertical demoable. Las épicas mapean a las features del codebase (`lib/features/`).

Formato:

```
HU-XX — Como <rol>, quiero <acción> para <beneficio>.
RFs cubiertos: RF-...
DoR: ver checklist en contributing.md
```

## Épica AUTH — autenticación

| ID | Historia | RFs |
|---|---|---|
| HU-A01 | Como **owner** quiero solicitar acceso por email para entrar al sistema sin recordar contraseña. | RF-AUTH-001 |
| HU-A02 | Como **staff** (manager, cashier, waiter, kitchen) quiero ingresar con mi nombre y un PIN corto para empezar mi turno sin usar email. | RF-AUTH-002, RF-AUTH-004 |
| HU-A03 | Como **owner** quiero que el sistema bloquee a un PIN tras 5 intentos fallidos para evitar fuerza bruta. | RF-AUTH-003 |
| HU-A04 | Como **owner** o **manager** quiero invitar a un staff con su rol y un PIN nuevo para que pueda usar la app desde su primera jornada con permisos correctos. | RF-AUTH-005 |
| HU-A05 | Como **usuario** quiero hacer logout explícito para liberar la tablet a otro turno sin dejar mi sesión abierta. | RF-AUTH-006 |
| HU-A06 | Como **desarrollador** quiero que la sesión exponga el rol del usuario para que las policies RLS y la UI no tengan que re-llamar al RPC de validación en cada operación. | RF-AUTH-007 |

## Épica MENU — gestión del menú

| ID | Historia | RFs |
|---|---|---|
| HU-M01 | Como **owner** o **manager** quiero crear categorías ordenadas para que el garzón vea el menú estructurado. | RF-MENU-001 |
| HU-M02 | Como **owner** o **manager** quiero crear ítems con nombre y precio para que aparezcan en la toma de pedido. | RF-MENU-002, RF-MENU-005 |
| HU-M03 | Como **owner** o **manager** quiero editar nombre y precio sin afectar pedidos pasados para corregir errores sin reescribir la historia. | RF-MENU-003 |
| HU-M04 | Como **owner** o **manager** quiero desactivar un ítem temporalmente para sacar lo que se acabó sin perder su historial. | RF-MENU-004 |
| HU-M05 | Como **owner** quiero importar el menú desde un CSV para no tipear ítem por ítem en el onboarding. | RF-MENU-006 |

## Épica MODIFIER — modificadores de ítems

| ID | Historia | RFs |
|---|---|---|
| HU-MD01 | Como **owner** o **manager** quiero crear grupos de modificadores asociados a un ítem (ej. "Salsas", "Punto de cocción") para que el garzón ofrezca las opciones predefinidas. | RF-MODIFIER-001 |
| HU-MD02 | Como **owner** o **manager** quiero crear modificadores con precio delta dentro de un grupo (ej. "+queso $800", "sin cebolla $0") para que el cobro refleje las personalizaciones. | RF-MODIFIER-002 |
| HU-MD03 | Como **waiter** quiero aplicar modificadores al armar un ítem del pedido para que la cocina sepa exactamente cómo prepararlo y el cobro sea correcto. | RF-MODIFIER-003 |
| HU-MD04 | Como **owner** quiero que el sistema fije el precio del modificador al momento del pedido para que cambios futuros del catálogo no alteren pedidos viejos. | RF-MODIFIER-004 |
| HU-MD05 | Como **owner** quiero que el total del pedido considere los modificadores automáticamente para no calcularlos a mano. | RF-MODIFIER-005 |
| HU-MD06 | Como **waiter** quiero poder dejar un comentario libre opcional en un ítem ("que la cocción sea jugosa") para personalizaciones que no encajan en modificadores. | RF-MODIFIER-006 |

## Épica ORDER — toma de pedido

| ID | Historia | RFs |
|---|---|---|
| HU-O01 | Como **waiter** quiero seleccionar una mesa y agregar ítems con cantidad, modificadores y comentario para tomar el pedido sin libreta. | RF-ORDER-001 |
| HU-O02 | Como **waiter** quiero que el pedido funcione sin internet para no perder ventas si se cae la red. | RF-ORDER-002, RNF-REL-001 |
| HU-O03 | Como **waiter** quiero que los pedidos pendientes se sincronicen al volver la red para que cocina y owner los vean automáticamente. | RF-ORDER-003, RF-ORDER-004 |
| HU-O04 | Como **waiter** quiero ver el total del pedido al instante para confirmarlo con el cliente. | RF-ORDER-005 |
| HU-O05 | Como **waiter** quiero agregar más ítems a un pedido abierto para cubrir las "uno más" del cliente. | RF-ORDER-006 |
| HU-O06 | Como **waiter** quiero enviar la cuenta a caja con un solo gesto para que la cajera la procese sin que yo deba acompañar al cliente. | RF-ORDER-007 |
| HU-O07 | Como **waiter** quiero ver el estado de cada mesa de un vistazo (libre / con pedido / listo / en caja) para priorizar mi atención. | RF-ORDER-009 |
| HU-O08 | Como **desarrollador** quiero que el modelo de datos reserve `service_type` por pedido aunque solo se use `dine_in` en la UI inicial para no migrar el schema cuando entre take-away o delivery. | RF-ORDER-010 |

## Épica KDS — pantalla cocina

| ID | Historia | RFs |
|---|---|---|
| HU-K01 | Como **kitchen** quiero ver los pedidos llegando en tiempo real para preparar sin esperar al garzón. | RF-KDS-001, RNF-PERF-004 |
| HU-K02 | Como **kitchen** quiero marcar el pedido como `preparing` y luego `ready` para que el garzón sepa cuándo retirarlo. | RF-KDS-002 |
| HU-K03 | Como **kitchen** quiero ver mesa, ítems, cantidad, modificadores y comentarios en cada tarjeta para preparar sin pedir aclaraciones. | RF-KDS-003 |
| HU-K04 | Como **kitchen** quiero distinguir visualmente los `ready` para no perderlos en el flujo. | RF-KDS-004 |
| HU-K05 | Como **owner** quiero que el stock se descuente automáticamente cuando la cocina marca un ítem como `ready` para no tener que registrar consumo a mano. | RF-KDS-005, RF-INVENTORY-004 |
| HU-K06 | Como **owner** quiero que cancelar un ítem que ya pasó por cocina reverse el descuento de stock para no acumular pérdidas fantasma. | RF-KDS-006 |

## Épica CASHIER — caja y cobro

| ID | Historia | RFs |
|---|---|---|
| HU-C01 | Como **cashier** quiero abrir mi sesión de caja declarando el monto inicial para empezar el turno con cuadre claro. | RF-CASHIER-001 |
| HU-C02 | Como **cashier** quiero cobrar un pedido en `to_pay` registrando el método de pago y monto para cerrar la cuenta del cliente. | RF-CASHIER-002 |
| HU-C03 | Como **cashier** quiero dividir la cuenta entre varios pagos (efectivo + tarjeta, o 4 amigos por separado) para reflejar el cobro real. | RF-CASHIER-002 |
| HU-C04 | Como **waiter** o **cashier** quiero registrar la propina del cliente como parte del pedido para que el cobro la incluya. | RF-CASHIER-003 |
| HU-C05 | Como **cashier** quiero aplicar descuentos pequeños bajo el umbral configurado por el venue para resolver fricciones menores sin escalar al manager. | RF-CASHIER-004 |
| HU-C06 | Como **manager** u **owner** quiero autorizar descuentos sobre el umbral del cashier para mantener control sobre rebajas significativas. | RF-CASHIER-004 |
| HU-C07 | Como **cashier** quiero registrar movimientos de caja no asociados a pedido (ingreso de respaldo, retiro para gastos) con motivo para que el arqueo cuadre. | RF-CASHIER-005 |
| HU-C08 | Como **cashier** quiero cerrar mi sesión declarando el monto contado y ver la diferencia con lo esperado para detectar errores antes de irme. | RF-CASHIER-006 |
| HU-C09 | Como **manager** quiero devolver un pedido de `to_pay` a `ready` cuando hay error de cobro para corregir sin anular. | RF-CASHIER-007 |
| HU-C10 | Como **manager** u **owner** quiero anular un pedido ya `closed` con motivo explícito para resolver reclamos legítimos, sabiendo que el stock se restituye. | RF-CASHIER-008 |

## Épica INVENTORY — inventario y costeo

| ID | Historia | RFs |
|---|---|---|
| HU-I01 | Como **owner** o **manager** quiero crear insumos con nombre, unidad y costo unitario para tener el inventario base del local. | RF-INVENTORY-001 |
| HU-I02 | Como **owner** o **manager** quiero definir la receta de un plato (qué insumos y cuánto consume cada uno) para que el sistema descuente stock solo. | RF-INVENTORY-002 |
| HU-I03 | Como **owner** o **manager** quiero registrar una compra de insumos con cantidad y costo para mantener el stock actualizado y reflejar variaciones de precio. | RF-INVENTORY-003 |
| HU-I04 | Como **owner** quiero que el stock se descuente automáticamente cuando la cocina marca un ítem `ready` para dejar de contar a mano. | RF-INVENTORY-004 (= RF-KDS-005) |
| HU-I05 | Como **owner** o **manager** quiero registrar mermas y ajustes manuales con motivo para reconciliar la realidad con el sistema sin perder auditoría. | RF-INVENTORY-005 |
| HU-I06 | Como **owner** quiero consultar el stock actual de cualquier insumo en cualquier momento para decidir si compro hoy. | RF-INVENTORY-006 |
| HU-I07 | Como **owner** quiero recibir alerta visible cuando un insumo cae bajo su umbral para no llegar al cero por descuido. | RF-INVENTORY-007 |
| HU-I08 | Como **owner** quiero ver el costo de producción y margen real de cada plato para decidir precios y promociones con datos. | RF-INVENTORY-008 |
| HU-I09 | Como **owner** quiero que los movimientos de stock sean append-only para que la historia de inventario sea auditable y no se pueda "limpiar" desde la app. | RF-INVENTORY-009 |

## Épica ANALY — analítica básica del owner

| ID | Historia | RFs |
|---|---|---|
| HU-AN01 | Como **owner** quiero ver ventas totales por día / 7 días / 30 días para saber cómo va el local sin abrir Excel. | RF-ANALY-001 |
| HU-AN02 | Como **owner** quiero ver mis 5 ítems más vendidos para decidir qué empujar y qué sacar del menú. | RF-ANALY-002 |
| HU-AN03 | Como **owner** quiero ver el ticket promedio para saber si los clientes están gastando más o menos esta semana. | RF-ANALY-003 |
| HU-AN04 | Como **owner** quiero ver mi hora pico para planificar mejor la dotación. | RF-ANALY-004 |
| HU-AN05 | Como **owner** quiero cambiar el periodo del dashboard sin recargar la página para explorar rápido los datos. | RF-ANALY-005 |
| HU-AN06 | Como **owner** quiero exportar los datos a CSV compatible con Excel chileno para llevarlos al contador o a una planilla propia. | RF-ANALY-006 |
| HU-AN07 | Como **owner** quiero que el dashboard responda rápido (≤1.5 s para 30 días) para no interrumpir mi flujo. | RF-ANALY-007, RNF-PERF-003 |
| HU-AN08 | Como **owner** quiero ver alertas de stock bajo y margen estimado por plato en el dashboard para cruzar la información operativa con la económica. | RF-ANALY-008 |

## Épica TENANT — multi-tenancy y onboarding

| ID | Historia | RFs |
|---|---|---|
| HU-T01 | Como **owner nuevo** quiero crear mi venue al primer login para empezar el onboarding sin formularios extra. | RF-TENANT-001 |
| HU-T02 | Como **owner** quiero estar 100% seguro de que ningún otro local ve mis datos (pedidos, caja, inventario) para no exponer mi negocio. | RF-TENANT-002, RF-TENANT-003, RNF-SEC-001..002 |
| HU-T03 | Como **owner** o **manager** quiero agregar mesas a mi venue con etiqueta y capacidad para que el garzón las vea en la toma de pedido. | RF-TENANT-004 |
| HU-T04 | Como **owner** quiero configurar por venue el umbral de descuento que puede aplicar un cashier sin autorización para ajustar las políticas a mi negocio. | RF-TENANT-005 |

## Notas

- Las HUs no son inmutables: si un RF cambia, la HU se actualiza en el mismo PR.
- El backlog operativo vive en GitHub Project **COMAND-IA — Sprints**. Esta lista es la **fuente narrativa**; el board es la fuente operativa con story points, asignación y estado.
- Para los criterios de aceptación detallados ver [acceptance-criteria.md](acceptance-criteria.md).
- Los identificadores `cashier`, `waiter`, `manager`, `kitchen`, `stock_item`, `cash_session`, `menu_item_recipe`, `modifier_group`, etc. son canónicos — definidos en [product/glossary.md](../product/glossary.md). No usar sinónimos.
