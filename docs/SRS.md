# SRS — COMAND-IA

> Documento de requisitos del sistema. Sigue la estructura IEEE 29148.  
> Calidad mapeada a **ISO/IEC 25010:2011**.

---

## 1. Introducción

### 1.1 Propósito

Este documento especifica los requisitos funcionales y no funcionales de **COMAND-IA**, una aplicación multiplataforma de comandas y analítica para locales gastronómicos micro. Sirve como contrato entre el equipo de desarrollo y los evaluadores académicos del ramo Electivo Profesional (ICCI, UCEN 2026-S1).

### 1.2 Alcance MVP

El MVP cubre **Capa 1 (Operación)** y **Capa 2 (Analítica)**:

| Capa | Alcance |
|---|---|
| **1 — Operación** | Toma de pedido offline-first, KDS realtime, cierre de cuenta |
| **2 — Analítica** | Dashboard owner: KPIs de ventas, top items, ticket promedio, hora pico |
| **3 — Turismo regional B2G** | Fuera del MVP. Roadmap v2. La arquitectura ya lo soporta. |

La arquitectura soporta multi-tenant (múltiples locales en la misma base de datos) desde el Sprint 1 por diseño, pero el onboarding de múltiples venues es Capa 3.

### 1.3 Definiciones y glosario

| Término | Definición |
|---|---|
| **venue** | Local gastronómico (tenant raíz del sistema) |
| **owner** | Dueño del local; gestiona menú, ve analítica, hace onboarding |
| **garzón** | Personal de sala; toma pedidos en mesas |
| **KDS** | Kitchen Display System — pantalla de cocina que muestra los pedidos en tiempo real |
| **dining_table** | Mesa del local (renombrado de `table` para evitar colisión con SQL) |
| **customer_order** | Pedido (renombrado de `order` para evitar colisión con SQL) |
| **pending_op** | Operación pendiente de sincronización con Supabase (cola FIFO local) |
| **LWW** | Last Write Wins — política de resolución de conflictos por `updated_at` server-side |
| **RLS** | Row-Level Security — mecanismo Postgres de control de acceso por fila |
| **Drift** | ORM type-safe para Flutter con soporte SQLite (nativo) e IndexedDB (web) |
| **venue_id** | UUID que identifica a qué venue pertenece cada fila; eje del multi-tenant |
| **magic link** | Enlace de autenticación sin contraseña enviado al email del owner |
| **PIN de garzón** | Código numérico corto para identificar al garzón; hasheado en Postgres |
| **CLP** | Peso chileno. Precios almacenados en centavos (integer) para evitar errores de punto flotante |

### 1.4 Referencias

- [ARCHITECTURE.md](ARCHITECTURE.md) — C4, modelo de datos, RLS, sync offline-first, contratos API
- [decisiones.md](decisiones.md) — ADRs con el por qué de cada decisión técnica
- [CONTRIBUTING.md](../CONTRIBUTING.md) — convenciones de equipo, DoR, DoD, code review

---

## 2. Descripción general

### 2.1 Perspectiva del producto

COMAND-IA reemplaza la libreta del garzón y el cuaderno del dueño con una sola aplicación que opera offline-first (toma pedidos sin internet) y sincroniza en tiempo real cuando hay conexión. La cocina ve el pedido en pantalla apenas se confirma; el dueño ve qué se vendió sin abrir Excel.

El sistema es multiplataforma: un único codebase Flutter corre en Android, iOS, web y desktop. Para el MVP académico el canal principal es web (Chrome/Firefox/Safari) sobre tablet o desktop, con soporte nativo para mobile desde el mismo build. Ver [ARCHITECTURE.md](ARCHITECTURE.md) para el C4 completo.

### 2.2 Funciones principales

**Capa 1 — Operación (MVP)**

- Autenticación: magic link para owner, PIN + nombre para garzones
- Gestión de menú: categorías e ítems con precio en CLP
- Toma de pedido por mesa con soporte offline (cola FIFO local)
- KDS realtime: pantalla cocina con cambios de estado en ≤2s
- Cierre de cuenta: total inmutable, método de pago, estado terminal
- Multi-tenant: RLS deny-by-default que aísla datos por venue

**Capa 2 — Analítica (MVP)**

- Dashboard owner: ventas/día, top 5 ítems, ticket promedio, hora pico
- Filtros temporales: hoy / 7 días / 30 días
- Exportación CSV con separador `;` y encoding chileno

