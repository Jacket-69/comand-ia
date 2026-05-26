# Glosario

> Lenguaje del dominio compartido entre el código, los docs y la conversación con el equipo. Si introduces un término nuevo del dominio, agrégalo acá en el mismo PR. **Esta es la fuente única de nombres canónicos**: las migraciones SQL, los identifiers en Dart, los ADRs y las HUs deben usar exactamente los términos definidos acá. No inventar sinónimos paralelos.

## Actores

| Término | Definición |
|---|---|
| **owner** | Dueño del local. Configura el venue, ve analítica completa, hace onboarding, decide ajustes mayores de stock. Se autentica con magic link al email. Rol con permisos máximos dentro de su venue. |
| **manager** | Encargado del local. Opera en ausencia del owner: maneja caja, autoriza descuentos y anulaciones, hace ajustes de stock. Mismos permisos que owner salvo configuración de venue y gestión de usuarios. Se autentica con PIN. |
| **cashier** (cajera) | Personal de caja. Abre y cierra sesiones de caja, cobra pedidos, divide cuentas, aplica propinas y descuentos pequeños. No toma pedidos en mesas. Se autentica con PIN. |
| **waiter** (garzón) | Personal de sala. Toma pedidos en mesas, agrega ítems y modificadores, envía la cuenta a caja, ve estado de sus mesas. No cobra. Se autentica con PIN. |
| **kitchen** (cocina) | Personal de cocina. Usa el KDS para ver pedidos llegando y marcarlos como `preparing` y `ready`. Se autentica con PIN; en locales pequeños puede compartir PIN con un `waiter` y diferenciar solo por vista. |

> Roles persistidos en el ENUM `app_role` como `owner | manager | cashier | waiter | kitchen`. La matriz de permisos vive en [ADR-0009](../architecture/decisions/0009-roles-granulares-y-permisos.md).

## Conceptos del producto

### Tenancy y autenticación

| Término | Definición |
|---|---|
| **venue** | Local gastronómico (tenant raíz del sistema). Una fila en `venue` = un local. Toda tabla con datos de negocio incluye `venue_id`. |
| **venue_id** | UUID que identifica a qué venue pertenece cada fila; eje del multi-tenant. Cero filas sin `venue_id`. |
| **magic link** | Enlace de autenticación sin contraseña enviado al email del owner. |
| **PIN** | Código numérico corto (4–6 dígitos) para identificar a un staff member (`manager`, `cashier`, `waiter`, `kitchen`). Hasheado en Postgres con `pgcrypto.crypt()`. Validado por RPC `verify_pin()` SECURITY DEFINER. |
| **RLS** | Row-Level Security — mecanismo Postgres de control de acceso por fila. Ver [database/rls.md](../database/rls.md). |

### Mesas y pedidos

| Término | Definición |
|---|---|
| **dining_table** | Mesa del local (renombrado de `table` para evitar colisión con SQL). Tiene etiqueta visible, capacidad y estado derivado (libre / con pedido abierto / con pedido listo). |
| **customer_order** | Pedido (renombrado de `order` para evitar colisión con SQL). Vinculado a un `dining_table` (opcional según `service_type`) y a un `waiter` que lo abre. |
| **order_item** | Línea de un pedido: referencia un `menu_item`, una cantidad y opcionalmente un conjunto de modificadores. |
| **service_type** | Canal del pedido: `dine_in` (mesa), `takeaway` (retiro), `delivery` (despacho), `bar` (barra sin mesa). MVP usa `dine_in`; el campo existe para no migrar después. |
| **comment** | Texto libre opcional asociado a un `order_item`. Para personalizaciones no estructurables ("cocción jugosa"). Convive con `modifier` — no lo reemplaza. |

### Modificadores

| Término | Definición |
|---|---|
| **modifier_group** | Grupo de opciones de personalización asociado a un `menu_item` (ej. "Salsas", "Punto de cocción"). Tiene reglas: opcional/obligatorio, selección única o múltiple. |
| **modifier** | Opción concreta dentro de un `modifier_group` (ej. "mayonesa", "+queso", "término medio"). Tiene precio delta (positivo, cero o negativo). |
| **order_item_modifier** | Modificador efectivamente aplicado a un `order_item`. Inmutable una vez que el pedido pasa de `open`. Suma su precio delta al total del pedido. |

