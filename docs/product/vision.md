# Visión

> Qué problema resolvemos, para quién y cómo sabemos que funciona. Documento ancla del proyecto: cualquier feature debe poder justificarse contra esta visión.

## Problema

Los locales gastronómicos micro (cafeterías, picadas, sushis chicos, pizzerías de barrio) operan hoy con tres herramientas básicas y desconectadas: la **libreta del garzón**, la **caja con cuaderno** y el **conteo mental de insumos** que hace el dueño cuando va a comprar. La primera pierde pedidos cuando la cocina no los lee y no deja huella analítica. La segunda obliga a registrar manualmente las ventas al cierre del día, sin granularidad por ítem ni por hora. La tercera convierte la compra de insumos en un acto de intuición: el dueño sobreabastece o se queda corto, paga merma que no puede medir y nunca conoce el margen real por plato.

El resultado: el dueño no sabe qué se vendió ayer, cuál es su hora pico real, cuáles son sus 5 ítems estrella, ni cuánto le cuesta producir cada plato. La cocina depende de la voz del garzón. La caja depende de la memoria del cajero. El sistema en papel **no escala más allá de 5–6 mesas activas** sin perder pedidos.

Las soluciones SaaS existentes (Toteat, Ágil POS, Lightspeed) resuelven el problema técnico para locales medianos, pero su costo mensual (US$50–150) y su curva de onboarding (1–2 días de entrenamiento) son desproporcionados para el segmento micro.

## Usuarios

| Persona | Objetivo principal | Contexto de uso | Dispositivo típico |
|---|---|---|---|
| **Owner (dueño)** | Configurar el local; ver analítica; conocer margen y stock. | Trastienda o escritorio, con calma relativa. | Desktop o tablet; web. |
| **Manager (encargado)** | Operar el local en ausencia del owner; manejar caja, ajustes de stock, descuentos no triviales. | Sala y trastienda, alternando. | Tablet o desktop. |
| **Cashier (cajera)** | Cobrar cuentas, abrir/cerrar caja, dividir cuentas, aplicar propinas y descuentos. | Punto de caja con cola; manos libres limitadas. | Tablet o desktop dedicado. |
| **Waiter (garzón)** | Tomar pedidos rápido sin errores; ver estado de sus mesas; enviar la cuenta a caja. | Sala con ruido, manos ocupadas, sin tiempo para aprender. | Tablet o móvil. |
| **Kitchen (cocina)** | Ver los pedidos llegando en tiempo real; marcar como `preparing` y `ready`. | Cocina con humedad y grasa; visión desde lejos. | Tablet montada en pared; web. |

## Propuesta de valor

**Un POS gastronómico genérico, multiplataforma, offline-first, accesible al local micro.** Reemplaza la libreta del garzón, el cuaderno de caja y el conteo a ojo de insumos con una operación digital integrada que:

- toma pedidos sin internet y sincroniza al reconectarse, sin perder ninguno;
- muestra pedidos en cocina en ≤2 s desde que el garzón los confirma;
- separa la responsabilidad del garzón (toma) de la cajera (cobra), con caja con apertura y cierre de turno auditable;
- **descuenta inventario automáticamente según la receta de cada plato**, para que el dueño deje de comprar por intuición;
- entrega al dueño un dashboard listo (ventas, top items, ticket promedio, hora pico, margen por plato, alertas de stock) sin abrir Excel;
- se adapta a distintos formatos de local (restaurante con mesas, cafetería, barra) por configuración, no por desarrollo;
- se aprende en menos de 5 minutos sin manual.

## Producto en 3 capas

