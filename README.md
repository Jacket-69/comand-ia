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
| **Fase** | Sprint 0 — capa documental cerrada · próximo: Sprint 1 (Fundación) |
| **Hito siguiente** | Avance 2 (2026-05-26) — Capa 1 demoable |
| **Defensa final** | 2026-07-07 — MVP Capa 1 + Capa 2 |
| **Equipo** | Benjamín López (PO + Backend) · Fernando Godoy (Frontend + UX) |

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
| **CI** | GitHub Actions (lint + format + tests) |
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
│       ├── auth/
│       ├── menu/
│       ├── orders/         # toma de pedido + sync queue
│       ├── kitchen/        # KDS realtime
│       └── analytics/      # dashboard Capa 2
├── test/                   # unit + widget
├── integration_test/       # flujos end-to-end
├── supabase/
│   ├── migrations/         # SQL forward-only
│   ├── seed.sql
│   └── config.toml
├── docs/
│   ├── SRS.md              # requisitos funcionales y no funcionales
│   ├── ARCHITECTURE.md     # C4 + modelo de datos + RLS + sync
│   └── decisiones.md       # ADRs compactos
└── .github/workflows/      # CI
```

## Documentación

| Documento | Para qué |
|---|---|
| [SRS](docs/SRS.md) | Qué hace el sistema (requisitos funcionales + no funcionales mapeados a ISO 25010) |
| [Architecture](docs/ARCHITECTURE.md) | Cómo está hecho (C4, modelo de datos, RLS, sync offline-first, contratos API) |
| [Decisiones](docs/decisiones.md) | Por qué se eligió cada cosa (ADRs en formato Nygard compacto) |
| [Contributing](CONTRIBUTING.md) | Cómo trabajamos (branching, commits, DoR/DoD, code review) |

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

## Licencia

Este proyecto se distribuye bajo [AGPL-3.0](LICENSE). Cualquier despliegue público (incluso SaaS) debe publicar el código fuente derivado.

---

<div align="center">
<sub>Construido con disciplina y cariño por dos estudiantes que prefieren código bien hecho a deadlines apretados — pero que igual van a llegar al deadline.</sub>
</div>