### Caja

| Término | Definición |
|---|---|
| **cash_session** | Sesión de caja para un cajero en un turno. Abre con monto inicial declarado; se cierra con arqueo (conteo declarado vs total esperado). Solo una `cash_session` abierta por cajero a la vez. |
| **cash_movement** | Movimiento de dinero asociado a una `cash_session` por una causa que **no es un pago de pedido**: ingreso de respaldo, retiro para gastos del local, ajuste manual. Auditable. |
| **order_payment** | Pago aplicado a un `customer_order`. Un pedido puede tener varios pagos (división de cuenta: 4 amigos pagan por separado). Cada pago tiene `payment_method` (`cash`, `card`, `transfer`, `other`) y monto. La suma de `order_payment` de un pedido cerrado = total del pedido. |
| **tip** | Propina. Atributo del `customer_order` (no de `order_payment`), porque la propina pertenece al pedido completo aunque se cobre en cuotas. |
| **discount** | Descuento aplicado al `customer_order`. Atributo del pedido. Solo `manager` u `owner` pueden aplicar descuentos sobre un umbral configurable. |
| **arqueo** | Acto de cerrar una `cash_session` declarando el monto físico contado. La diferencia con el esperado (calculado por la suma de `order_payment` en efectivo + `cash_movement`) queda registrada como `cash_difference`. |

### Inventario

| Término | Definición |
|---|---|
| **stock_item** | Insumo físico que el local compra y consume (tomate, queso mozzarella, harina, cerveza Heineken 330 ml). Tiene `unit_of_measure`, costo unitario actual y stock actual derivado. |
| **unit_of_measure** | Unidad estándar del insumo: `gram`, `kilogram`, `milliliter`, `liter`, `unit`. Cada `stock_item` tiene exactamente una. |
| **menu_item_recipe** | Relación N:M entre `menu_item` y `stock_item` con la cantidad consumida (ej. "1 hamburguesa clásica = 150 g de carne + 1 unidad de pan + 30 g de queso"). Es la receta. |
| **stock_movement** | Cambio en el stock de un `stock_item`. Tipos: `entry` (compra), `consumption` (descontado por receta al pasar un `order_item` a `ready`), `adjustment` (ajuste manual con motivo), `waste` (merma declarada). Append-only, auditable. |
| **stock_low_threshold** | Umbral configurable por `stock_item` debajo del cual se dispara una alerta visible para owner/manager. |
| **costing** | Cálculo del costo de producción de un `menu_item` a partir de su `menu_item_recipe` × costo unitario actual de cada `stock_item`. Permite calcular margen real por plato. |
| **supplier** | Proveedor de insumos (opcional, entra cuando se implemente compra estructurada). |
| **purchase_order** | Orden de compra a un `supplier` (opcional, futura). |

### Sincronización

| Término | Definición |
|---|---|
| **pending_op** | Operación pendiente de sincronización con Supabase (cola FIFO local en Drift). **No existe en Supabase.** |
| **LWW** | Last Write Wins — política de resolución de conflictos por `updated_at` server-side. Ver [sync/offline-first.md](../sync/offline-first.md). |
| **Drift** | ORM type-safe para Flutter con soporte SQLite (nativo) e IndexedDB (web). Persistencia local de la app. |

### Otros

| Término | Definición |
|---|---|
| **KDS** | Kitchen Display System — pantalla de cocina que muestra los pedidos en tiempo real. |
| **CLP** | Peso chileno. Precios y montos almacenados en **centavos (integer)** para evitar errores de punto flotante. |

## Estados