### 2.3 Personas

| Persona | Objetivo principal | Contexto de uso | Dispositivo típico |
|---|---|---|---|
| **Garzón** | Tomar pedido rápido sin errores, ver estado de sus mesas | Sala con ruido, manos ocupadas, sin tiempo para aprender | Tablet (principal) o móvil; web fallback |
| **Dueño (owner)** | Ver qué se vendió hoy y esta semana | Escritorio o trastienda, con calma relativa | Desktop o tablet; web |
| **Cocina** | Ver los pedidos llegando en tiempo real, marcar como listo | Cocina con humedad y grasa; visión desde lejos | Tablet montada en pared; web |

### 2.4 Restricciones

| Restricción | Detalle |
|---|---|
| **Flutter multiplataforma** | Un solo codebase para Android, iOS, web y desktop. Sin bifurcación de código por plataforma salvo adaptaciones de layout. |
| **Supabase free tier** | Hasta 500 MB DB, 200 conexiones realtime simultáneas, 2M mensajes/mes. Suficiente para academia. |
| **Capacidad equipo** | ~20h/sprint efectivas (2 personas × ~10h). Scope se recorta antes que calidad. |
| **AGPL-3.0** | Todo despliegue público debe publicar el código fuente derivado. |
| **Sin presupuesto** | Stack elegido en tier gratuito o open-source. Sin licencias pagas. |
| **Idioma** | Código e identifiers en inglés. Docs, commits, issues y ADRs en español. |
| **Impresión de boletas** | Fuera del MVP (Capa 1.5). La arquitectura no la bloquea, pero no se implementa en este semestre. |

### 2.5 Suposiciones y dependencias

- Supabase permanece en tier free durante el semestre sin degradar realtime.
- Drift es viable en Flutter web (IndexedDB). Si el spike Sprint 1 lo descarta, se migra a Hive (ver ADR-0004 en [decisiones.md](decisiones.md)).
- Los locales gastronómicos target tienen conexión a internet al menos intermitente (el sistema tolera desconexión, no la asume permanente).

---

## 3. Requisitos funcionales

Formato: `id | descripción imperativa | criterio de verificación`.

### 3.1 Auth (RF-AUTH)

| ID | Descripción | Criterio de verificación |
|---|---|---|
| RF-AUTH-001 | El sistema envía un magic link al email del owner cuando este solicita acceso. | El usuario recibe el correo en ≤60s y el link expira en 24h. |
| RF-AUTH-002 | El sistema autentica a un garzón con su nombre y PIN de 4-6 dígitos asociado al venue. | PIN correcto retorna sesión de garzón; PIN incorrecto no. |
| RF-AUTH-003 | El sistema bloquea la autenticación por PIN tras 5 intentos fallidos consecutivos para el mismo usuario. | El 6° intento retorna error bloqueado aunque el PIN sea correcto. |
| RF-AUTH-004 | El sistema almacena el PIN hasheado con argon2/pgcrypto; nunca en texto plano. | La columna `pin_hash` no contiene el PIN original; solo `verify_pin()` SECURITY DEFINER lo valida. |
| RF-AUTH-005 | El owner puede invitar a un garzón creando un perfil con nombre y PIN en el panel de administración. | El garzón nuevo puede autenticarse con ese PIN en el mismo venue. |
| RF-AUTH-006 | El sistema cierra sesión y limpia el estado local al hacer logout explícito. | Después del logout, navegar a ruta protegida redirige al login. |

### 3.2 Menú (RF-MENU)

| ID | Descripción | Criterio de verificación |
|---|---|---|
| RF-MENU-001 | El owner puede crear una categoría de menú con nombre y orden de visualización. | La categoría aparece en la lista del garzón en el orden definido. |
| RF-MENU-002 | El owner puede crear un ítem de menú con nombre, precio en CLP y categoría. | El ítem aparece en la pantalla de toma de pedido. |
| RF-MENU-003 | El owner puede editar nombre y precio de un ítem existente. | Los cambios se reflejan en nuevos pedidos; pedidos existentes conservan el snapshot inmutable. |
| RF-MENU-004 | El owner puede desactivar un ítem sin eliminarlo; los ítems inactivos no aparecen en la toma de pedido. | Un ítem inactivo no es seleccionable por el garzón. |
| RF-MENU-005 | El sistema almacena precios en centavos (integer). El frontend muestra el valor en CLP con formato local. | No hay errores de punto flotante en totales. |
| RF-MENU-006 | El owner puede importar ítems desde un archivo CSV con separador `;`. | Los ítems del CSV aparecen en el menú tras la importación exitosa. |

