# Layout tree — COMAND-IA

> Árbol de navegación y de widgets de la app Flutter, actualizado a la Evaluación 2 (2026-06).
> Muestra cómo se encadenan **rutas → pantallas → widgets → estado (Riverpod) → datos (Drift/Supabase)**.

La app corre desde un solo codebase Flutter en **web, Android, iOS, Linux, macOS y Windows**
(verificado: `flutter build apk` genera `app-debug.apk` y `app-release.apk`).

## 1. Árbol de navegación (go_router)

`main.dart` → `ComandIaApp` → `MaterialApp.router(routerProvider)`.

El `routerProvider` aplica un **redirect de autenticación**: sin sesión, cualquier ruta cae a
`/login`; con sesión, `/login` redirige a `/tables`. La ruta `/spike` es pública.

```
(initialLocation: /tables)
│
├── /login ............. LoginScreen          público; redirige a /tables si hay sesión
│       ├── owner: magic link (email)
│       └── garzón: PIN
│
├── /tables ............ TableGridScreen       home tras login — grilla de mesas en vivo
│       ├── tap mesa LIBRE ───────────────────────────► /order/:tableId   (pedido nuevo)
│       └── tap mesa CON PEDIDO ─► hoja de acciones
│                ├── "Seguir pidiendo" ──────────────► /order/:tableId   (modo agregar)
│                └── "Pedir la cuenta" ──────────────► /checkout/:orderId
│
├── /order/:tableId .... OrderScreen           toma de pedido (Vista categorías → Vista ítems)
│       └── "Enviar a Cocina" / "Agregar a cocina" ──► vuelve a /tables
│
├── /kitchen ........... KitchenScreen         KDS de cocina (pedidos activos en vivo)
│
├── /checkout/:orderId . CheckoutScreen        cierre de cuenta + pago + propina
│       └── "Cerrar cuenta" ────────────────────────► vuelve a /tables (mesa queda libre)
│
├── /dashboard ......... (placeholder)         Capa 2 — analítica del dueño (próximo)
└── /spike ............. SpikeScreen           validación de Drift en web (COMA-004)
```

**Ciclo operativo completo:** `tables → order → (kitchen) → checkout → tables`.

## 2. Árbol de widgets por pantalla

Cada pantalla declara de qué *provider* de Riverpod se alimenta (ver §3).

### LoginScreen · `features/auth` ← `authControllerProvider`

```
LoginScreen (ConsumerStatefulWidget)
└── Scaffold
    └── selector dueño / garzón
        ├── _OwnerForm ....... campo email + ElevatedButton.icon "Enviar enlace mágico"
        └── _StaffForm ....... campo PIN  + ElevatedButton.icon "Ingresar"
```

### TableGridScreen · `features/orders` ← `tablesViewProvider`, `currentUserProvider`

```
TableGridScreen (ConsumerWidget)
└── Scaffold
    ├── AppBar ............. "Selecciona una Mesa" + saludo
    └── Column
        ├── barra de stats .. Row[ _StatBadge "Libres", _StatBadge "Con Orden" ]
        ├── GridView.builder
        │     └── _TableCard (×N)            número + estado + total + punto de estado
        │           └── InkWell(onTap)
        │                 ├── mesa libre  → context.go('/order/:id')
        │                 └── mesa ocupada → showModalBottomSheet
        │                        ├── "Seguir pidiendo" → /order/:id
        │                        └── "Pedir la cuenta"  → /checkout/:orderId
        └── leyenda ......... Row[ _LegendDot ×3 ] = 🔴 Esperando · 🟢 Preparando · 🟡 Listo
```

El punto de estado deriva del `OrderStatus`: `sent → esperando (rojo)`,
`preparing → preparando (verde)`, `ready → listo (amarillo)`.

### OrderScreen · `features/orders` ← `orderDraftControllerProvider(tableId)`, `menuLocalRepositoryProvider`, `devSeedProvider`

```
OrderScreen (ConsumerWidget)
└── devSeedProvider.when(loading / error / data)
    └── _OrderContent
        ├── Vista 2 — _CategorySelectionView   (cuando no hay categoría activa)
        │     └── Scaffold → AppBar → GridView.builder → _CategoryCard (×6)
        └── Vista 3 — _ItemListView            (con categoría activa)
              └── Scaffold
                  ├── AppBar con buscador
                  ├── ListView.builder → _MenuItemCard (×N, con stepper de cantidad)
                  └── _OrderPanel
                        ├── (modo agregar) banner "Pedido actual · N ítems / $X"
                        ├── subtotal del borrador
                        └── ElevatedButton "Enviar a Cocina" / "Agregar a cocina"
```

