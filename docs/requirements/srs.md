# SRS — COMAND-IA

> Documento de requisitos del sistema. Estructura **IEEE 29148**. Calidad mapeada a **ISO/IEC 25010:2011**.

---

## 1. Introducción

### 1.1 Propósito

Este documento especifica los requisitos funcionales y no funcionales de **COMAND-IA**, un POS gastronómico genérico para locales micro: gestión de pedidos, mesas, cocina, caja con cierre de turno e inventario con costeo por receta. La inteligencia (BI + recomendaciones IA) y la distribución pública (turismo regional B2G) son capas diferidas — la arquitectura las habilita, este SRS no las especifica.

Para la motivación del producto y los usuarios objetivo ver [product/vision.md](../product/vision.md). Para el lenguaje del dominio ver [product/glossary.md](../product/glossary.md).

### 1.2 Alcance

| Capa | Alcance | Estado en este SRS |
|---|---|---|
| **1 — Operacional** | Pedidos + mesas + KDS + caja + modificadores + inventario + costeo. | **Especificada** acá. |
| **2 — Inteligencia** | Dashboard + analítica + forecasting + recomendaciones IA. | Diferida. Se especificará cuando entre al alcance vigente. La sección 3.7 lista los RFs mínimos de dashboard básico que se construyen sobre la data acumulada por Capa 1. |
| **3 — Distribución pública** | Mapa turismo regional B2G + marketplace. | Diferida sin urgencia. La arquitectura (multi-tenant + RLS) la soporta sin refactor del modelo de datos. |

La arquitectura soporta multi-tenant (múltiples locales en la misma base de datos) desde Sprint 1 por diseño; el onboarding de múltiples venues por un mismo owner queda fuera del alcance vigente.

### 1.3 Definiciones y glosario

Glosario completo del dominio en [product/glossary.md](../product/glossary.md). **Los identificadores usados en este SRS (`cashier`, `cash_session`, `stock_item`, `menu_item_recipe`, `modifier_group`, `service_type`, etc.) son canónicos** — toda implementación, migración o ADR debe usarlos sin sinónimos.

### 1.4 Referencias

- [Architecture overview](../architecture/overview.md) — C4, modelo de datos, RLS, sync, contratos API.
- [Architecture decisions](../architecture/decisions/) — ADRs con el por qué de cada decisión técnica.
- [Acceptance criteria](acceptance-criteria.md) — escenarios Given-When-Then.
- [User stories](user-stories.md) — historias por épica.
- [contributing.md](../contributing.md) — convenciones de equipo, DoR, DoD, code review.

---

## 2. Descripción general

### 2.1 Perspectiva del producto

Para la perspectiva narrativa ver [product/vision.md](../product/vision.md). Resumen técnico: COMAND-IA es una app Flutter multiplataforma offline-first sobre Supabase BaaS que cubre la operación completa de un local gastronómico micro. Multi-tenant por `venue_id` desde Sprint 1.

### 2.2 Funciones principales

**Capa 1 — Operacional (alcance vigente)**

- Autenticación: magic link para owner, PIN + nombre para `manager`, `cashier`, `waiter`, `kitchen`.
- Gestión de menú: categorías, ítems con precio en CLP, modificadores estructurados con precio delta, recetas (qué insumos consume cada ítem).
- Toma de pedido por mesa con soporte offline (cola FIFO local), con modificadores aplicados a cada ítem y `comment` libre opcional.
- KDS realtime: cocina ve pedidos `sent/preparing` y cambia estado a `preparing` y luego `ready`.
- **Descuento automático de inventario** al pasar un `order_item` a `ready`, según `menu_item_recipe`.
- **Caja**: apertura de `cash_session` con monto inicial, cobro de pedidos en estado `to_pay`, división de cuenta (múltiples `order_payment` por `customer_order`), propinas, descuentos con umbral por rol, cierre con arqueo (declarado vs esperado) y registro de diferencia.
- **Inventario**: `stock_item` con `unit_of_measure`, costo unitario actual, alertas de stock bajo configurable, movimientos `entry/consumption/adjustment/waste` append-only, costeo por plato.
- Multi-tenant: RLS deny-by-default que aísla datos por `venue_id`.

