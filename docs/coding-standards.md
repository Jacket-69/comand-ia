# Coding standards — COMAND-IA

> Convenciones de estilo del proyecto. Lo que el linter no puede atrapar pero que mantiene el código legible y los invariantes vivos.

## Linter y formato

- **`very_good_analysis`** con warnings = errores (RNF-MAIN-002).
- `dart format` canónico — sin opciones custom; el formatter manda.
- `lefthook` ejecuta ambos en pre-commit.
- CI bloquea merge si `dart format --set-exit-if-changed` o `flutter analyze --fatal-warnings` fallan.

## Naming

### Idioma

- **Identifiers en inglés** (clases, variables, funciones, parámetros).
- **Comentarios** en español o inglés según consistencia local del archivo.
- **Strings de UI** en español (chileno neutro, sin voseo).

### Convenciones por tipo

| Construcción | Convención | Ejemplo |
|---|---|---|
| Clases, enums, typedefs | `UpperCamelCase` | `OrderRepository`, `AuthStatus`, `VenueId` |
| Variables, métodos, parámetros | `lowerCamelCase` | `tableId`, `createOrder()`, `priceCents` |
| Constantes top-level | `lowerCamelCase` | `defaultPageSize`, no `DEFAULT_PAGE_SIZE` |
| Archivos | `snake_case.dart` | `order_repository.dart`, `auth_controller.dart` |
| Carpetas de feature | `snake_case` | `lib/features/orders/`, no `lib/features/Orders/` |
| Tablas SQL | `snake_case` con renombres canónicos | `customer_order` (no `order`), `dining_table` (no `table`) |
| Columnas SQL | `snake_case` con sufijo de tipo | `*_cents` (int, dinero), `*_at` (timestamp), `*_id` (uuid fk) |
| Eventos en logs | `dominio.accion` | `orders.created`, `auth.pin_blocked`, `sync.flushed` |

### Sufijos consistentes

- `*_cents` para todo monto monetario (siempre `int`).
- `*_at` para timestamps (`created_at`, `updated_at`, `closed_at`, `opened_at`).
- `*_id` para foreign keys.
- `*Repository` para interfaces de repositorio.
- `*DataSource` para implementaciones (remote/local).
- `*Controller` para Riverpod notifiers.
- `*Screen` para pantallas, `*Widget` no se sufija explícitamente.

### Lenguaje del dominio

Si el SRS usa un término, el código usa ese término. Si introduces un término nuevo, agrégalo al [glossary.md](product/glossary.md) en el mismo PR. Nunca uses sinónimos genéricos (`Type`, `Level`) cuando hay un nombre del dominio (`AuthStatus`, `OrderState`).

## Invariantes ACID en código

Los siete invariantes ACID viven en [architecture/invariants.md](architecture/invariants.md). El código debe respetarlos siempre:

- **ACID-1.** `customer_order.venue_id` siempre coincide con `dining_table.venue_id`. Verificado por FK + CHECK.
- **ACID-2.** `order_item.name_snapshot` y `price_cents_snapshot` son inmutables al INSERT. **Nunca actualizar** estos campos.
- **ACID-3.** `total_cents` lo calcula el trigger `compute_order_total()`. **El cliente nunca lo escribe.** Si lo intenta, code review rechaza.
- **ACID-4.** `status = 'closed'` es terminal. No agregues lógica que UPDATE un pedido cerrado.
- **ACID-5.** Toda tabla con `venue_id` tiene RLS habilitada y policy USING. PR sin policy = PR rechazado.
- **ACID-6.** PIN nunca en texto plano ni en logs. Solo `verify_pin()` SECURITY DEFINER lo valida.
- **ACID-7.** `pending_op` es FIFO estricto por `venue_id`. El `SyncService` no reordena.

## SOLID en Flutter

Los principios SOLID en este proyecto se aplican así:

