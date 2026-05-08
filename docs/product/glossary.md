# Glosario

> Lenguaje del dominio compartido entre el código, los docs y la conversación con el equipo. Si introduces un término nuevo del dominio, agrégalo acá en el mismo PR.

## Actores

| Término | Definición |
|---|---|
| **owner** | Dueño del local. Gestiona menú, ve analítica, hace onboarding. Se autentica con magic link al email. |
| **garzón** (staff) | Personal de sala. Toma pedidos en mesas. Se autentica con PIN + nombre, asociado a un venue. |
| **cocina** | Personal de cocina. Usa el KDS para ver pedidos llegando y marcarlos como `preparing` y `ready`. En MVP no se autentica como rol separado: la cocina opera con el mismo PIN que un staff. |

## Conceptos del producto

| Término | Definición |
|---|---|
| **venue** | Local gastronómico (tenant raíz del sistema). Una fila en `venue` = un local. |
| **KDS** | Kitchen Display System — pantalla de cocina que muestra los pedidos en tiempo real. |
| **dining_table** | Mesa del local (renombrado de `table` para evitar colisión con SQL). |
| **customer_order** | Pedido (renombrado de `order` para evitar colisión con SQL). |
| **pending_op** | Operación pendiente de sincronización con Supabase (cola FIFO local en Drift). **No existe en Supabase.** |
| **LWW** | Last Write Wins — política de resolución de conflictos por `updated_at` server-side. Ver [sync/offline-first.md](../sync/offline-first.md). |
| **RLS** | Row-Level Security — mecanismo Postgres de control de acceso por fila. Ver [database/rls.md](../database/rls.md). |
| **Drift** | ORM type-safe para Flutter con soporte SQLite (nativo) e IndexedDB (web). Persistencia local de la app. |
| **venue_id** | UUID que identifica a qué venue pertenece cada fila; eje del multi-tenant. |
| **magic link** | Enlace de autenticación sin contraseña enviado al email del owner. |
| **PIN de garzón** | Código numérico corto (4–6 dígitos) para identificar al garzón; hasheado en Postgres con `pgcrypto.crypt()`. |
| **CLP** | Peso chileno. Precios almacenados en **centavos (integer)** para evitar errores de punto flotante. |

## Estados

| Estado | Aplica a | Significado |
|---|---|---|
| `open` | `customer_order` | Pedido recién creado; el garzón puede agregar/quitar ítems. |
| `sent` | `customer_order` | Pedido enviado a cocina; visible en KDS. |
| `preparing` | `customer_order`, `order_item` | Cocina lo está preparando. |
| `ready` | `customer_order`, `order_item` | Listo para servir. |
| `closed` | `customer_order` | Pedido cerrado con método de pago. **Estado terminal** — no se puede modificar (ACID-4). |
| `cancelled` | `customer_order`, `order_item` | Pedido o ítem cancelado. No suma al total. |
| `valid` / `invalid` / `blocked` | `verify_pin` (RPC) | Resultado de la validación de PIN. `blocked` se devuelve tras 5 intentos fallidos consecutivos. |

## Capas del producto

| Término | Significado |
|---|---|
| **Capa 1 — Operación** | Toma de pedido + KDS + cierre. MVP. |
| **Capa 2 — Analítica** | Dashboard owner: ventas, top items, ticket promedio, hora pico. MVP. |
| **Capa 3 — Turismo regional B2G** | Datos agregados anonimizados para municipios y SERNATUR. Roadmap v2. |

## Convenciones de nombres en código

- Identifiers en **inglés**: `OrderRepository`, `customerOrder`, `tableId`.
- Renombres canónicos para evitar colisión con palabras reservadas SQL:
  - `dining_table` (no `table`)
  - `customer_order` (no `order`)
- Sufijos consistentes:
  - `*_cents` para todo monto monetario (siempre `int`).
  - `*_at` para timestamps (`created_at`, `updated_at`, `closed_at`).
  - `*_id` para foreign keys (`venue_id`, `dining_table_id`, `menu_item_id`).
- En español solo: commits, issues, PRs, docs, ADRs y comentarios opcionales en código.

## Términos académicos

| Término | Significado |
|---|---|
| **Avance 1** | Entrega académica 2026-04-28 — scaffolding ejecutable. |
| **Avance 2** | Entrega académica 2026-05-26 — Capa 1 demoable. |
| **Defensa** | Entrega final 2026-07-07 — Capa 1 + Capa 2 MVP. |
| **DoR** | Definition of Ready — checklist para que una historia entre al sprint. Ver [contributing.md](../contributing.md). |
| **DoD** | Definition of Done — checklist para que una historia se cierre. Ver [quality/definition-of-done.md](../quality/definition-of-done.md). |
| **ADR** | Architecture Decision Record. Una decisión por archivo en formato MADR. Ver [architecture/decisions/](../architecture/decisions/). |

## Cómo agregar un término nuevo

1. Si aparece en código (clase, variable, función) en inglés y aún no está acá, **agrégalo en el mismo PR**.
2. Si reemplaza un término anterior, agrega ambos con nota cruzada (`X (antes Y)`).
3. Mantener orden alfabético dentro de cada sección no es obligatorio; mantener **agrupación temática** sí lo es.