**Capa 2 — Inteligencia (alcance acotado en este SRS)**

Acá se especifica únicamente el **dashboard básico** que se construye sobre la data de Capa 1. Forecasting y recomendaciones IA quedan fuera de este SRS.

- Dashboard owner: ventas/día, top 5 ítems, ticket promedio, hora pico, alertas de stock bajo, **margen por plato** (a partir del costeo de Capa 1).
- Filtros temporales: hoy / 7 días / 30 días.
- Exportación CSV con separador `;` y encoding chileno (UTF-8-BOM).

### 2.3 Personas

Ver [product/vision.md § Usuarios](../product/vision.md). Roles persistidos en el ENUM `app_role`: `owner | manager | cashier | waiter | kitchen`.

### 2.4 Restricciones

| Restricción | Detalle |
|---|---|
| **Flutter multiplataforma** | Un solo codebase para Android, iOS, web y desktop. Sin bifurcación de código por plataforma salvo adaptaciones de layout. |
| **Supabase free tier** | Hasta 500 MB DB, 200 conexiones realtime simultáneas, 2 M mensajes/mes. Suficiente para el piloto académico. |
| **AGPL-3.0** | Todo despliegue público debe publicar el código fuente derivado. |
| **Sin presupuesto operativo** | Stack en tier gratuito o open-source mientras el modelo de negocio no esté validado. |
| **Idioma** | Código e identifiers en inglés. Docs, commits, issues y ADRs en español. |
| **Genérico por configuración** | Capacidades específicas de un tipo de local (mesas, barra, take-away) se habilitan por configuración del venue, no por build separado. |
| **Migraciones forward-only** | Toda evolución del schema va en migraciones nuevas con índice creciente. `0001_init.sql` no se modifica. |

### 2.5 Suposiciones y dependencias

- Supabase permanece en tier free durante el piloto sin degradar realtime.
- Drift es viable en Flutter web (IndexedDB), validado por spike COMA-004. Fallback Hive disponible si surge regresión web ([ADR-0004](../architecture/decisions/0004-drift-persistencia-local.md)).
- Los locales gastronómicos target tienen conexión a internet **al menos intermitente** (el sistema tolera desconexión, no la asume permanente). La caja, sin embargo, exige conexión en el momento del cobro (ver § 4.4).
- Los locales reciben insumos con frecuencia (diaria/semanal): el modelo asume que entradas de stock se registran en el día de recepción, no en lotes históricos masivos.

---

## 3. Requisitos funcionales

Formato: `id | descripción imperativa | criterio de verificación`.

### 3.1 Auth (RF-AUTH)

| ID | Descripción | Criterio de verificación |
|---|---|---|
| RF-AUTH-001 | El sistema envía un magic link al email del owner cuando este solicita acceso. | El usuario recibe el correo en ≤60 s y el link expira en 24 h. |
| RF-AUTH-002 | El sistema autentica a un staff member (`manager`, `cashier`, `waiter`, `kitchen`) con su nombre y PIN de 4–6 dígitos asociado al venue. | PIN correcto retorna sesión con el rol del usuario; PIN incorrecto no. |
| RF-AUTH-003 | El sistema bloquea la autenticación por PIN tras 5 intentos fallidos consecutivos para el mismo usuario. | El 6° intento retorna error `blocked` aunque el PIN sea correcto. |
| RF-AUTH-004 | El sistema almacena el PIN hasheado con `pgcrypto.crypt()`; nunca persistido en texto plano. | La columna `pin_hash` no contiene el PIN original; solo `verify_pin()` SECURITY DEFINER lo valida. |
| RF-AUTH-005 | El owner (o `manager`) puede invitar a un staff member creando un perfil con nombre, rol y PIN en el panel de administración. | El staff nuevo puede autenticarse con ese PIN y obtener una sesión con el rol asignado. |
| RF-AUTH-006 | El sistema cierra sesión y limpia el estado local al hacer logout explícito. | Después del logout, navegar a ruta protegida redirige al login. |
| RF-AUTH-007 | El rol de la sesión es legible desde RLS y desde la app sin re-llamar al RPC de validación. | El JWT o el contexto de sesión expone `role` para que policies y UI lo consulten. |