### KitchenScreen · `features/orders` ← `kitchenOrdersProvider`, `orderItemsProvider`, `kitchenControllerProvider`

```
KitchenScreen (ConsumerWidget)
└── Scaffold
    ├── AppBar "Cocina"
    └── kitchenOrdersProvider.when(...)
          ├── data  → ListView.builder → KdsOrderCard (×N)   ← widget reutilizable
          │              ├── encabezado de mesa + estado del pedido
          │              └── lista de ítems (← orderItemsProvider(orderId))
          │                    └── chip de estado + botón avanzar (sent→preparing→ready)
          ├── empty → _KdsEmptyView
          └── error → _KdsErrorView
```

### CheckoutScreen · `features/orders` ← `checkoutOrderProvider(orderId)`, `orderItemsProvider`, `checkoutControllerProvider`

```
CheckoutScreen (ConsumerStatefulWidget)
└── Scaffold
    ├── AppBar "Cobrar cuenta"
    └── _CheckoutBody
        ├── _SectionCard "Detalle" → _ItemList    nombre × cant = subtotal de línea + subtotal
        ├── _SectionCard "Método de pago" → _PaymentMethodSelector → _PaymentChip (×4)
        │        Efectivo · Tarjeta · Transferencia · Otro
        ├── _SectionCard "Propina" → _TipSelector → _TipPercentButton (0% · 10% · 15% · Otro)
        ├── _TotalDisplay ...... Subtotal + Propina = Total a cobrar
        └── ElevatedButton "Cerrar cuenta"
```

**Invariante visible (ACID-3):** el _Subtotal_ (= `total_cents` persistido) es solo la suma de
ítems; la _Propina_ (`tip_cents`) se muestra y guarda **aparte** y nunca entra al total del pedido.

### Widgets reutilizables

| Widget | Ubicación | Usado en |
|---|---|---|
| `KdsOrderCard` | `features/orders/presentation/widgets/` | KitchenScreen |

Cada pantalla además compone widgets privados (`_TableCard`, `_MenuItemCard`, `_PaymentChip`,
`_TipPercentButton`, `_SectionCard`, etc.) que encapsulan piezas visuales repetidas.

## 3. Capa de estado y datos (cómo cuelga de las pantallas)

Las pantallas no hablan con la base directamente: observan **providers de Riverpod**, que delegan en
**repositorios** (interfaces de `domain/`), implementados sobre **Drift** (`data/local/`).

```
Pantalla (presentation)
   │  ref.watch / ref.read
   ▼
Provider Riverpod
   ├── tablesViewProvider ........ StreamProvider  (combina mesas + pedidos vivos)
   ├── kitchenOrdersProvider ..... StreamProvider  (pedidos sent/preparing/ready)
   ├── orderItemsProvider(id) .... StreamProvider.family
   ├── checkoutOrderProvider(id) . FutureProvider.family
   ├── orderDraftControllerProvider(tableId) . StateNotifierProvider.family
   ├── kitchenControllerProvider . StateNotifierProvider
   └── checkoutControllerProvider  StateNotifierProvider
   │
   ▼
Repositorio (domain/repositories — interfaz)
   ├── OrderLocalRepository
   ├── MenuLocalRepository
   ├── DiningTableLocalRepository
   └── PendingOpQueue
   │
   ▼
Implementación Drift (data/local/repositories) → AppDatabase
   └── SQLite (móvil / escritorio)  ·  IndexedDB (web)
   │
   ▼ (cada cambio encola una operación)
Cola FIFO  pending_op  ⇢  [diferido COMA-008]  ⇢  Supabase (Postgres + RLS)
```

**Offline-first:** toda escritura persiste local y encola un `PendingOp`
(`create_order` · `update_order_item` · `close_order`). El drenado hacia Supabase
y el realtime cross-device son el siguiente paso (COMA-008); hoy el loop completo
funciona en un dispositivo sin red.

## Referencias

- [Overview de arquitectura](overview.md)
- [Invariantes ACID](invariants.md)
- [Sync offline-first](../sync/offline-first.md)
- [Router](../../lib/app/router.dart) · pantallas en `lib/features/*/presentation/screens/`
