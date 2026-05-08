# C4 Nivel 3 — Componentes por feature

> Componentes dentro de cada feature de la app Flutter. Solo se documentan los módulos no triviales.

Cada feature en `lib/features/<feature>/` sigue la misma estructura vertical (Clean Architecture adaptada):

```
features/<feature>/
├── domain/
│   ├── entities/           ← modelos de dominio (sin dependencia de Flutter/Supabase)
│   ├── repositories/       ← interfaces abstractas (contratos)
│   └── usecases/           ← operaciones de negocio (una por archivo)
├── data/
│   ├── datasources/
│   │   ├── remote/         ← implementación Supabase
│   │   └── local/          ← implementación Drift
│   ├── models/             ← DTOs con serialización
│   └── repositories/       ← implementación concreta de la interfaz de dominio
└── presentation/
    ├── controllers/        ← Riverpod providers/notifiers
    ├── screens/            ← pantallas (solo layout y llamadas a controllers)
    └── widgets/            ← widgets reutilizables del feature
```

## Feature: `auth`

| Componente | Responsabilidad |
|---|---|
| `AuthRepository` (interfaz) | Contrato de autenticación: magic link y PIN. |
| `SupabaseAuthDataSource` | Magic link email vía Supabase Auth. |
| `PinAuthDataSource` | Llama a RPC `verify_pin(venue_id, pin, display_name)` SECURITY DEFINER. |
| `AuthController` (Riverpod) | Estado de sesión; expone `User?` al árbol de widgets. |
| `LoginScreen` | Pantalla con dos flows: magic link (owner) y PIN (garzón). |

## Feature: `menu`

| Componente | Responsabilidad |
|---|---|
| `MenuRepository` (interfaz) | CRUD de categorías e ítems. |
| `SupabaseMenuDataSource` | Operaciones sobre `menu_category` y `menu_item`. |
| `LocalMenuDataSource` | Cache Drift de menú para uso offline. |
| `MenuController` | Lista reactiva de ítems; expone stream filtrado por `venue_id`. |
| `MenuAdminScreen` | Gestión de categorías e ítems (solo owner). |

## Feature: `orders`

| Componente | Responsabilidad |
|---|---|
| `OrderRepository` (interfaz) | Crear, modificar, cerrar pedidos. |
| `SupabaseOrderDataSource` | Operaciones sobre `customer_order` y `order_item`. |
| `LocalOrderDataSource` | Persiste pedidos en Drift durante offline. |
| `SyncService` | Vacía `pending_op` hacia Supabase con backoff exponencial. Ver [sync/offline-first.md](../sync/offline-first.md). |
| `OrderController` | Estado del pedido activo por mesa. |
| `TableGridScreen` | Vista de mesas con estado en tiempo real. |
| `OrderFormScreen` | Toma de pedido: mesa → ítems → confirmar. |

## Feature: `kitchen` (KDS)

| Componente | Responsabilidad |
|---|---|
| `KitchenRepository` (interfaz) | Suscripción realtime a pedidos activos. |
| `SupabaseKitchenDataSource` | Canal realtime `realtime:venue_<id>:orders`. |
| `KitchenController` | Stream de pedidos activos; expone lista ordenada por hora. |
| `KdsScreen` | Pantalla KDS: tarjetas de pedido con cambio de estado. |

## Feature: `analytics`

| Componente | Responsabilidad |
|---|---|
| `AnalyticsRepository` (interfaz) | Consulta KPIs del periodo seleccionado. |
| `SupabaseAnalyticsDataSource` | Llama a RPC `dashboard_kpis(venue_id, period)`. |
| `AnalyticsController` | Estado del dashboard con filtro de periodo. |
| `DashboardScreen` | Tarjetas KPI + gráfico de ventas (`fl_chart`). |
| `CsvExporter` | Genera y descarga CSV con separador `;` y UTF-8-BOM (compatible Excel chileno). |

## Reglas de imports

- **Sin imports cruzados entre features.** Un feature no importa de otro feature directamente; pasa por `lib/core/` si necesita compartir tipos.
- **`presentation/` solo importa `domain/`** (no `data/`).
- **`data/` solo importa `domain/`** (interfaces); las implementaciones concretas se inyectan vía Riverpod en `lib/app/providers.dart`.
- **`domain/` no importa nada de Flutter, Supabase, Drift ni `dart:io|dart:html`.** RNF-PORT-001.

Verificado en code review (DoD). Si surge regresión persistente, agregar lint rule de imports.