### 3.2 Menú (RF-MENU)

| ID | Descripción | Criterio de verificación |
|---|---|---|
| RF-MENU-001 | El owner (o `manager`) puede crear una categoría de menú con nombre y orden de visualización. | La categoría aparece en la lista del garzón en el orden definido. |
| RF-MENU-002 | El owner (o `manager`) puede crear un ítem de menú con nombre, precio en CLP y categoría. | El ítem aparece en la pantalla de toma de pedido. |
| RF-MENU-003 | El owner (o `manager`) puede editar nombre y precio de un ítem existente. | Los cambios se reflejan en nuevos pedidos; pedidos existentes conservan el snapshot inmutable (ACID-2). |
| RF-MENU-004 | El owner (o `manager`) puede desactivar un ítem sin eliminarlo; los ítems inactivos no aparecen en la toma de pedido. | Un ítem inactivo no es seleccionable por el garzón. |
| RF-MENU-005 | El sistema almacena precios en centavos (integer). El frontend muestra el valor en CLP con formato local. | No hay errores de punto flotante en totales. |
| RF-MENU-006 | El owner puede importar ítems desde un archivo CSV con separador `;`. | Los ítems del CSV aparecen en el menú tras la importación exitosa. |

### 3.3 Modificadores (RF-MODIFIER)

| ID | Descripción | Criterio de verificación |
|---|---|---|
| RF-MODIFIER-001 | El owner (o `manager`) puede crear un `modifier_group` asociado a un `menu_item` con nombre, regla `is_required` y regla `selection` (`single` o `multiple`). | El grupo aparece como conjunto de opciones al seleccionar el ítem en la toma de pedido. |
| RF-MODIFIER-002 | El owner (o `manager`) puede crear un `modifier` dentro de un grupo con nombre y `price_delta_cents` (positivo, cero o negativo). | El modificador aparece como opción seleccionable bajo su grupo. |
| RF-MODIFIER-003 | El garzón aplica modificadores a un `order_item` durante la toma; las opciones obligatorias deben quedar resueltas antes de enviar a cocina. | Pedido con grupo `is_required` sin selección no permite cambiar el estado de `open` a `sent`. |
| RF-MODIFIER-004 | El sistema persiste `price_delta_cents_snapshot` en `order_item_modifier` al momento del pedido. | Editar el `price_delta_cents` del catálogo después no altera pedidos anteriores. |
| RF-MODIFIER-005 | El total del pedido considera el delta de cada modificador aplicado. | El trigger `compute_order_total()` suma `SUM(quantity × (menu_item.price + SUM(price_delta_cents_snapshot)))`. |
| RF-MODIFIER-006 | El sistema mantiene `order_item.comment` como TEXT NULL opcional para personalizaciones no estructurables. | Coexisten modificadores y comentario en el mismo `order_item`. El comentario no afecta el total. |

### 3.4 Pedidos (RF-ORDER)

