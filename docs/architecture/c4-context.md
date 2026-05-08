# C4 Nivel 1 — Contexto

> Sistema y actores externos. Para el zoom dentro del sistema, ver [c4-container.md](c4-container.md).

## Diagrama

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

## Actores

| Actor | Rol | Dispositivo típico |
|---|---|---|
| **Garzón** | Toma pedidos en mesas; ve estado de sus pedidos. | Tablet (principal) o móvil; web fallback. |
| **Owner (dueño)** | Gestiona menú, ve analítica, hace onboarding. | Desktop o tablet; web. |
| **Cocina** | Ve los pedidos llegando en tiempo real (KDS); marca como `preparing` y `ready`. | Tablet montada en pared; web. |

Los tres actores comparten **un mismo codebase** (la app Flutter) — diferencian su vista por rol y por capa de auth (`owner` vía magic link; `staff` vía PIN).

## Sistemas externos

| Sistema | Tipo | Responsabilidad |
|---|---|---|
| **Supabase** | BaaS | Único backend gestionado: Postgres + Auth + Realtime + Storage. Ver [ADR-0002](decisions/0002-supabase-baas-backend.md). |
| **Sentry** | SaaS | Captura de excepciones y breadcrumbs en el frontend. Ver [observability](../operations/observability.md). |
| **Vercel** | Hosting | Hosting del build web con preview automático por PR. |

No hay otros sistemas externos en el MVP (sin pasarelas de pago, sin servicios de impresión, sin integración con terceros).

## Flujos típicos por actor

- **Garzón → Sistema → Cocina:** garzón abre la app en tablet → autentica con PIN → toma pedido en una mesa → confirma. Si hay red, llega al KDS de cocina en ≤2 s; si no, queda en `pending_op` local y se sincroniza al reconectar.
- **Owner → Sistema:** owner abre web en desktop → autentica con magic link → consulta dashboard del día → exporta CSV.
- **Sistema → Sentry:** excepción no capturada en el frontend → breadcrumb + payload mínimo a Sentry → alerta por email si error rate > 5/min durante 5 min.

## Fronteras

- **Dentro del sistema** (lo que el equipo escribe): app Flutter (`comand-ia/`), schema Postgres + RLS + RPCs (`supabase/`).
- **Fuera del sistema** (gestionado por terceros): Supabase como producto, Sentry como SaaS, Vercel como CDN.
