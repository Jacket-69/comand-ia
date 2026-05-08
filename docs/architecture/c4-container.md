# C4 Nivel 2 — Contenedores

> Contenedores y stacks dentro del sistema. Para el zoom a componentes por feature, ver [c4-components.md](c4-components.md).

## Diagrama

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
              │ SQLite/      │              │ ┌──────────────┐ │           │
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

## Contenedores

| Contenedor | Tecnología | Responsabilidad |
|---|---|---|
| **comand-ia-app** | Flutter 3.x | UI multiplataforma, lógica de dominio, sync offline. Único deployable que el equipo controla. |
| **local-cache** | Drift sobre SQLite (mobile/desktop) / IndexedDB (web) | Persistencia local; fuente de verdad durante offline. Cola FIFO `pending_op`. |
| **supabase-postgres** | Postgres 15 + Supabase | Fuente de verdad remota; schema multi-tenant; RLS deny-by-default; triggers. |
| **supabase-auth** | Supabase Auth (GoTrue) | JWT; magic link para owner; sesiones para garzón vía RPC `verify_pin()`. |
| **supabase-realtime** | Supabase Realtime | WebSocket para KDS y sync de estados de pedido. |
| **supabase-storage** | Supabase Storage | Imágenes de ítems del menú. |
| **sentry-saas** | Sentry | Excepciones, breadcrumbs, alertas por error rate. |

## Capas internas de la app Flutter

Cada feature en `lib/features/<feature>/` sigue Clean Architecture liviana:

- **`domain/`** — entidades del dominio, interfaces de repositorio, UseCases. Cero dependencias de Flutter, Supabase o Drift (RNF-PORT-001).
- **`data/`** — implementación concreta de repositorios; `datasources/remote/` (Supabase) y `datasources/local/` (Drift); modelos DTO con serialización.
- **`presentation/`** — controllers Riverpod, screens y widgets. Solo interactúan con el dominio vía providers.

Cross-cutting (`lib/core/`):

- `env/` — variables de entorno cargadas vía `--dart-define-from-file=.env`.
- `errors/` — clases de error compartidas.
- `logging/` — wrappers para Sentry y logger local.
- `db_types.dart` — tipos generados con `supabase gen types --lang dart`. **No se edita a mano.**

## Comunicación entre contenedores

| Origen | Destino | Protocolo | Uso |
|---|---|---|---|
| comand-ia-app | local-cache | Dart API (Drift) | Lectura/escritura local; fuente de verdad offline. |
| comand-ia-app | supabase-postgres | HTTPS (`supabase-dart` SDK) | CRUD sobre tablas; llamada a RPCs. |
| comand-ia-app | supabase-auth | HTTPS | Magic link, verificación de sesión, refresh JWT. |
| comand-ia-app | supabase-realtime | WSS | Suscripción a `customer_order` por `venue_id` (KDS y sync de estados). |
| comand-ia-app | supabase-storage | HTTPS | Upload/download de imágenes de menú. |
| comand-ia-app | sentry-saas | HTTPS | Push de excepciones y breadcrumbs. |

No hay capa REST artesanal entre la app y Supabase ([ADR-0002](decisions/0002-supabase-baas-backend.md)). El SDK `supabase-dart` provee la comunicación directa con tipos generados desde el schema.

## Despliegue de contenedores

- **comand-ia-app** se despliega como build web a Vercel (preview por PR, prod por tag `v*`). Builds nativos Android/iOS quedan habilitados pero sin distribución por store en MVP.
- **supabase-* / sentry-saas** son productos gestionados — el equipo no los despliega; solo configura.

Detalles en [release-process](../devops/release-process.md).