| ID | Descripción | Criterio de verificación |
|---|---|---|
| RF-ORDER-001 | El `waiter` selecciona una mesa y agrega ítems del menú con cantidad, modificadores y comentario opcional. | El pedido refleja los ítems, cantidades, modificadores y comentarios seleccionados. |
| RF-ORDER-002 | El sistema persiste el pedido localmente antes de enviarlo a Supabase. | Con red desconectada, el pedido se guarda y la UI confirma OK. |
| RF-ORDER-003 | El sistema sincroniza los pedidos pendientes con Supabase cuando la conexión se restablece (FIFO). | Tras reconexión, `pending_op` se vacía en orden de creación. |
| RF-ORDER-004 | El sistema aplica backoff exponencial ante fallos de sync; tras 10 intentos notifica al owner. | El log de sync muestra los reintentos y la notificación se emite al superar 10. |
| RF-ORDER-005 | El total del pedido lo calcula un trigger Postgres (`compute_order_total`); el frontend nunca lo escribe directamente. | Modificar un `order_item` u `order_item_modifier` actualiza automáticamente `customer_order.total_cents`. |
| RF-ORDER-006 | El `waiter` puede agregar ítems a un pedido `open` o `sent` (mientras no haya pasado a `to_pay`). | Ítems adicionales se suman al total y se envían a la cocina. |
| RF-ORDER-007 | El `waiter` puede enviar la cuenta a caja cambiando el estado del pedido a `to_pay`. | El pedido queda visible en la vista de la cajera; el `waiter` ya no puede agregar ítems. |
| RF-ORDER-008 | Un pedido en estado `closed` es **terminal**. Ningún rol puede agregar, modificar ni anular ítems. | Trigger Postgres bloquea cualquier UPDATE de items, total, modificadores o payments en pedidos `closed`. (ACID-4) |
| RF-ORDER-009 | El sistema muestra el estado de cada mesa en la vista principal (libre / `open` / `sent` / `ready` / `to_pay`). | La vista de mesas refleja el estado en tiempo real. |
| RF-ORDER-010 | El sistema soporta `service_type` por pedido (`dine_in`, `takeaway`, `delivery`, `bar`); en alcance vigente solo `dine_in` está implementado en la UI, los demás valores existen en el modelo para no migrar después. | El ENUM `service_type` existe en `customer_order`; la UI solo expone `dine_in`. |

### 3.5 KDS / Cocina (RF-KDS)

| ID | Descripción | Criterio de verificación |
|---|---|---|
| RF-KDS-001 | La pantalla de cocina muestra en tiempo real todos los pedidos en estado `sent` o `preparing` del venue. | Nuevo ítem enviado por garzón aparece en KDS en ≤2 s. |
| RF-KDS-002 | El `kitchen` (o `waiter` con la vista habilitada en locales pequeños) puede cambiar el estado de un `order_item` a `preparing` y luego a `ready`. | El cambio de estado se propaga al garzón vía realtime en ≤2 s. |
| RF-KDS-003 | La pantalla KDS muestra mesa, ítems, cantidad, modificadores aplicados y comentarios para cada pedido. | La información coincide con lo registrado por el garzón. |
| RF-KDS-004 | Los pedidos `ready` se distinguen visualmente de los `preparing` y `sent`. | Diferencia de color o iconografía clara entre estados. |
| RF-KDS-005 | El sistema dispara `stock_movement` de tipo `consumption` automáticamente al pasar un `order_item` a `ready`, según `menu_item_recipe`. | Trigger Postgres `on_order_item_ready` inserta una fila en `stock_movement` por cada insumo de la receta con `qty = recipe.qty × order_item.quantity`. |
| RF-KDS-006 | Si un `order_item` pasa de `ready` a `cancelled`, el sistema inserta un `stock_movement` inverso referenciando el movimiento original. | Trigger Postgres `on_order_item_cancelled_after_ready` inserta `consumption` con cantidad negativa y `related_movement_id` apuntando al original. |

### 3.6 Caja (RF-CASHIER)