### 3.3 Pedidos (RF-ORDER)

| ID | Descripción | Criterio de verificación |
|---|---|---|
| RF-ORDER-001 | El garzón selecciona una mesa y puede agregar ítems del menú con cantidad y comentario opcional. | El pedido refleja los ítems y cantidades seleccionados. |
| RF-ORDER-002 | El sistema persiste el pedido localmente antes de enviarlo a Supabase. | Con red desconectada, el pedido se guarda y la UI confirma OK. |
| RF-ORDER-003 | El sistema sincroniza los pedidos pendientes con Supabase cuando la conexión se restablece (FIFO). | Tras reconexión, `pending_op` se vacía en orden de creación. |
| RF-ORDER-004 | El sistema aplica backoff exponencial ante fallos de sync; tras 10 intentos notifica al owner. | El log de sync muestra los reintentos y la notificación se emite al superar 10. |
| RF-ORDER-005 | El total del pedido lo calcula un trigger Postgres (`compute_order_total`); el frontend nunca lo escribe directamente. | Modificar un `order_item` actualiza automáticamente `customer_order.total_cents`. |
| RF-ORDER-006 | El garzón puede agregar ítems a un pedido abierto mientras no esté cerrado. | Ítems adicionales se suman al total y se envían a la cocina. |
| RF-ORDER-007 | El garzón puede cerrar un pedido registrando el método de pago; el estado `closed` es terminal. | Tras cierre, no se pueden agregar ni modificar ítems. |
| RF-ORDER-008 | El sistema muestra el estado de cada mesa en la vista principal (libre / con pedido abierto / pedido listo). | La vista de mesas refleja el estado en tiempo real. |

### 3.4 KDS / Cocina (RF-KDS)

| ID | Descripción | Criterio de verificación |
|---|---|---|
| RF-KDS-001 | La pantalla de cocina muestra en tiempo real todos los pedidos en estado `sent` o `preparing` del venue. | Nuevo ítem enviado por garzón aparece en KDS en ≤2s. |
| RF-KDS-002 | El cocinero puede cambiar el estado de un pedido a `preparing` y luego a `ready`. | El cambio de estado se propaga al garzón vía realtime en ≤2s. |
| RF-KDS-003 | La pantalla KDS muestra nombre de la mesa, ítems, cantidad y comentarios para cada pedido. | La información coincide con lo registrado por el garzón. |
| RF-KDS-004 | Los pedidos `ready` se distinguen visualmente de los `preparing` y `sent`. | Diferencia de color o iconografía clara entre estados. |

### 3.5 Analítica (RF-ANALY)

| ID | Descripción | Criterio de verificación |
|---|---|---|
| RF-ANALY-001 | El dashboard del owner muestra ventas totales del día actual, últimos 7 días y últimos 30 días. | Los valores coinciden con la suma de `customer_order.total_cents` cerrados en el periodo. |
| RF-ANALY-002 | El dashboard muestra los 5 ítems más vendidos (por cantidad) en el periodo seleccionado. | Ranking correcto verificable con seed determinista. |
| RF-ANALY-003 | El dashboard muestra el ticket promedio por pedido en el periodo seleccionado. | Valor = suma totales / número de pedidos cerrados. |
| RF-ANALY-004 | El dashboard muestra la hora pico (hora del día con más pedidos) en el periodo. | La hora pico coincide con la distribución horaria en el seed. |
| RF-ANALY-005 | El owner puede filtrar la vista por tres periodos (hoy / 7d / 30d) sin recargar la página. | El filtro cambia los datos sin navegación. |
| RF-ANALY-006 | El owner puede exportar los datos del periodo como CSV con separador `;` y encoding UTF-8-BOM (compatible Excel chileno). | El archivo se descarga y abre correctamente en Excel con caracteres especiales. |
| RF-ANALY-007 | El dashboard responde en ≤1.5s para hasta 30 días de datos en Supabase. | Medido con herramientas de red del browser con dataset seed estándar. |

### 3.6 Multi-tenant / Onboarding (RF-TENANT)