| Estado | Aplica a | Significado |
|---|---|---|
| `open` | `customer_order` | Pedido recién creado; el garzón puede agregar/quitar ítems y modificadores. |
| `sent` | `customer_order` | Pedido enviado a cocina; visible en KDS. |
| `preparing` | `customer_order`, `order_item` | Cocina lo está preparando. |
| `ready` | `customer_order`, `order_item` | Listo para servir. **Al pasar un `order_item` a `ready` se ejecutan los `stock_movement` de tipo `consumption` según su `menu_item_recipe`.** |
| `to_pay` | `customer_order` | Garzón envía la cuenta a la cajera. El pedido queda visible en la vista de caja. |
| `closed` | `customer_order` | Pedido cobrado por completo (suma de `order_payment` = total). **Estado terminal** — no se puede modificar (ACID-4). |
| `cancelled` | `customer_order`, `order_item` | Pedido o ítem cancelado. No suma al total. Si había `stock_movement` de tipo `consumption` asociado, se inserta un movimiento inverso. |
| `open` | `cash_session` | Sesión de caja activa para un cajero. |
| `closed` | `cash_session` | Sesión cerrada con arqueo. Estado terminal. |
| `entry` / `consumption` / `adjustment` / `waste` | `stock_movement` | Tipos de movimiento; ver tabla de Inventario. |
| `valid` / `invalid` / `blocked` | `verify_pin` (RPC) | Resultado de la validación de PIN. `blocked` se devuelve tras 5 intentos fallidos consecutivos. |

## Capas del producto

| Término | Significado |
|---|---|
| **Capa 1 — Operacional** | Pedidos + mesas + KDS + caja + modificadores + inventario + costeo. Núcleo del producto. **Alcance vigente.** |
| **Capa 2 — Inteligencia** | Dashboard + analítica + forecasting + recomendaciones IA. Sobre la data acumulada en Capa 1. Diferida; entra cuando hay volumen. |
| **Capa 3 — Distribución pública** | Mapa turismo regional B2G + marketplace. Roadmap diferido sin urgencia. La arquitectura ya la soporta. |

## Convenciones de nombres en código

- Identifiers en **inglés**: `OrderRepository`, `customerOrder`, `tableId`, `cashSessionId`, `stockMovement`.
- Renombres canónicos para evitar colisión con palabras reservadas SQL:
  - `dining_table` (no `table`)
  - `customer_order` (no `order`)
- Sufijos consistentes:
  - `*_cents` para todo monto monetario (siempre `int`).
  - `*_qty` para cantidades de inventario (decimal con precisión definida por `unit_of_measure`).
  - `*_at` para timestamps (`created_at`, `updated_at`, `closed_at`, `opened_at`).
  - `*_id` para foreign keys (`venue_id`, `dining_table_id`, `menu_item_id`, `cash_session_id`, `stock_item_id`).
- En español solo: commits, issues, PRs, docs, ADRs y comentarios opcionales en código.

## Términos académicos

| Término | Significado |
|---|---|
| **Avance 1** | Entrega académica 2026-04-28 — scaffolding ejecutable. |
| **Avance 2** | Entrega académica 2026-05-26 — Capa 1 demoable (alcance acotado del MVP académico, no la Capa 1 completa de visión). |
| **Defensa** | Entrega final 2026-07-07. |
| **DoR** | Definition of Ready — checklist para que una historia entre al sprint. Ver [contributing.md](../contributing.md). |
| **DoD** | Definition of Done — checklist para que una historia se cierre. Ver [quality/definition-of-done.md](../quality/definition-of-done.md). |
| **ADR** | Architecture Decision Record. Una decisión por archivo en formato MADR. Ver [architecture/decisions/](../architecture/decisions/). |

## Cómo agregar un término nuevo

1. Si aparece en código (clase, variable, función) en inglés y aún no está acá, **agrégalo en el mismo PR**.
2. Si reemplaza un término anterior, agrega ambos con nota cruzada (`X (antes Y)`).
3. Mantener agrupación temática (Tenancy, Mesas, Caja, Inventario, etc.) es obligatorio; orden alfabético dentro de cada grupo no lo es.
4. Si una migración SQL introduce una tabla nueva, su entrada en el glosario va en el mismo PR que la migración.