| ID | Descripción | Criterio de verificación |
|---|---|---|
| RF-CASHIER-001 | El `cashier` abre una `cash_session` declarando el monto inicial en centavos. | Se crea fila en `cash_session` con `status=open`; el cajero no puede abrir una segunda sesión hasta cerrar la actual (UNIQUE INDEX). |
| RF-CASHIER-002 | El `cashier` cobra un pedido en estado `to_pay` registrando uno o varios `order_payment` (división de cuenta) con `payment_method` (`cash` / `card` / `transfer` / `other`) y monto. | Cada pago se asocia a la `cash_session` activa; la suma de pagos de un pedido no puede exceder su total; al alcanzar el total, el pedido pasa a `closed`. |
| RF-CASHIER-003 | El `waiter` o el `cashier` puede aplicar una propina (`tip_amount_cents`) al pedido antes de cerrar. La propina suma al total. | El trigger `compute_order_total()` incluye `tip_amount_cents`. |
| RF-CASHIER-004 | El `cashier` puede aplicar un descuento (`discount_amount_cents`) al pedido bajo un umbral configurable por venue; sobre el umbral requiere autorización de `manager` u `owner`. | RLS y validación en RPC `apply_discount(order_id, amount)`: rechaza si `amount > venue.cashier_discount_limit_cents` y el rol es `cashier`. |
| RF-CASHIER-005 | El `cashier` registra movimientos de caja no asociados a un pedido (`cash_movement`) con tipo `inflow`, `outflow` o `adjustment`, monto y motivo. | Cada movimiento queda en `cash_movement` con auditoría (`created_by`, `created_at`). |
| RF-CASHIER-006 | El `cashier` cierra la `cash_session` declarando el monto físico contado. El sistema calcula el esperado y la diferencia. | RPC `close_cash_session(session_id, declared)` computa `expected_amount_cents = opened + SUM(order_payment cash) + SUM(cash_movement)` y `difference_cents = declared - expected`. El estado pasa a `closed`. |
| RF-CASHIER-007 | Un pedido en `to_pay` puede ser devuelto a estado anterior (`ready`) por `manager` u `owner` para corregir errores; la acción queda en `audit_log`. | RPC `revert_order_to_ready(order_id)` con check de rol mínimo; entrada en `audit_log` con motivo. |
| RF-CASHIER-008 | Anulación de un pedido `closed` solo es posible por `manager` u `owner`, queda registrada en `audit_log` y revierte los `stock_movement` asociados. | RPC `void_closed_order(order_id, reason)`: requiere `manager`+; el pedido pasa a `cancelled`; se insertan movimientos de stock inversos. |

### 3.7 Inventario y costeo (RF-INVENTORY)

| ID | Descripción | Criterio de verificación |
|---|---|---|
| RF-INVENTORY-001 | El owner (o `manager`) puede crear un `stock_item` con nombre, `unit_of_measure` (`gram` / `kilogram` / `milliliter` / `liter` / `unit`), costo unitario actual en centavos y umbral de stock bajo. | El `stock_item` queda disponible para asociar a recetas y registrar movimientos. |
| RF-INVENTORY-002 | El owner (o `manager`) puede definir una `menu_item_recipe`: lista de `stock_item × qty` que consume un `menu_item`. | La receta queda registrada y es consultada por el trigger `on_order_item_ready`. |
| RF-INVENTORY-003 | El owner (o `manager`) registra una entrada de stock (compra) con `stock_movement` tipo `entry`, cantidad, costo unitario y proveedor opcional. | El stock actual del insumo refleja la entrada; el costo unitario actual del `stock_item` se actualiza si la entrada lo indica explícitamente. |
| RF-INVENTORY-004 | El sistema registra automáticamente `stock_movement` tipo `consumption` al pasar `order_item` a `ready`. | Verificado por RF-KDS-005. |
| RF-INVENTORY-005 | El owner (o `manager`) puede registrar mermas (`stock_movement` tipo `waste`) y ajustes manuales (`adjustment`) con motivo obligatorio. | Cada movimiento queda en `stock_movement` con auditoría completa. |
| RF-INVENTORY-006 | El sistema expone el stock actual de un insumo como `stock_current(stock_item_id) = SUM(entry) - SUM(consumption) + SUM(adjustment) - SUM(waste)`. | Función Postgres o vista materializada; el resultado coincide con el cálculo manual sobre `stock_movement`. |
| RF-INVENTORY-007 | El sistema marca un `stock_item` como "bajo umbral" cuando `stock_current < low_threshold_qty`. | Vista o flag en `stock_item` consultable por el dashboard y por alertas. |
| RF-INVENTORY-008 | El sistema calcula el costo de producción de un `menu_item` como `SUM(recipe.qty × stock_item.current_cost_cents)`. | Función `menu_item_cost(menu_item_id)` retorna el costo; el dashboard lo compara con el precio de venta para mostrar margen. |
| RF-INVENTORY-009 | Todos los movimientos de stock son append-only. Modificar un movimiento histórico no está permitido. | No existe RPC ni policy que permita UPDATE sobre `stock_movement`; las correcciones se hacen vía `adjustment` con motivo. |

