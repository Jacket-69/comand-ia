# Handoff — COMAND-IA

Última actualización: 2026-05-02.

Este documento existe para retomar el proyecto en un chat nuevo sin depender de memoria implícita. Léelo junto con [ROADMAP.md](ROADMAP.md), [SRS.md](SRS.md), [ARCHITECTURE.md](ARCHITECTURE.md) y [../CONTRIBUTING.md](../CONTRIBUTING.md).

## Estado actual

La deuda técnica detectada después del primer entregable quedó cerrada en `main` y empujada a GitHub. El repositorio compila, analiza, testea y valida la base Supabase local/CI.

Cambios relevantes ya integrados:

- Schema Supabase alineado con SRS/arquitectura: `price_cents`, `total_cents`, estados correctos de pedido, snapshots inmutables de `order_item`, RLS deny-by-default por `venue_id`, `verify_pin()` SECURITY DEFINER y `staff_pin` sin SELECT público.
- `pending_op` quedó explícitamente como tabla local Drift; no existe en Supabase.
- Seed determinista para usuarios, venue, PIN de staff, mesas, menú y pedidos demo.
- Tests pgTAP para contrato RLS y ausencia de `pending_op` en schema público.
- CI con formato, análisis, tests, cobertura mínima, secret scan y validación Supabase/pgTAP.
- `pubspec.lock` versionado.
- Ruta `/order/:tableId` conectada desde la grilla de mesas.
- Tests adicionales para helpers de rol en auth.
- README, SRS y arquitectura sincronizados con el contrato implementado.

## Entorno local

Herramientas verificadas en esta estación:

- Flutter SDK 3.29.3 en `~/.local/share/flutter-sdks/flutter`.
- `flutter` y `dart` disponibles desde `~/.local/bin`.
- Supabase CLI 2.95.4 en `~/.local/bin/supabase`.
- Chrome instalado como `google-chrome-stable`; existe alias local `google-chrome` para Flutter.
- Docker instalado. Supabase local necesita acceso al socket Docker.

No se duplicó Chrome: solo se creó el alias que Flutter espera.

## Comandos de salud

Ejecutar antes de entregar o después de cambios grandes:

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze --fatal-warnings
flutter test --coverage
dart run tool/check_coverage.dart coverage/lcov.info --global-min=60 --domain-min=70
flutter build web --no-pub
supabase db reset
supabase test db
```

Para desarrollo diario:

```bash
supabase start
flutter run -d chrome
```

Al terminar:

```bash
supabase stop
```

## Estado de GitHub

- Rama principal: `main`.
- Remote: `origin` en `git@github.com:Jacket-69/comand-ia.git`.
- GitHub Project: `COMAND-IA — Sprints`.
- Milestones creados: Sprint 1 a Sprint 10.
- Issues usan prefijo `COMA-NNN` en el título y siguen DoR/DoD de [CONTRIBUTING.md](../CONTRIBUTING.md).

## Cómo continuar en un chat nuevo

Mensaje sugerido:

```text
Estamos en /home/jacket/Documentos/Repositorios/UNIVERSIDAD/comand-ia.
Lee docs/HANDOFF.md, docs/ROADMAP.md, README.md y CONTRIBUTING.md.
Sigue el roadmap del GitHub Project "COMAND-IA — Sprints".
No aparezcas como colaborador en commits; usa la identidad git configurada del repo.
Toma el próximo issue ready, crea una rama según CONTRIBUTING.md, implementa, verifica con CI local y deja commit/PR o push según corresponda.
```

Si el trabajo toca UI, revisar primero las vistas en `../comand-ia_vistas`.

## Riesgos vivos

- Validar Drift en Flutter web sigue siendo gate técnico. Si falla el spike, activar fallback Hive y registrar ADR nueva.
- La app aún usa auth mock en frontend; Supabase Auth real entra después de cerrar la base offline/order flow.
- El tablero debe mantenerse como fuente operativa: si una historia no tiene issue, no entra al sprint.