| ID | Descripción | Criterio de verificación |
|---|---|---|
| RF-TENANT-001 | El owner crea un venue al registrarse por primera vez con magic link. | Se crea un registro en `venue` vinculado al `auth.uid()` del owner. |
| RF-TENANT-002 | Toda lectura y escritura de datos de un venue solo es posible para usuarios autenticados con `venue_id` coincidente. | Un usuario de venue B no puede leer pedidos, ítems ni mesas de venue A (test pgTAP). |
| RF-TENANT-003 | El sistema aplica RLS deny-by-default: ninguna tabla permite acceso sin policy explícita. | `pg_policies` refleja al menos una policy por tabla con `venue_id`. |
| RF-TENANT-004 | El owner puede agregar mesas al venue con etiqueta y capacidad. | Las mesas aparecen disponibles para el garzón en la toma de pedido. |

---

## 4. Requisitos no funcionales (ISO 25010)

### 4.1 Performance Efficiency (RNF-PERF)

| ID | Descripción | Métrica |
|---|---|---|
| RNF-PERF-001 | La toma de pedido responde (persist local) en modo offline. | p95 ≤200ms medido con `flutter_test` en dispositivo de referencia. |
| RNF-PERF-002 | La sincronización al reconectarse no bloquea la UI. | Sync corre en isolate/background; UI responde durante la operación. |
| RNF-PERF-003 | El dashboard de analítica carga en ≤1.5s con 30 días de datos. | Medido desde red request hasta renderizado completo con dataset seed estándar. |
| RNF-PERF-004 | El KDS refleja cambios en ≤2s desde la acción del garzón. | Medido con dos sesiones simultáneas en staging. |

### 4.2 Compatibility (RNF-COMPAT)

| ID | Descripción | Métrica |
|---|---|---|
| RNF-COMPAT-001 | La app web funciona en Chromium 120+, Firefox 120+ y Safari 17+. | Smoke test manual en los tres navegadores antes de Avance 2. |
| RNF-COMPAT-002 | La app nativa compila y corre en Android 10+ (API 29) e iOS 15+. | Build CI verde para ambas plataformas. |
| RNF-COMPAT-003 | Un solo codebase Flutter produce builds para web, Android, iOS y desktop sin modificaciones de plataforma en la lógica de dominio. | `flutter build <target>` sin errores de compilación para los cuatro targets. |

### 4.3 Usability (RNF-USAB)

| ID | Descripción | Métrica |
|---|---|---|
| RNF-USAB-001 | Todos los elementos interactivos tienen tap target ≥44×44 px. | Auditoria con Flutter DevTools (widget inspector) antes de Avance 2. |
| RNF-USAB-002 | Un garzón nuevo puede completar su primer pedido en ≤5 min sin manual de usuario. | Validado con prueba de usuario antes de Avance 2. |
| RNF-USAB-003 | Todos los estados relevantes (loading, error, vacío) tienen representación visual explícita. | Revisión en code review: no se acepta pantalla en blanco ni spinner infinito. |
| RNF-USAB-004 | Los contrastes de color cumplen WCAG AA (ratio ≥4.5:1 para texto normal). | Verificado con herramienta de contraste en pantallas finales. |

### 4.4 Reliability (RNF-REL)

| ID | Descripción | Métrica |
|---|---|---|
| RNF-REL-001 | La toma de pedido funciona sin conexión a internet. | Test de integración con red desconectada: pedido persiste en `pending_op`. |
| RNF-REL-002 | Ningún pedido se pierde por desconexión mientras la app permanezca abierta. | Cola FIFO local persiste entre reinicios de la app (Drift). |
| RNF-REL-003 | El servicio web tiene uptime ≥99% durante el semestre académico. | Vercel SLA + uptimerobot monitoreo cada 5 min. |

### 4.5 Security (RNF-SEC)

| ID | Descripción | Métrica |
|---|---|---|
| RNF-SEC-001 | Toda tabla con `venue_id` tiene RLS habilitada y al menos una policy USING. | Test pgTAP valida `pg_policies` en nightly. |
| RNF-SEC-002 | Un usuario de venue B no puede leer ni escribir datos de venue A. | Test SQL cross-venue en pgTAP: 0 filas retornadas con token de venue B. |
| RNF-SEC-003 | El PIN de garzón nunca viaja en texto plano; solo se valida via `verify_pin()` SECURITY DEFINER. | Code review: ningún query directo sobre `pin_hash` en el cliente. |
| RNF-SEC-004 | No hay secretos (tokens, claves) hardcodeados en el código fuente. | `git grep` en CI sobre patrones comunes de credenciales. Sentry alerta si detecta key leak. |
| RNF-SEC-005 | Las migraciones SQL son forward-only en MVP. | Política documentada en [ARCHITECTURE.md](ARCHITECTURE.md); rollback manual si se necesita. |