### 3.8 Multi-tenant / Onboarding (RF-TENANT)

| ID | Descripción | Criterio de verificación |
|---|---|---|
| RF-TENANT-001 | El owner crea un venue al registrarse por primera vez con magic link. | Se crea un registro en `venue` vinculado al `auth.uid()` del owner. |
| RF-TENANT-002 | Toda lectura y escritura de datos de un venue solo es posible para usuarios autenticados con `venue_id` coincidente. | Un usuario de venue B no puede leer pedidos, ítems, mesas, sesiones de caja ni movimientos de stock de venue A (test pgTAP). |
| RF-TENANT-003 | El sistema aplica RLS deny-by-default: ninguna tabla con `venue_id` permite acceso sin policy explícita. | `pg_policies` refleja al menos una policy por tabla con `venue_id`. |
| RF-TENANT-004 | El owner (o `manager`) puede agregar mesas al venue con etiqueta y capacidad. | Las mesas aparecen disponibles para el garzón en la toma de pedido. |
| RF-TENANT-005 | El owner configura por venue: umbral de descuento del `cashier` y monto del PIN inicial al crear staff. | Las configuraciones quedan en columnas de `venue`. |

### 3.9 Analítica básica (RF-ANALY)

> Esta sección especifica el dashboard mínimo que se construye sobre la data de Capa 1. Forecasting y recomendaciones IA quedan fuera del alcance vigente del SRS.

| ID | Descripción | Criterio de verificación |
|---|---|---|
| RF-ANALY-001 | El dashboard del owner muestra ventas totales del día actual, últimos 7 días y últimos 30 días. | Los valores coinciden con la suma de `customer_order.total_cents` cerrados en el periodo. |
| RF-ANALY-002 | El dashboard muestra los 5 ítems más vendidos (por cantidad) en el periodo seleccionado. | Ranking correcto verificable con seed determinista. |
| RF-ANALY-003 | El dashboard muestra el ticket promedio por pedido en el periodo seleccionado. | Valor = suma totales / número de pedidos cerrados. |
| RF-ANALY-004 | El dashboard muestra la hora pico (hora del día con más pedidos) en el periodo. | La hora pico coincide con la distribución horaria en el seed. |
| RF-ANALY-005 | El owner puede filtrar la vista por tres periodos (hoy / 7d / 30d) sin recargar la página. | El filtro cambia los datos sin navegación. |
| RF-ANALY-006 | El owner puede exportar los datos del periodo como CSV con separador `;` y encoding UTF-8-BOM (compatible Excel chileno). | El archivo se descarga y abre correctamente en Excel con caracteres especiales. |
| RF-ANALY-007 | El dashboard responde en ≤1.5 s para hasta 30 días de datos en Supabase. | Medido con herramientas de red del browser con dataset seed estándar. |
| RF-ANALY-008 | El dashboard muestra alertas de `stock_item` bajo umbral (RF-INVENTORY-007) y margen estimado por ítem (RF-INVENTORY-008). | Lista de insumos en alerta y tabla de margen por plato visible en el dashboard. |

---

## 4. Requisitos no funcionales (ISO 25010)

### 4.1 Performance Efficiency (RNF-PERF)

