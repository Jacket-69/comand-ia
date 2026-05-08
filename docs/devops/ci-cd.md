# CI/CD — pipeline real

> Lo que corre en cada PR y push a `main`. Fuente de verdad: `.github/workflows/ci.yml`. Este archivo describe **qué hace** y **por qué**, no es la única fuente del pipeline (es el código).

## Triggers

```yaml
on:
  pull_request:
  push:
    branches: [main]
```

- **Pull request** → corre todo el pipeline. Bloquea merge si falla.
- **Push a `main`** → re-corre por consistencia (rare path: si el merge a `main` introduce conflicto resuelto en GitHub UI).

## Jobs

### 1. `analyze-and-test` — Lint, format y tests

Corre en `ubuntu-latest` con `subosito/flutter-action@v2` (Flutter 3.29.3, cache habilitada).

| Step | Comando | Qué verifica |
|---|---|---|
| Instalar dependencias | `flutter pub get` | pubspec.lock consistente. |
| Verificar formato | `dart format --set-exit-if-changed .` | Formato Dart canónico. |
| Analizar código | `flutter analyze --fatal-warnings` | `very_good_analysis` con warnings = errores (RNF-MAIN-002). |
| Tests con cobertura | `flutter test --coverage` | Toda la suite Flutter (unit + widget). |
| Umbrales de cobertura | `dart run tool/check_coverage.dart coverage/lcov.info --global-min=60 --domain-min=70` | Gate de RNF-MAIN-001. |
| Buscar secretos | `! git grep -nE '<patrones>'` | RNF-SEC-004. Patrones: claves SSH/RSA, tokens `sk-*`, JWT compactos. |
| Subir a Codecov | `codecov/codecov-action@v4` | Visibilidad histórica. `continue-on-error: true` (no bloqueante). |

### 2. `supabase-schema` — Migraciones Supabase

Corre en `ubuntu-latest` con `supabase/setup-cli@v1`.

| Step | Comando | Qué verifica |
|---|---|---|
| Levantar Supabase local | `supabase start` | Docker + Postgres listos. |
| Aplicar migraciones y seed | `supabase db reset` | Todas las migraciones aplican limpias desde cero (RNF-SEC-005). |
| Tests pgTAP | `supabase test db` | Contratos SQL: RLS cross-venue, ausencia de `pending_op` en schema público, triggers, RPCs. |

## Reglas

- **Falla rápido.** Si `dart format` falla, no se ejecuta `analyze`. Si `analyze` falla, no se ejecutan tests.
- **Cacheo agresivo.** `subosito/flutter-action@v2` cachea Flutter SDK + `pub get`.
- **Sin pasos manuales escondidos.** Todo lo que hace falta para que el PR pase está en este archivo.
- **Same artifact.** Lo que se testea en `ci.yml` con la versión de Flutter pinneada (3.29.3) es bit-a-bit lo que se publica.

## Pre-commit local (lefthook)

Antes de que el PR llegue a CI, los hooks locales atajan errores comunes:

```yaml
# lefthook.yml
pre-commit:
  parallel: false
  commands:
    format:
      glob: "*.dart"
      run: dart format --set-exit-if-changed {staged_files}
    analyze:
      glob: "*.dart"
      run: flutter analyze --fatal-warnings
```

- Format ejecuta solo sobre archivos staged (rápido).
- Analyze corre completo (es necesario para captar errores de tipo cross-file).
- Si lefthook bloquea el commit, **no se hace bypass**: se arregla y se vuelve a commitear.

## Lo que NO hay en CI (y por qué)

- **No hay step `e2e`.** Los integration tests (`integration_test/`) corren solo nightly y pre-release, no en cada PR (lentos). Se reactivarán como step de PR cuando entren los flujos críticos en Sprint 8+.
- **No hay step `build` matricial Android/iOS/desktop.** Solo se valida en CI lo que se demoa: `flutter build web --no-pub` se hace localmente antes del Avance 2; los builds nativos se ejecutan manualmente cuando se prepara la entrega.
- **No hay `dependabot`/`renovate`.** Está en opt-out por contexto académico (chequeo manual mensual de deps).
- **No hay despliegue automático a prod.** El deploy a `comand-ia.app` solo ocurre con tag `v*`; ver [release-process.md](release-process.md).

## Tiempo de pipeline

- `analyze-and-test`: ~2–4 min (cobertura incluida).
- `supabase-schema`: ~3–5 min (Docker setup + db reset + pgTAP).
- Pipeline total: ~5–7 min en condiciones normales.

Si supera 10 min consistentemente: dividir en jobs paralelos o invertir en cacheo más agresivo.

## Variables de entorno en CI

Configuradas en GitHub Settings › Secrets:

- `SUPABASE_URL` · `SUPABASE_ANON_KEY` · `SUPABASE_SERVICE_ROLE_KEY` · `SUPABASE_DB_PASSWORD`
- `VERCEL_TOKEN` · `VERCEL_ORG_ID` · `VERCEL_PROJECT_ID`
- `SENTRY_DSN` · `SENTRY_AUTH_TOKEN`
- `CODECOV_TOKEN`

Detalle de uso por entorno en [release-process.md](release-process.md). Manejo seguro en [security/security.md](../security/security.md).

## Referencias

- `.github/workflows/ci.yml` — fuente de verdad del pipeline.
- `lefthook.yml` — hooks pre-commit.
- [release-process.md](release-process.md) — qué pasa después del merge a `main`.
- [branching-strategy.md](branching-strategy.md) — flujo Git que alimenta el pipeline.
- [definition-of-done.md](../quality/definition-of-done.md) — gate de CI dentro del DoD.
