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
| HU-A02 | Como **garzón** quiero ingresar con mi nombre y un PIN corto para empezar mi turno sin usar email. | RF-AUTH-002, RF-AUTH-004 |
| HU-A03 | Como **owner** quiero que el sistema bloquee a un PIN tras 5 intentos fallidos para evitar fuerza bruta. | RF-AUTH-003 |
| HU-A04 | Como **owner** quiero invitar a un garzón con un PIN nuevo para que pueda usar la app desde su primera jornada. | RF-AUTH-005 |
| HU-A05 | Como **usuario** quiero hacer logout explícito para liberar la tablet a otro turno sin dejar mi sesión abierta. | RF-AUTH-006 |

## Épica MENU — gestión del menú

| ID | Historia | RFs |
|---|---|---|
| HU-M01 | Como **owner** quiero crear categorías ordenadas para que el garzón vea el menú estructurado. | RF-MENU-001 |
| HU-M02 | Como **owner** quiero crear ítems con nombre y precio para que aparezcan en la toma de pedido. | RF-MENU-002, RF-MENU-005 |
| HU-M03 | Como **owner** quiero editar nombre y precio sin afectar pedidos pasados para corregir errores sin reescribir la historia. | RF-MENU-003 |
| HU-M04 | Como **owner** quiero desactivar un ítem temporalmente para sacar lo que se acabó sin perder su historial. | RF-MENU-004 |
| HU-M05 | Como **owner** quiero importar el menú desde un CSV para no tipear ítem por ítem en el onboarding. | RF-MENU-006 |

## Épica ORDER — toma de pedido

| ID | Historia | RFs |
|---|---|---|
| HU-O01 | Como **garzón** quiero seleccionar una mesa y agregar ítems con cantidad y comentario para tomar el pedido sin libreta. | RF-ORDER-001 |
| HU-O02 | Como **garzón** quiero que el pedido funcione sin internet para no perder ventas si se cae la red. | RF-ORDER-002, RNF-REL-001 |
| HU-O03 | Como **garzón** quiero que los pedidos pendientes se sincronicen al volver la red para que cocina y owner los vean automáticamente. | RF-ORDER-003, RF-ORDER-004 |
| HU-O04 | Como **garzón** quiero ver el total del pedido al instante para confirmarlo con el cliente. | RF-ORDER-005 |
| HU-O05 | Como **garzón** quiero agregar más ítems a un pedido abierto para cubrir las "uno más" del cliente. | RF-ORDER-006 |
| HU-O06 | Como **garzón** quiero cerrar el pedido eligiendo método de pago y dejar el estado terminal para imprimir/leer el ticket sin riesgo de cambios accidentales. | RF-ORDER-007 |
| HU-O07 | Como **garzón** quiero ver el estado de cada mesa de un vistazo (libre / pedido abierto / pedido listo) para priorizar mi atención. | RF-ORDER-008 |

## Épica KDS — pantalla cocina

| ID | Historia | RFs |
|---|---|---|
| HU-K01 | Como **cocinero** quiero ver los pedidos llegando en tiempo real para preparar sin esperar al garzón. | RF-KDS-001, RNF-PERF-004 |
| HU-K02 | Como **cocinero** quiero marcar el pedido como `preparing` y luego `ready` para que el garzón sepa cuándo retirarlo. | RF-KDS-002 |
| HU-K03 | Como **cocinero** quiero ver mesa, ítems, cantidad y comentarios en cada tarjeta para preparar sin pedir aclaraciones. | RF-KDS-003 |
| HU-K04 | Como **cocinero** quiero distinguir visualmente los `ready` para no perderlos en el flujo. | RF-KDS-004 |

## Épica ANALY — analítica del owner

| ID | Historia | RFs |
|---|---|---|
| HU-AN01 | Como **owner** quiero ver ventas totales por día / 7 días / 30 días para saber cómo va el local sin abrir Excel. | RF-ANALY-001 |
| HU-AN02 | Como **owner** quiero ver mis 5 ítems más vendidos para decidir qué empujar y qué sacar del menú. | RF-ANALY-002 |
| HU-AN03 | Como **owner** quiero ver el ticket promedio para saber si los clientes están gastando más o menos esta semana. | RF-ANALY-003 |
| HU-AN04 | Como **owner** quiero ver mi hora pico para planificar mejor la dotación. | RF-ANALY-004 |
| HU-AN05 | Como **owner** quiero cambiar el periodo del dashboard sin recargar la página para explorar rápido los datos. | RF-ANALY-005 |
| HU-AN06 | Como **owner** quiero exportar los datos a CSV compatible con Excel chileno para llevarlos al contador o a una planilla propia. | RF-ANALY-006 |
| HU-AN07 | Como **owner** quiero que el dashboard responda rápido (≤1.5 s para 30 días) para no interrumpir mi flujo. | RF-ANALY-007, RNF-PERF-003 |

## Épica TENANT — multi-tenancy y onboarding

| ID | Historia | RFs |
|---|---|---|
| HU-T01 | Como **owner nuevo** quiero crear mi venue al primer login para empezar el onboarding sin formularios extra. | RF-TENANT-001 |
| HU-T02 | Como **owner** quiero estar 100% seguro de que ningún otro local ve mis pedidos para no exponer mi negocio. | RF-TENANT-002, RF-TENANT-003, RNF-SEC-001..002 |
| HU-T03 | Como **owner** quiero agregar mesas a mi venue con etiqueta y capacidad para que el garzón las vea en la toma de pedido. | RF-TENANT-004 |

## Notas

- Las HUs no son inmutables: si un RF cambia, la HU se actualiza en el mismo PR.
- El backlog operativo vive en GitHub Project **COMAND-IA — Sprints**. Esta lista es la **fuente narrativa**; el board es la fuente operativa con story points, asignación y estado.
- Para los criterios de aceptación detallados ver [acceptance-criteria.md](acceptance-criteria.md).