| ID | Descripción | Métrica |
|---|---|---|
| RNF-PERF-001 | La toma de pedido responde (persist local) en modo offline. | p95 ≤200 ms medido con `flutter_test` en dispositivo de referencia. |
| RNF-PERF-002 | La sincronización al reconectarse no bloquea la UI. | Sync corre en isolate/background; UI responde durante la operación. |
| RNF-PERF-003 | El dashboard de analítica carga en ≤1.5 s con 30 días de datos. | Medido desde request hasta render completo con dataset seed estándar. |
| RNF-PERF-004 | El KDS refleja cambios en ≤2 s desde la acción del garzón. | Medido con dos sesiones simultáneas en staging. |
| RNF-PERF-005 | El descuento de stock por trigger se ejecuta en ≤200 ms post-`ready` para una receta de hasta 10 insumos. | Medido con pgbench sobre el trigger en seed estándar. |
| RNF-PERF-006 | El cobro de un pedido (RPC `register_payment`) responde en ≤500 ms p95. | Medido con dataset seed estándar; la cajera no debe percibir lag. |

### 4.2 Compatibility (RNF-COMPAT)

| ID | Descripción | Métrica |
|---|---|---|
| RNF-COMPAT-001 | La app web funciona en Chromium 120+, Firefox 120+ y Safari 17+. | Smoke test manual en los tres navegadores antes de cada release. |
| RNF-COMPAT-002 | La app nativa compila y corre en Android 10+ (API 29) e iOS 15+. | Build CI verde para ambas plataformas. |
| RNF-COMPAT-003 | Un solo codebase Flutter produce builds para web, Android, iOS y desktop sin modificaciones de plataforma en la lógica de dominio. | `flutter build <target>` sin errores de compilación para los cuatro targets. |

### 4.3 Usability (RNF-USAB)

| ID | Descripción | Métrica |
|---|---|---|
| RNF-USAB-001 | Todos los elementos interactivos tienen tap target ≥44×44 px. | Auditoría con Flutter DevTools (widget inspector) antes de cada release. |
| RNF-USAB-002 | Un `waiter` nuevo puede completar su primer pedido en ≤5 min sin manual de usuario. | Validado con prueba de usuario antes de release. |
| RNF-USAB-003 | Un `cashier` nuevo puede abrir caja, cobrar un pedido y cerrar caja en ≤10 min sin manual. | Validado con prueba de usuario antes de release. |
| RNF-USAB-004 | Todos los estados relevantes (loading, error, vacío) tienen representación visual explícita. | Revisión en code review: no se acepta pantalla en blanco ni spinner infinito. |
| RNF-USAB-005 | Los contrastes de color cumplen WCAG AA (ratio ≥4.5:1 para texto normal). | Verificado con herramienta de contraste en pantallas finales. |

### 4.4 Reliability (RNF-REL)

| ID | Descripción | Métrica |
|---|---|---|
| RNF-REL-001 | La toma de pedido funciona sin conexión a internet. | Test de integración con red desconectada: pedido persiste en `pending_op`. |
| RNF-REL-002 | Ningún pedido se pierde por desconexión mientras la app permanezca abierta. | Cola FIFO local persiste entre reinicios de la app (Drift). |
| RNF-REL-003 | **La caja exige conexión online en el momento del cobro.** Si la red está caída, la cajera no puede cerrar pedidos — el registro de pago requiere consistencia fuerte. | RPC `register_payment` requiere round-trip a Supabase; sin red, la UI bloquea la acción con mensaje explícito. |
| RNF-REL-004 | El registro de movimientos de stock manuales (`entry`, `adjustment`, `waste`) exige conexión online. | Mismo patrón que RNF-REL-003: la UI bloquea con mensaje explícito si no hay red. |
| RNF-REL-005 | El descuento automático de stock por `consumption` puede sincronizar de forma diferida si el `order_item` se cerró offline. | El movimiento entra en la cola `pending_op` junto con la transición de estado; se materializa al reconectar. |
| RNF-REL-006 | El servicio web tiene uptime ≥99% durante el piloto. | Vercel SLA + uptimerobot monitoreo cada 5 min. |