### 4.6 Maintainability (RNF-MAIN)

| ID | Descripción | Métrica |
|---|---|---|
| RNF-MAIN-001 | Cobertura de tests ≥70% en `domain/` y ≥60% global. | Reporte lcov en cada PR; falla CI si no se cumple. |
| RNF-MAIN-002 | Cero warnings de `very_good_analysis`. | `flutter analyze --fatal-warnings` en CI. |
| RNF-MAIN-003 | Toda decisión arquitectónica nueva tiene un ADR en [decisiones.md](decisiones.md) en estado `Accepted` antes de mergearse. | Checklist de code review: ADR requerido si aplica. |
| RNF-MAIN-004 | No hay lógica de negocio en widgets (capa de presentación). | Code review: se rechaza PR que incluya UseCase o query de repositorio directo en un widget. |

### 4.7 Portability (RNF-PORT)

| ID | Descripción | Métrica |
|---|---|---|
| RNF-PORT-001 | La lógica de dominio no tiene dependencias de plataforma (no importa `dart:html` ni `dart:io` directamente). | Capa `domain/` tiene 0 imports de plataforma. |
| RNF-PORT-002 | Cambiar de Drift a otro motor de persistencia local no requiere modificar las capas de dominio ni presentación. | Los repositorios extienden interfaz abstracta; se verifica con mock en tests. |

---

## 5. Casos de aceptación

### Capa 1 — Operación

| ID | Nombre | Escenario | Resultado esperado |
|---|---|---|---|
| CA-001 | PIN bloqueado | Garzón ingresa PIN incorrecto 5 veces. En el 6° intento ingresa el PIN correcto. | El sistema rechaza el acceso y retorna estado `bloqueado`. |
| CA-002 | Aislamiento de mesas por venue | Garzón autenticado en venue A navega a la vista de mesas. | Solo ve las mesas de venue A; nunca las de venue B. |
| CA-003 | Pedido offline persiste | Red desconectada. Garzón completa un pedido y lo confirma. | UI muestra OK. `pending_op` contiene la operación. No hay pérdida de datos. |
| CA-004 | Sync al reconectarse | Después de CA-003, la red se restablece. | `pending_op` se vacía en orden FIFO. El pedido llega a Supabase. El KDS lo muestra en ≤2s. |
| CA-005 | Realtime KDS → garzón | Cocinero marca pedido como `ready` en el KDS. | El garzón ve el cambio de estado en su vista de mesas en ≤2s sin recargar. |
| CA-006 | Estado `closed` es terminal | Pedido está cerrado. Garzón intenta agregar un ítem. | El sistema rechaza la operación con error de estado terminal. |
| CA-007 | Aislamiento de pedidos por venue (SQL) | Token de venue B intenta SELECT sobre `customer_order` sin filtro explícito. | Retorna 0 filas (RLS bloquea). Test pgTAP. |

### Capa 2 — Analítica

| ID | Nombre | Escenario | Resultado esperado |
|---|---|---|---|
| CA-101 | Dashboard carga rápido | Owner abre dashboard con filtro 30d y dataset seed estándar. | Datos visibles en ≤1.5s. |
| CA-102 | Filtro sin refresh | Owner cambia filtro de 7d a hoy. | Datos actualizados sin recarga de página. |
| CA-103 | Top 5 determinista | Dataset seed con distribución conocida. | El ranking de top 5 ítems coincide con el esperado. |
| CA-104 | Aislamiento dashboard | Owner de venue A abre su dashboard. | Solo ve datos de venues que posee; nunca de venue B. |
| CA-105 | Export CSV | Owner exporta CSV con filtro 30d. | Archivo descargado con separador `;`, encoding UTF-8-BOM, sin datos de otros venues. |

---

## 6. Verificación

La estrategia de pruebas completa (pirámide de tests, cobertura por capa, métricas de flakiness) está documentada en [ARCHITECTURE.md § 10 Estrategia de pruebas](ARCHITECTURE.md).

Los casos de aceptación de esta sección son los criterios verificables mínimos. Un sprint no está "Done" si alguno de los CA relevantes no pasa.
