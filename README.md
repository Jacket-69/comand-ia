<div align="center">

# COMAND-IA

**Comandas multiplataforma + analítica para locales gastronómicos micro.**

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Postgres+RLS-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Status](https://img.shields.io/badge/status-alpha-orange.svg)]()

*Proyecto académico — Electivo Profesional · ICCI · Universidad Central de Chile · 2026-S1*

</div>

---

## Qué es

COMAND-IA reemplaza la libreta del garzón y el cuaderno del dueño con una sola aplicación que funciona offline-first y sincroniza en tiempo real. La cocina ve el pedido apenas se escribe, el dueño ve qué se vendió ayer sin abrir Excel.

## Estado del proyecto

| | |
|---|---|
| **Fase** | Capa 1 — loop operativo offline-first implementado (toma → cocina → cobro) |
| **Hito siguiente** | Defensa final (2026-07-07) — MVP Capa 1 + Capa 2 |
| **Defensa final** | 2026-07-07 — MVP Capa 1 + Capa 2 |
| **Equipo** | Benjamín López (PO + Backend) · Fernando Godoy (Frontend + UX) |
| **Perfil** | Estándar (M) × BaaS-only — metodología in-house |

## Producto en 3 capas

| Capa | Alcance | Estado |
|---|---|---|
| **1. Operación** | Toma de pedido, KDS realtime, cierre de cuenta | MVP |
| **2. Analítica** | Dashboard owner: ventas, top items, ticket promedio, hora pico | MVP |
| **3. Turismo regional B2G** | Datos agregados anonimizados para municipios y SERNATUR | Roadmap v2 |

La arquitectura ya soporta Capa 3 (multi-tenant + RLS) — queda fuera del MVP académico para no inflar scope, pero un proyecto futuro la habilita sin refactor.

## Stack

| Capa | Tecnología |
|---|---|
| **Frontend** | Flutter 3.x (móvil + tablet + web + desktop desde un solo codebase) |
| **State management** | Riverpod 2.x con codegen |
| **Persistencia local** | Drift (offline-first; spike validatorio Sprint 1) |
| **Routing** | go_router |
| **Backend** | Supabase (Postgres + Auth + Realtime + Storage) |
| **Multi-tenant** | Shared DB + RLS deny-by-default por `venue_id` |
| **Hosting** | Vercel (web preview por PR) + builds nativos Android/iOS |
| **Observabilidad** | Sentry + Supabase logs |
| **CI** | GitHub Actions (format + analyze + tests + cobertura + secret scan + Supabase/pgTAP) |
| **Licencia** | AGPL-3.0 |

## Quickstart

> Pre-requisitos: Flutter 3.x, Dart SDK, Supabase CLI, Node ≥18 (para Vercel CLI), un editor con plugin Flutter.

```bash
# 1. Clonar
git clone https://github.com/<org>/comand-ia.git
cd comand-ia

# 2. Configurar entorno
cp .env.example .env
# Editar .env con SUPABASE_URL, SUPABASE_ANON_KEY, SENTRY_DSN

# 3. Instalar dependencias
flutter pub get

# 4. Levantar Supabase local
supabase start
supabase db reset  # aplica migraciones + seed

# 5. Correr la app
flutter run -d chrome      # web (preview/dev)
flutter run                 # plataforma activa (Android/iOS si hay device)
```

## Estructura del repo

```
comand-ia/
├── lib/
│   ├── main.dart
│   ├── app/                # bootstrap, router, theme
│   ├── core/               # cross-cutting: env, errors, logging
│   └── features/           # vertical slices (data + domain + presentation)
│       ├── auth/           # login (magic link dueño + PIN garzón, mock)
│       └── orders/         # toma de pedido, KDS cocina y cierre de cuenta (offline-first)
│       # Próximo: analytics/ (Capa 2 — dashboard del dueño)
├── test/                   # unit + widget actuales
├── tool/                   # utilidades de CI local
├── supabase/
│   ├── migrations/         # SQL forward-only
│   ├── seed.sql
│   └── config.toml
├── docs/                   # doc-as-code, árbol canónico de la metodología in-house
│   ├── product/            # vision, glossary, storyboards, roadmap
│   ├── requirements/       # srs (RF/RNF); historias y criterios en el board
│   ├── architecture/       # overview, c4-context, c4-container, invariants, decisions/ (ADRs MADR)
│   ├── api/                # contracts (schema + RPCs + tipos generados)
│   ├── database/           # model, migrations, rls
│   ├── sync/               # offline-first
│   ├── quality/            # definition-of-done, testing-strategy
│   ├── security/           # security baseline
│   ├── devops/             # ci-cd, release-process
│   ├── operations/         # observability, runbook
│   └── coding-standards.md
└── .github/workflows/      # CI
```

> La estructura documenta el estado actual del repo y el crecimiento esperado.
> Cocina (KDS) y menú viven dentro de `orders/`; `analytics/` (Capa 2) e
> `integration_test/` se agregan cuando entren sus historias al sprint.

## Documentación

La doc vive como código en `docs/`, organizada según el árbol canónico de la metodología in-house del equipo. Para una entrada por dominio:

### Producto y requisitos

| Documento | Para qué |
|---|---|
| [Visión](docs/product/vision.md) | Problema, usuarios, propuesta de valor, criterios de éxito, fuera de alcance. |
| [Glosario](docs/product/glossary.md) | Lenguaje del dominio compartido entre código y docs. |
| [Roadmap](docs/product/roadmap.md) | Orden de sprints, prioridades, GitHub Projects, criterios de replan. |
| [Storyboards](docs/product/storyboards.md) | Referencias visuales (la carpeta `comand-ia_vistas/` no se versiona acá). |
| [SRS](docs/requirements/srs.md) | Requisitos funcionales + no funcionales mapeados a ISO 25010. |

### Arquitectura

| Documento | Para qué |
|---|---|
| [Overview](docs/architecture/overview.md) | Vista técnica del sistema en una página. |
| [C4 Context](docs/architecture/c4-context.md) | Sistema y actores externos. |
| [C4 Container](docs/architecture/c4-container.md) | Contenedores y stacks. |
| [Invariants](docs/architecture/invariants.md) | ACID-1..7 + aplicación de SOLID. |
| [Layout tree](docs/architecture/layout-tree.md) | Árbol de navegación + widgets por pantalla + capa de estado/datos. |
| [ADRs](docs/architecture/decisions/) | Decisiones costosas de revertir, formato MADR. |

### Datos y backend (BaaS-only)

| Documento | Para qué |
|---|---|
| [Database model](docs/database/model.md) | Tablas, relaciones, triggers SQL. |
| [Database migrations](docs/database/migrations.md) | Política forward-only y convenciones. |
| [RLS](docs/database/rls.md) | Multi-tenant deny-by-default por `venue_id`. |
| [Sync offline-first](docs/sync/offline-first.md) | Cola FIFO + LWW server-side. |
| [API contracts](docs/api/contracts.md) | Schema + RPCs + tipos generados (reemplaza `openapi.yaml`). |

### Calidad, seguridad, devops y operación

| Documento | Para qué |
|---|---|
| [Definition of Done](docs/quality/definition-of-done.md) | Checklist canónico para cerrar historias. |
| [Testing strategy](docs/quality/testing-strategy.md) | Pirámide, cobertura, flujos críticos cubiertos. |
| [Security baseline](docs/security/security.md) | Reglas no negociables, secretos, OWASP, STRIDE informal. |
| [CI/CD](docs/devops/ci-cd.md) | Qué hace cada step del pipeline real. |
| [Release process](docs/devops/release-process.md) | Variante BaaS/SPA: tag → CDN → smoke 1–5 min. |
| [Observability](docs/operations/observability.md) | Sentry + Supabase Dashboard + uptimerobot. |
| [Runbook](docs/operations/runbook.md) | Síntomas → acciones (alcance BaaS-only). |
| [Coding standards](docs/coding-standards.md) | Naming, invariantes, SOLID, imports. |

### Cómo retomar

| Documento | Para qué |
|---|---|
| [Roadmap](docs/product/roadmap.md) | Sprint actual, backlog priorizado, criterios de replan. |
| [Contributing](CONTRIBUTING.md) | DoR, DoD, code review checklist, plantilla de PR. |
| [CHANGELOG](CHANGELOG.md) | Historial de cambios (Keep a Changelog). |

## Equipo y roles

| Persona | Rol primario | Rol secundario |
|---|---|---|
| **Benjamín López** | Product Owner + Backend Lead | Tech Lead (arquitectura, ADRs, Supabase, RLS) |
| **Fernando Godoy** | Frontend Lead + UX champion | Cross-cutting code reviewer |

## Convenciones

- **Idioma:** código e identifiers en inglés · commits, issues, PRs y docs en español
- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/) en español → `feat(orders): agrega tomar pedido offline`
- **Branching:** GitHub Flow + squash merge + PR obligatorio
- **Estilo:** `very_good_analysis` con warnings = errores