### 4.5 Security (RNF-SEC)

| ID | Descripción | Métrica |
|---|---|---|
| RNF-SEC-001 | Toda tabla con `venue_id` tiene RLS habilitada y al menos una policy USING. | Test pgTAP valida `pg_policies` en nightly. |
| RNF-SEC-002 | Un usuario de venue B no puede leer ni escribir datos de venue A. | Test SQL cross-venue en pgTAP: 0 filas retornadas con token de venue B. |
| RNF-SEC-003 | El PIN de staff no se persiste ni registra en texto plano; se valida vía `verify_pin()` SECURITY DEFINER. | Code review: ningún query directo sobre `pin_hash` en el cliente ni logging del PIN. |
| RNF-SEC-004 | No hay secretos (tokens, claves) hardcodeados en el código fuente. | `git grep` en CI sobre patrones comunes de credenciales. Sentry alerta si detecta key leak. |
| RNF-SEC-005 | Las migraciones SQL son forward-only. | Política documentada en [database/migrations.md](../database/migrations.md); rollback manual si se necesita. |
| RNF-SEC-006 | Las acciones sensibles de caja (descuento sobre umbral, anulación de pedido cerrado, ajuste de stock) quedan en `audit_log` con `user_id`, `role`, `action`, `target_id`, `reason` y `created_at`. | Revisión en code review + test pgTAP de inserciones esperadas tras cada RPC sensible. |
| RNF-SEC-007 | El rol `cashier` no puede aplicar descuentos sobre el umbral configurado por venue. | Verificación en RPC + test pgTAP: `cashier` con `discount > venue.cashier_discount_limit_cents` retorna error. |
| RNF-SEC-008 | El rol `waiter` no puede ejecutar RPCs de caja (`open_cash_session`, `register_payment`, `close_cash_session`, `apply_discount`). | Test pgTAP: token con rol `waiter` retorna `permission denied` en cada RPC de caja. |

### 4.6 Maintainability (RNF-MAIN)

| ID | Descripción | Métrica |
|---|---|---|
| RNF-MAIN-001 | Cobertura de tests ≥70% en `domain/` y ≥60% global. | Reporte lcov en cada PR; falla CI si no se cumple. |
| RNF-MAIN-002 | Cero warnings de `very_good_analysis`. | `flutter analyze --fatal-warnings` en CI. |
| RNF-MAIN-003 | Toda decisión arquitectónica nueva tiene un ADR en [`architecture/decisions/`](../architecture/decisions/) en estado `accepted` antes de mergearse. | Checklist de code review: ADR requerido si aplica. |
| RNF-MAIN-004 | No hay lógica de negocio en widgets (capa de presentación). | Code review: se rechaza PR que incluya UseCase o query de repositorio directo en un widget. |
| RNF-MAIN-005 | Toda RPC SECURITY DEFINER nueva tiene su contrato documentado en [api/contracts.md](../api/contracts.md) y al menos un test pgTAP. | Code review + pgTAP en CI. |

### 4.7 Portability (RNF-PORT)

| ID | Descripción | Métrica |
|---|---|---|
| RNF-PORT-001 | La lógica de dominio no tiene dependencias de plataforma (no importa `dart:html` ni `dart:io` directamente). | Capa `domain/` tiene 0 imports de plataforma. |
| RNF-PORT-002 | Cambiar de Drift a otro motor de persistencia local no requiere modificar las capas de dominio ni presentación. | Los repositorios extienden interfaz abstracta; se verifica con mock en tests. |

---

## 5. Trazabilidad y verificación

- Casos de aceptación detallados en [acceptance-criteria.md](acceptance-criteria.md) (Given-When-Then).
- Historias derivadas de los RFs en [user-stories.md](user-stories.md).
- Estrategia de pruebas (pirámide, cobertura por capa, métricas de flakiness) en [quality/testing-strategy.md](../quality/testing-strategy.md).

Un release no está "Done" si alguno de los casos de aceptación relevantes no pasa.
