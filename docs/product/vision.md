# Visión

> Qué problema resolvemos, para quién y cómo sabemos que funciona. Documento ancla del proyecto: cualquier feature debe poder justificarse contra esta visión.

## Problema

Los locales gastronómicos micro (cafeterías, picadas, sushis chicos, pizzerías de barrio) operan hoy con dos herramientas básicas: la **libreta del garzón** y el **cuaderno (o Excel) del dueño**. La primera pierde pedidos cuando la cocina no los lee, exige reescribir el ticket y no deja huella analítica. La segunda obliga a registrar manualmente las ventas al cierre del día, con errores de transcripción y sin granularidad por ítem o por hora.

El dueño termina sin saber qué se vendió ayer, cuál es su hora pico real ni cuáles son sus 5 ítems estrella. La cocina depende de la voz del garzón. El sistema tradicional de comandas en papel **no escala más allá de 5–6 mesas activas** sin perder pedidos.

Las soluciones SaaS existentes (Toteat, Ágil POS, Lightspeed) están pensadas para locales medianos y resuelven el problema, pero su costo mensual y su curva de onboarding son desproporcionados para el segmento micro: el local pequeño no puede pagar US$50–150/mes ni dedicar 2 días a entrenar al equipo.

## Usuarios

| Persona | Objetivo principal | Contexto de uso | Dispositivo típico |
|---|---|---|---|
| **Garzón** | Tomar pedido rápido sin errores; ver estado de sus mesas. | Sala con ruido, manos ocupadas, sin tiempo para aprender. | Tablet (principal) o móvil; web fallback. |
| **Dueño (owner)** | Ver qué se vendió hoy y esta semana; hacer onboarding sin pasos técnicos. | Escritorio o trastienda, con calma relativa. | Desktop o tablet; web. |
| **Cocina** | Ver los pedidos llegando en tiempo real; marcar como `ready`. | Cocina con humedad y grasa; visión desde lejos. | Tablet montada en pared; web. |

## Propuesta de valor

**Una sola app, multiplataforma, offline-first, gratis para el local micro.** Reemplaza la libreta del garzón y el cuaderno del dueño con una operación digital que:

- toma pedidos sin internet y sincroniza al reconectarse, sin perder ninguno;
- muestra pedidos en cocina en ≤2 s desde que el garzón los confirma;
- entrega al dueño un dashboard listo (ventas, top items, ticket promedio, hora pico) sin abrir Excel;
- se aprende en menos de 5 minutos sin manual.

## Producto en 3 capas

| Capa | Alcance | Estado en MVP académico |
|---|---|---|
| **1. Operación** | Toma de pedido, KDS realtime, cierre de cuenta. | MVP — Avance 2 (2026-05-26). |
| **2. Analítica** | Dashboard owner: ventas, top items, ticket promedio, hora pico. | MVP — Defensa (2026-07-07). |
| **3. Turismo regional B2G** | Datos agregados anonimizados para municipios y SERNATUR. | Roadmap v2 — la arquitectura ya lo soporta. |

La arquitectura ya soporta Capa 3 (multi-tenant + RLS) — queda fuera del MVP académico para no inflar scope, pero un proyecto futuro la habilita sin refactor.

## Éxito (cómo sabemos que funciona)

- Un garzón nuevo completa su primer pedido en ≤5 min sin manual de usuario (RNF-USAB-002).
- La toma de pedido funciona sin conexión y ningún pedido se pierde mientras la app permanezca abierta (RNF-REL-001, RNF-REL-002).
- El KDS refleja cambios en ≤2 s desde la acción del garzón (RNF-PERF-004).
- El dashboard de analítica carga en ≤1.5 s con 30 días de datos (RNF-PERF-003).
- Aislamiento estricto entre venues: ninguno ve datos de otro (RNF-SEC-001..002, verificado por pgTAP cross-venue).

## Fuera de alcance del MVP académico

- **Impresión de boletas / comandas físicas.** Capa 1.5; arquitectura no la bloquea pero no se implementa este semestre.
- **Pasarela de pago integrada.** Métodos de pago se registran (efectivo, débito, crédito), no se cobran.
- **Sistema de inventario / stock.** Cambios en ítems del menú no descuentan inventario.
- **Onboarding multi-venue para una misma cuenta owner.** Un owner = un venue en MVP.
- **Notificaciones push nativas** (Android/iOS). Se habilitan post-defensa si el proyecto continúa.
- **Audit log con UI de exploración.** El log existe en la tabla `audit_log` pero no hay screen para consultarlo.

## Restricciones que moldean la solución

- **Equipo de 2 personas con ~20 h/sprint efectivas, en 10 sprints.** Se recorta scope antes que calidad.
- **Sin presupuesto.** Stack en tier gratuito o open-source.
- **Multi-tenant desde el día 1.** RLS deny-by-default por `venue_id`, no "después".
- **AGPL-3.0.** Cualquier despliegue público debe publicar el código fuente derivado.

## Referencias

- [SRS](../requirements/srs.md) — requisitos formales (IEEE 29148 + ISO 25010).
- [User stories](../requirements/user-stories.md) — historias por épica.
- [Glossary](glossary.md) — lenguaje del dominio.
- [Roadmap](roadmap.md) — orden de sprints, prioridades, criterios de replan.
- [Architecture overview](../architecture/overview.md) — cómo está hecho.