| Capa | Alcance | Estado |
|---|---|---|
| **1. Operacional** | Toma de pedido, gestión de mesas, KDS realtime, caja (apertura/cierre/arqueo), división de cuenta, modificadores de ítems, **inventario con recetas y descuento automático**, costeo por plato. | **Alcance vigente.** Núcleo del producto. |
| **2. Inteligencia** | Dashboard owner (ventas, top items, ticket promedio, hora pico, margen, alertas de stock bajo), forecasting de demanda, recomendaciones IA (qué promoción, cuándo reforzar, qué plato ajustar). | **Diferido.** Se construye sobre la data acumulada por la Capa 1. La BI básica entra en cuanto haya volumen útil; la recomendación IA es trabajo de un semestre dedicado. |
| **3. Distribución pública** | Mapa gastronómico regional, marketplace turístico, datos agregados anonimizados para municipios y SERNATUR. Modelo B2G: el municipio o gremio financia. | **Roadmap diferido sin urgencia.** La arquitectura (multi-tenant + RLS + `venue_id`) la soporta sin refactor del modelo de datos. Cuando llegue, el frontend público es un proyecto separado (probablemente SSR por SEO) que comparte el backend. |

La Capa 1 es lo que define al producto. La Capa 2 entra cuando hay data; la Capa 3 entra cuando hay locales adoptados y una contraparte institucional dispuesta a financiar.

## Éxito (cómo sabemos que funciona)

- Un garzón nuevo completa su primer pedido en ≤5 min sin manual de usuario (RNF-USAB-002).
- La toma de pedido funciona sin conexión y ningún pedido se pierde mientras la app permanezca abierta (RNF-REL-001, RNF-REL-002).
- El KDS refleja cambios en ≤2 s desde la acción del garzón (RNF-PERF-004).
- El dashboard de analítica carga en ≤1.5 s con 30 días de datos (RNF-PERF-003).
- La caja cierra con cuadre verificable: total cobrado por método = total esperado de pedidos cerrados en la sesión (invariante de arqueo).
- El stock de un insumo refleja, en cualquier momento, `(entradas) − (consumo por pedidos `ready`) − (mermas) + (ajustes)` (invariante de inventario).
- Aislamiento estricto entre venues: ninguno ve datos de otro (RNF-SEC-001..002, verificado por pgTAP cross-venue).

## Fuera de alcance vigente

Estas capacidades quedan deliberadamente fuera del alcance actual. Su exclusión no es por imposibilidad técnica sino por foco: cerrar primero el núcleo POS + inventario robusto.

- **Recomendaciones por IA generativa.** Capa 2. Requiere data acumulada y un proyecto dedicado (probablemente Sistemas Inteligentes en un semestre posterior).
- **Multi-canal completo** — delivery con integración a Rappi/Uber Eats, take-away formal con cola y notificación al cliente. El modelo de datos reserva `service_type` para soportarlo sin migración; la lógica de negocio no se implementa todavía.
- **Integración SII y boleta electrónica.** Los métodos de pago se registran (efectivo, débito, crédito, transferencia); la emisión tributaria automática queda diferida.
- **Pasarela de pago electrónica integrada** (Transbank, Fintoc). El cobro se registra; el procesamiento del medio de pago lo hace el local con su propia POS bancaria.
- **Capa 3 — Distribución pública / turismo regional.** La arquitectura lo habilita; el frontend público es trabajo posterior.
- **Onboarding multi-venue para una misma cuenta owner.** Un owner = un venue. La extensión a cadenas se diseña después.
- **Impresión física de comandas / boletas.** Conexión a impresoras térmicas POS. Diferida.

## Restricciones que moldean la solución

- **Sin presupuesto operativo.** Stack en tier gratuito o open-source mientras el modelo de negocio no esté validado.
- **Multi-tenant desde el día 1.** RLS deny-by-default por `venue_id`, no "después".
- **AGPL-3.0.** Cualquier despliegue público debe publicar el código fuente derivado.
- **Genérico por configuración, no por código.** Cualquier feature que sirva solo a un tipo de local (ej. mesas, barra, take-away) debe poder desactivarse por configuración del venue, no por build separado.

## Referencias

- [SRS](../requirements/srs.md) — requisitos formales (IEEE 29148 + ISO 25010).
- [User stories](../requirements/user-stories.md) — historias por épica.
- [Glossary](glossary.md) — lenguaje del dominio.
- [Roadmap](roadmap.md) — orden de implementación y prioridades.
- [Architecture overview](../architecture/overview.md) — cómo está hecho.