Detalles en [CONTRIBUTING.md](CONTRIBUTING.md).

## Contexto académico

Este proyecto es el entregable del ramo **Electivo Profesional**.

**Hitos académicos:**
- 2026-04-28 — Entrega 1 (scaffolding ejecutable)
- 2026-05-26 — Entrega 2 (Capa 1 demoable)
- 2026-07-07 — Entrega 3 (Capa 1 + Capa 2)

## Metodología aplicada

COMAND-IA sigue la metodología in-house del equipo (Scrumban + docs-as-code + C4 + ADRs MADR + SQA día 1 + DevSecOps + GitHub Flow + Conventional Commits). Perfil declarado:

- **Talla:** Estándar (M) — proyecto con usuarios potenciales, 2 devs, alcance de semanas a meses.
- **Tipo:** BaaS-only — frontend Flutter sobre Supabase gestionado; el "backend" son schema, RLS y RPCs.

La combinación **Estándar × BaaS-only** fija qué piezas aplican y cuáles no: lo que la matriz de la metodología marca `—` o `Cambia` para BaaS (`openapi.yaml`, `/healthz`, runbook completo de servidor, Twelve-Factor §4/§7/§8, etc.) ya queda justificado por el tipo, sin una lista de opt-outs aparte.

**Desviaciones por contexto académico** (proyecto evaluado por un profesor, sin clientes reales): threat modeling formal STRIDE, OWASP SAMM, `incident-response.md`, separación staging/prod ensayada y métricas DORA accionables quedan en **opt-in**. Se levantan —documentándolo en un ADR— si el proyecto continúa con clientes reales post-defensa.

## Licencia

Este proyecto se distribuye bajo [AGPL-3.0](LICENSE). Cualquier despliegue público (incluso SaaS) debe publicar el código fuente derivado.

---

<div align="center">
<sub>Construido con disciplina y cariño por dos estudiantes que prefieren código bien hecho a deadlines apretados — pero que igual van a llegar al deadline.</sub>
</div>
