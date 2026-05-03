# Arquitectura — COMAND-IA

> Vista técnica del sistema. Complementa el [SRS](SRS.md) (qué hace) explicando cómo está hecho.  
> Para los por qué de cada decisión, ver [decisiones.md](decisiones.md).

---

## 1. Vista general

### Stack

| Capa | Tecnología | Notas |
|---|---|---|
| **Frontend** | Flutter 3.x | Un solo codebase para Android, iOS, web y desktop |
| **State management** | Riverpod 2.x + codegen | Controllers Riverpod inyectan repositorios abstractos (SOLID-D) |
| **Routing** | go_router | Deep links, guards de auth, shell routes para layouts compartidos |
| **Persistencia local** | Drift (SQLite/IndexedDB) | Spike validatorio Sprint 1; fallback Hive si Flutter web da fricción (ver ADR-0004) |
| **Backend** | Supabase | Postgres + Auth + Realtime + Storage en un solo backend gestionado |
| **Multi-tenant** | Shared DB + RLS deny-by-default | Aislamiento por `venue_id` en cada tabla; sin microservicios |
| **Hosting web** | Vercel | Preview automático por PR; deploy prod en tag `v*` |
| **Observabilidad** | Sentry + Supabase logs + Vercel analytics | |
| **CI** | GitHub Actions | Ver [§ 12 Despliegue](#12-despliegue) |

### Principios de diseño

- **Offline-first:** la app funciona sin internet. Supabase es el destino final, no el requisito de operación.
- **Multi-tenant by default:** `venue_id` presente desde el Schema v0; RLS activa en Sprint 1, no "después".
- **AGPL-3.0:** todo despliegue público debe publicar el código fuente derivado.
- **Calidad antes de scope:** si el sprint está apretado, se recorta features, no tests ni revisión.
- **YAGNI estructural:** se empieza con pubspec único. La estructura `apps/`/`packages/` se habilita en Sprint 5+ solo si aparece `apps/landing`.

---

## 2. C4 Nivel 1 — Contexto

```
╔══════════════════════════════════════════════════════════════╗
║                     COMAND-IA (sistema)                      ║
╚══════════════════════════════════════════════════════════════╝
           │                    │                   │
    ┌──────▼──────┐    ┌────────▼───────┐   ┌──────▼──────┐
    │   Garzón    │    │  Owner (dueño) │   │   Cocina    │
    │  tablet/    │    │  desktop/web   │   │   tablet    │
    │  mobile/web │    │                │   │   web       │
    └─────────────┘    └────────────────┘   └─────────────┘
           │                    │                   │
           ▼                    ▼                   ▼
   ┌───────────────────────────────────────────────────────┐
   │           comand-ia (Flutter, un solo codebase)       │
   │   Android · iOS · Web (CanvasKit) · Desktop           │
   └──────────────────────┬────────────────────────────────┘
                          │
          ┌───────────────┼────────────────┐
          ▼               ▼                ▼
   ┌─────────────┐  ┌──────────┐   ┌─────────────┐
   │  Supabase   │  │  Sentry  │   │   Vercel    │
   │(Auth+DB+    │  │  (SaaS)  │   │  (hosting   │
   │Realtime+    │  │          │   │   web)      │
   │Storage)     │  └──────────┘   └─────────────┘
   └─────────────┘
```

**Actores:**
- **Garzón:** usa la app en tablet o móvil para tomar pedidos y ver estado de mesas.
- **Owner:** usa web o desktop para gestionar menú, ver analítica y administrar el venue.
- **Cocina:** pantalla KDS montada en tablet (solo lectura + cambio de estado de pedidos).

**Sistemas externos:**
- **Supabase:** único backend gestionado (Postgres + Auth + Realtime + Storage).
- **Sentry:** captura de excepciones y breadcrumbs en el frontend.
- **Vercel:** hosting del build web con preview automático por PR.

---

## 3. C4 Nivel 2 — Contenedores

```
┌────────────────────────────────────────────────────────────────────┐
│                    comand-ia (Flutter app)                          │
│                                                                      │
│  ┌─────────────────┐  ┌──────────────────┐  ┌──────────────────┐   │
│  │  Presentación   │  │     Dominio      │  │      Datos       │   │
│  │  (Riverpod      │  │  (UseCases,      │  │  (Repositorios   │   │
│  │  Controllers,   │◄─│  Entidades,      │◄─│  Supabase +      │   │
│  │  Widgets)       │  │  Interfaces      │  │  Drift local)    │   │
│  └─────────────────┘  │  Repo)           │  └──────────────────┘   │
│                        └──────────────────┘          │              │
└─────────────────────────────────────────────────────┼──────────────┘
                                                       │
                     ┌─────────────────────────────────┼───────────────────┐
                     │                                 │                   │
              ┌──────▼───────┐              ┌──────────▼──────┐           │
              │ local-cache  │              │    Supabase      │           │
              │ (Drift sobre │              │                  │           │
              │ SQLite/       │              │ ┌──────────────┐ │           │
              │ IndexedDB)   │              │ │  Postgres DB │ │           │
              └──────────────┘              │ └──────────────┘ │           │
                                            │ ┌──────────────┐ │           │
                                            │ │  Auth (JWT)  │ │           │
                                            │ └──────────────┘ │           │
                                            │ ┌──────────────┐ │           │
                                            │ │  Realtime    │ │           │
                                            │ │  (WebSocket) │ │           │
                                            │ └──────────────┘ │           │
                                            │ ┌──────────────┐ │           │
                                            │ │   Storage    │ │           │
                                            │ │  (imágenes   │ │           │
                                            │ │   menú)      │ │           │
                                            │ └──────────────┘ │           │
                                            └──────────────────┘           │
                                                                           │
                                                                    ┌──────▼────┐
                                                                    │  sentry   │
                                                                    │  (SaaS)   │
                                                                    └───────────┘
```

| Contenedor | Tecnología | Responsabilidad |
|---|---|---|
| **comand-ia-app** | Flutter 3.x | UI, lógica de dominio, sync offline |
| **local-cache** | Drift (SQLite / IndexedDB) | Persistencia local; fuente de verdad durante offline |
| **supabase-postgres** | Postgres 15 + Supabase | Fuente de verdad remota; RLS; triggers |
| **supabase-auth** | Supabase Auth (GoTrue) | JWT; magic link; sesiones |
| **supabase-realtime** | Supabase Realtime | WebSocket para KDS y sync de estados |
| **supabase-storage** | Supabase Storage | Imágenes de ítems del menú |
| **sentry-saas** | Sentry | Excepciones, breadcrumbs, alertas |

---

## 4. C4 Nivel 3 — Componentes por feature

Cada feature sigue la misma estructura vertical (Clean Architecture adaptada):

```
features/<feature>/
├── domain/
│   ├── entities/          # modelos de dominio (sin dependencia de Flutter/Supabase)
│   ├── repositories/      # interfaces abstractas (contratos)
│   └── usecases/          # operaciones de negocio (una por archivo)
├── data/
│   ├── datasources/
│   │   ├── remote/        # implementación Supabase
│   │   └── local/         # implementación Drift
│   ├── models/            # DTOs con serialización
│   └── repositories/      # implementación concreta de la interfaz de dominio
└── presentation/
    ├── controllers/        # Riverpod providers/notifiers
    ├── screens/            # pantallas (solo layout y llamadas a controllers)
    └── widgets/            # widgets reutilizables del feature
```

### Feature: auth

| Componente | Responsabilidad |
|---|---|
| `AuthRepository` (interfaz) | Contrato de autenticación |
| `SupabaseAuthDataSource` | Magic link email via Supabase Auth |
| `PinAuthDataSource` | Llama a RPC `verify_pin(venue_id, pin, display_name)` SECURITY DEFINER |
| `AuthController` (Riverpod) | Estado de sesión; expone `User?` al árbol de widgets |
| `LoginScreen` | Pantalla con dos flows: magic link (owner) y PIN (garzón) |

### Feature: menu

| Componente | Responsabilidad |
|---|---|
| `MenuRepository` | CRUD de categorías e ítems |
| `SupabaseMenuDataSource` | Operaciones sobre `menu_category` y `menu_item` |
| `LocalMenuDataSource` | Cache Drift de menú para uso offline |
| `MenuController` | Lista reactiva de ítems; expone stream filtrado por `venue_id` |
| `MenuAdminScreen` | Gestión de categorías e ítems (solo owner) |

### Feature: orders

| Componente | Responsabilidad |
|---|---|
| `OrderRepository` | Crear, modificar, cerrar pedidos |
| `SupabaseOrderDataSource` | Operaciones sobre `customer_order` y `order_item` |
| `LocalOrderDataSource` | Persiste pedidos en Drift durante offline |
| `SyncService` | Vacía `pending_op` hacia Supabase; backoff exponencial |
| `OrderController` | Estado del pedido activo por mesa |
| `TableGridScreen` | Vista de mesas con estado en tiempo real |
| `OrderFormScreen` | Toma de pedido: mesa → ítems → confirmar |

### Feature: kitchen (KDS)

| Componente | Responsabilidad |
|---|---|
| `KitchenRepository` | Suscripción realtime a pedidos activos |
| `SupabaseKitchenDataSource` | Canal realtime `realtime:venue_<id>:orders` |
| `KitchenController` | Stream de pedidos activos; expone lista ordenada por hora |
| `KdsScreen` | Pantalla KDS: tarjetas de pedido con cambio de estado |

### Feature: analytics

| Componente | Responsabilidad |
|---|---|
| `AnalyticsRepository` | Consulta KPIs del periodo seleccionado |
| `SupabaseAnalyticsDataSource` | Llama a RPC `dashboard_kpis(venue_id, period)` |
| `AnalyticsController` | Estado del dashboard con filtro de periodo |
| `DashboardScreen` | Tarjetas KPI + gráfico de ventas (`fl_chart`) |
| `CsvExporter` | Genera y descarga CSV con separador `;` y UTF-8-BOM |

---

## 5. Modelo de datos

### Tablas principales

| Tabla | Columnas clave | Notas |
|---|---|---|
| `venue` | `id` (uuid PK), `name`, `owner_id` (fk auth.users), `settings` (jsonb), `created_at` | Tenant raíz. Una fila = un local. |
| `app_user` | `id` (= auth.users.id), `email`, `role` (owner\|staff), `venue_id`, `display_name`, `created_at` | El owner crea primero `venue` y luego su `app_user` asociado en el onboarding. |
| `staff_pin` | `id`, `venue_id`, `app_user_id`, `pin_hash`, `failed_attempts`, `locked_until` | `pin_hash` via `pgcrypto.crypt()`. SELECT bloqueado por RLS; solo `verify_pin()` SECURITY DEFINER. |
| `menu_category` | `id`, `venue_id`, `name`, `sort_order`, `active`, `updated_at` | |
| `menu_item` | `id`, `venue_id`, `category_id`, `name`, `price_cents` (int), `active`, `image_url`, `updated_at` | Precio en centavos (no float). |
| `dining_table` | `id`, `venue_id`, `label`, `capacity`, `active`, `updated_at` | Renombrado desde `table` para evitar colisión SQL. |
| `customer_order` | `id`, `venue_id`, `dining_table_id`, `status` (open\|sent\|preparing\|ready\|closed\|cancelled), `opened_by`, `opened_at`, `closed_at`, `total_cents`, `payment_method`, `notes`, `updated_at` | `total_cents` calculado por trigger; el cliente nunca lo escribe. |
| `order_item` | `id`, `venue_id`, `order_id`, `menu_item_id`, `name_snapshot`, `price_cents_snapshot`, `quantity`, `comments`, `status`, `updated_at` | Snapshots inmutables al INSERT: el precio y nombre del ítem no cambian aunque se edite el menú. |
| `pending_op` | `id`, `venue_id`, `op_type`, `payload` (jsonb), `created_at`, `attempts` | Local-only (Drift). Cola FIFO de sincronización. No existe en Supabase. |
| `audit_log` | `id`, `venue_id`, `app_user_id`, `action`, `entity`, `entity_id`, `diff` (jsonb), `at` | Trazabilidad mínima de mutaciones importantes. |

### Triggers SQL clave

```sql
-- set_updated_at: actualiza updated_at en toda tabla antes de UPDATE
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;
-- Aplicar: CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON <tabla>
--          FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- compute_order_total: recalcula total del pedido tras mutación en order_item
CREATE OR REPLACE FUNCTION compute_order_total()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE customer_order
  SET total_cents = (
    SELECT COALESCE(SUM(price_cents_snapshot * quantity), 0)
    FROM order_item
    WHERE order_id = COALESCE(NEW.order_id, OLD.order_id)
      AND status != 'cancelled'
  )
  WHERE id = COALESCE(NEW.order_id, OLD.order_id);
  RETURN NEW;
END;
$$;

-- verify_pin: valida PIN sin exponer pin_hash al cliente
CREATE OR REPLACE FUNCTION verify_pin(
  p_venue_id uuid,
  p_pin text,
  p_display_name text DEFAULT NULL
)
RETURNS TABLE(user_id uuid, display_name text, auth_status pin_auth_status)
LANGUAGE plpgsql SECURITY DEFINER AS $$ ... $$;
```

---

## 6. Row-Level Security (RLS)

### Patrón deny-by-default

Toda tabla con `venue_id` tiene RLS habilitada. La policy genérica es:

```sql
-- Patrón aplicado a cada tabla con venue_id
CREATE POLICY "venue_isolation" ON <tabla>
  USING (
    venue_id = current_venue_id()
  );
```

`current_venue_id()` es una función `SECURITY DEFINER` que consulta `app_user` sin disparar recursión de policies. Ninguna tabla permite acceso sin policy explícita. Si una tabla nueva se agrega sin policy, todas las queries retornan 0 filas (deny-by-default de Postgres cuando RLS está habilitada).

### Casos especiales

| Tabla | Policy especial |
|---|---|
| `staff_pin` | SELECT bloqueado completamente. Lectura solo via `verify_pin()` SECURITY DEFINER para evitar exponer `pin_hash`. |
| `venue` | El owner puede crear y ver venues donde `owner_id = auth.uid()`. |
| `audit_log` | INSERT desde SECURITY DEFINER trigger. SELECT solo para owner del venue. |

### Audit nightly con pgTAP

```sql
-- Verificación automática en nightly CI
SELECT plan(1);
SELECT ok(
  (SELECT count(*) FROM pg_tables t
   WHERE t.schemaname = 'public'
     AND t.tablename IN ('venue','app_user','menu_item','customer_order','order_item','dining_table','menu_category')
     AND NOT EXISTS (
       SELECT 1 FROM pg_policies p
       WHERE p.schemaname = 'public' AND p.tablename = t.tablename
     )
  ) = 0,
  'Todas las tablas con venue_id tienen al menos una policy RLS'
);
SELECT finish();
```

---

## 7. Sync offline-first

### Flujo de 6 pasos

```
1. UI llama OrderRepository.create(order)
       │
       ▼
2. Repo persiste en Drift (local-cache) → emite stream → UI re-renderiza con dato local
       │
       ▼
3. Repo encola en pending_op { op_type: 'create_order', payload: {...}, created_at, attempts: 0 }
       │
       ▼
4. SyncService (Riverpod, background) escucha conectividad
   - Conectado → toma ops FIFO de pending_op → llama supabase-dart SDK
       │
       ▼
5. Si Supabase falla:
   - attempts++ en pending_op
   - Backoff exponencial: 2^attempts segundos (máx. 5 min)
   - Si attempts > 10 → notifica owner via estado observable
       │
       ▼
6. Si Supabase OK:
   - Actualiza la fila remota; server retorna updated_at timestamp
   - LWW: si el servidor tiene updated_at > local → local adopta el valor del servidor
   - Borra la op de pending_op
```

### Resolución de conflictos: LWW

El campo `updated_at` se actualiza en Postgres vía trigger `set_updated_at()`. El cliente nunca genera timestamps de updated_at; los recibe del servidor. En caso de conflicto (misma fila editada offline en dos dispositivos), gana la escritura con `updated_at` más reciente en el servidor.

**Garantía:** pérdida cero en desconexión mientras la app permanezca activa. La cola FIFO `pending_op` se persiste en Drift (SQLite/IndexedDB) y sobrevive reinicios de la app.

---

## 8. Contratos API

### supabase-dart SDK (no REST artesanal)

El frontend usa `supabase-dart` SDK directamente. No hay capa REST artesanal entre la app y Supabase.

```dart
// Ejemplo: insertar pedido
final response = await supabase
  .from('customer_order')
  .insert({
    'venue_id': venueId,
    'dining_table_id': tableId,
    'status': 'open',
    'opened_by': userId,
  })
  .select()
  .single();
```

### Tipos generados

```bash
supabase gen types --lang dart > lib/core/db_types.dart
```

Este archivo es generado automáticamente y no se edita a mano. Se regenera en CI si cambia el schema.

### RPCs documentadas

| RPC | Inputs | Output | Notas |
|---|---|---|---|
| `verify_pin(venue_id, pin, display_name)` | uuid, text, text opcional | `{user_id, display_name, auth_status}` | SECURITY DEFINER. Retorna `valid`, `invalid` o `blocked`; bloquea tras 5 intentos fallidos. |
| `dashboard_kpis(venue_id, period)` | uuid, text ('today'\|'7d'\|'30d') | jsonb | Capa 2. Agrega ventas, top items, ticket promedio, hora pico. |

### Realtime channels

```dart
// Suscripción KDS: escucha INSERT/UPDATE en customer_order del venue
supabase
  .channel('venue_${venueId}_orders')
  .onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'customer_order',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'venue_id',
      value: venueId,
    ),
    callback: (payload) => kitchenController.handleChange(payload),
  )
  .subscribe();
```

---

## 9. Migraciones

Las migraciones viven en `supabase/migrations/` con numeración ascendente:

```
supabase/migrations/
├── 0001_init.sql           # tablas base + RLS + triggers
├── 0001_init.sql           # schema base + RLS + triggers + RPCs MVP
└── 0002_...sql             # cambios forward-only futuros
```

**Política:**
- **Forward-only en MVP.** No hay migraciones de rollback. Si algo falla, se aplica una nueva migración correctiva.
- CI verifica `supabase db reset` aplica todo desde cero sin errores.
- Las migraciones deben ser idempotentes cuando sea posible (`CREATE OR REPLACE`, `IF NOT EXISTS`).

---

## 10. Estrategia de pruebas

| Nivel | Herramienta | Objetivo de cobertura | Frecuencia |
|---|---|---|---|
| **Unit (dominio)** | flutter_test + mocktail | ≥70% en `domain/` | Cada PR |
| **Widget** | flutter_test + pumpWidget | ≥50% en `presentation/` | Cada PR |
| **Golden** | golden_toolkit + alchemist | 10-15 pantallas core | Main + nightly |
| **Integration** | integration_test | 3-5 flujos críticos (toma pedido / cierre / dashboard) | Nightly + pre-release |
| **RLS / SQL** | pgTAP | 100% policies cubiertas | Nightly |

**Cobertura global mínima:** ≥60%. Reporte lcov en cada PR como comentario. Si cae, el CI falla.

**Flaky tests:** 1 fallo en 10 corridas → `@Skip` con issue P2 abierto. No se permite flakiness en main.

**Suite lenta:** si la suite supera 5 min en CI → dividir en jobs paralelos.

---

## 11. Observabilidad

### Sentry (frontend)

```dart
await SentryFlutter.init(
  (options) {
    options.dsn = Env.sentryDsn;
    options.tracesSampleRate = 0.1; // 10% sampling en prod
  },
  appRunner: () => runApp(const ProviderScope(child: App())),
);
```

- Excepciones no capturadas → Sentry automático.
- Breadcrumbs de navegación (go_router).
- Alerta: si error rate >5 errores/min durante 5 min → email al owner del proyecto.

### Supabase logs

- Queries lentas visibles en Supabase Dashboard > Logs.
- Postgres logs para queries que superen 1s.

### Health check

Edge function `/health` (Deno) retorna `{"status":"ok","ts":"..."}`. Monitoreada por uptimerobot cada 5 min con alerta por email si cae.

### Vercel analytics

Tier gratuito: pageviews, web vitals. No se almacena PII.

---

## 12. Despliegue

| Entorno | URL | Base de datos | Disparador |
|---|---|---|---|
| **Local dev** | `localhost:port` | `supabase start` (Docker) | Manual (`flutter run -d chrome`) |
| **Preview (PR)** | `comand-ia-pr-NNN.vercel.app` | Supabase staging compartido | Automático en cada PR |
| **Staging** | `staging.comand-ia.app` | Supabase staging | Push a `main` |
| **Prod** | `comand-ia.app` | Supabase prod | Tag `v*` |

Para el semestre académico, los entornos relevantes son **local + preview + staging**. Prod queda configurado pero sin clientes reales hasta post-defensa.

### Variables de entorno

Definidas en `.env.example` (versionado). El archivo `.env.development.local` está en `.gitignore`. Los secretos en GitHub Actions se configuran en Settings > Secrets:

`SUPABASE_URL` · `SUPABASE_ANON_KEY` · `SUPABASE_SERVICE_ROLE_KEY` · `SUPABASE_DB_PASSWORD` · `VERCEL_TOKEN` · `VERCEL_ORG_ID` · `VERCEL_PROJECT_ID` · `SENTRY_DSN` · `SENTRY_AUTH_TOKEN` · `CODECOV_TOKEN`

---

## 13. Invariantes (ACID + SOLID)

### ACID — contratos de integridad de datos

| ID | Invariante |
|---|---|
| ACID-1 | `customer_order.venue_id` y `dining_table.venue_id` siempre coinciden (FK + CHECK). Un pedido no puede apuntar a una mesa de otro venue. |
| ACID-2 | `order_item` snapshotea `name_snapshot` y `price_cents_snapshot` al INSERT. Inmutables aunque se edite el menú después. |
| ACID-3 | `customer_order.total_cents` es derivado. El trigger `compute_order_total()` lo recalcula. El cliente nunca escribe este campo directamente. |
| ACID-4 | `status = 'closed'` es terminal. Un trigger bloquea cualquier UPDATE de items, total o método de pago en un pedido cerrado. |
| ACID-5 | Toda tabla pública con `venue_id` tiene RLS habilitada y al menos una policy USING. Verificado en CI con pgTAP. |
| ACID-6 | El PIN no se persiste ni registra en texto plano. El cliente solo llama `verify_pin(venue_id, pin, display_name)` por TLS; la columna `pin_hash` no es seleccionable desde el cliente. |
| ACID-7 | `pending_op` es FIFO estricto por `venue_id`. El `SyncService` no reordena las operaciones pendientes. |

### SOLID en Flutter

| Principio | Aplicación |
|---|---|
| **S** (Single Responsibility) | Cada feature tiene `domain/`, `data/`, `presentation/` separadas. Un UseCase = una sola operación de negocio. |
| **O** (Open/Closed) | Los repositorios extienden interfaces abstractas. Cambiar Drift→Hive no modifica la capa de dominio. |
| **L** (Liskov Substitution) | Los mocks (mocktail) cumplen exactamente el contrato de la interfaz abstracta. Los tests de dominio pasan con mock y con implementación real. |
| **I** (Interface Segregation) | Los repositorios exponen métodos específicos por feature. No hay super-interfaz monolítica que fuerce implementar métodos irrelevantes. |
| **D** (Dependency Inversion) | Los controllers Riverpod inyectan la interfaz abstracta del repositorio, no la implementación concreta. La inyección ocurre en el provider. |