- **S** — Una feature = un slice vertical (`domain/`, `data/`, `presentation/`). Un UseCase = una operación de negocio.
- **O** — Repositorios extienden interfaz abstracta. Cambiar Drift→Hive no toca dominio.
- **L** — Mocks (mocktail) cumplen el contrato exacto de la interfaz.
- **I** — Interfaces específicas por feature; no super-interfaz monolítica.
- **D** — Controllers Riverpod inyectan **interfaces**, no implementaciones concretas.

Code review rechaza:

- Lógica de negocio en widgets (RNF-MAIN-004).
- Repositorios o datasources instanciados directamente en widgets.
- `provider.read()` dentro de `domain/`.
- `domain/` con imports de Flutter, Supabase, Drift, `dart:io` o `dart:html` (RNF-PORT-001).
- Imports cruzados entre features.

## Estructura de archivos por feature

```
features/<feature>/
├── domain/
│   ├── entities/           ← clases de dominio (sin deps de plataforma)
│   ├── repositories/       ← interfaces abstractas
│   └── usecases/           ← una operación por archivo
├── data/
│   ├── datasources/
│   │   ├── remote/         ← implementación Supabase
│   │   └── local/          ← implementación Drift
│   ├── models/             ← DTOs con serialización
│   └── repositories/       ← implementación concreta
└── presentation/
    ├── controllers/        ← Riverpod (anotados con @riverpod)
    ├── screens/            ← pantallas (layout + llamadas a controllers)
    └── widgets/            ← widgets reutilizables del feature
```

## Logs y errores

- **Sin `print`.** Usar el logger del feature.
- **Logs estructurados** con namespace por dominio: `orders.created`, `auth.pin_blocked`, `sync.flushed`.
- **Excepciones no capturadas → Sentry automático.** No envolver `try/catch` para silenciar.
- **Nunca loguear** PIN, JWT, payload completo de pedidos con datos del cliente. Usar identificadores opacos (`venue_id`, `order_id`).

## Comentarios

Default: **no escribir comentarios.** Solo cuando el "por qué" no es obvio:

- Workaround de un bug específico (con link al issue).
- Constraint del dominio que el lector puede no conocer.
- Razón histórica de una elección que parece extraña (con link al ADR).

No comentar lo que el código ya dice ("incrementa contador en 1"). No referenciar el flujo o el caller en comentarios ("usado por X") — eso vive en el PR description o en las pruebas.

## TODOs

- Cada `TODO` debe linkear a un issue: `// TODO(COMA-NNN): explicación corta`.
- TODOs huérfanos sin issue → DoD bloquea merge.

## Imports

Orden:

1. `dart:`
2. `package:flutter/`
3. `package:` (terceros)
4. Imports relativos del proyecto.

Separados por línea en blanco. `dart format` los reordena automáticamente — no se discute.

## Tests

- Naming de archivos: `<archivo_under_test>_test.dart` en mismo path bajo `test/`.
- Naming de grupos: `group('OrderRepository.create', () { ... })`.
- Naming de tests: descriptivo y en presente: `test('persiste en local-cache antes de encolar pending_op', () { ... })`.
- Sin `Random.now()` ni `DateTime.now()` sin inyectar — tests deben ser determinísticos.

## Migraciones SQL

- Header con motivo, idempotencia y ADRs relacionados (ver [database/migrations.md](database/migrations.md)).
- `CREATE OR REPLACE` y `IF NOT EXISTS` cuando sea posible.
- Una migración por PR si toca esquema (excepto cambios indivisibles justificados).
- Forward-only en MVP.

## Referencias

- [architecture/invariants.md](architecture/invariants.md) — ACID + SOLID.
- [product/glossary.md](product/glossary.md) — lenguaje del dominio.
- [database/migrations.md](database/migrations.md) — convenciones SQL.
- [quality/definition-of-done.md](quality/definition-of-done.md) — gate de code review.
- [../CONTRIBUTING.md](../CONTRIBUTING.md) — code review checklist.
