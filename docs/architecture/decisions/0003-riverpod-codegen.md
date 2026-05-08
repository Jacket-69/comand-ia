---
adr: 0003
title: Riverpod 2.x con codegen para state management
status: accepted
date: 2026-04-27
deciders: Benjamín López, Fernando Godoy
tags: [adr, frontend, state-management]
---

# ADR 0003 — Riverpod 2.x con codegen para state management

## Contexto

El estado de la app (sesión, menú, pedidos activos, sync, KPIs del dashboard) debe ser:

1. **Reactivo** — la UI re-renderiza cuando cambia el dato local o llega una actualización por realtime.
2. **Testeable sin contexto de Widget** — los UseCases del dominio no deben requerir `WidgetTester` para probarse.
3. **Aislado de la UI** — la inyección de dependencias (repositorio, datasources) no vive dentro de los widgets.
4. **Compatible con todas las plataformas Flutter** incluida web (CanvasKit) y desktop.

Al empezar Sprint 1 había cuatro candidatos en la conversación: Provider, BLoC, Riverpod, GetX. Cada uno tiene tradeoffs claros en boilerplate, testing y acoplamiento UI.

## Decisión

Adoptamos **Riverpod 2.x con `@riverpod` codegen**. Los providers se generan en archivos `*.g.dart` mediante `build_runner`. Los controllers extienden `AsyncNotifier` o `Notifier` según el caso. Los repositorios se inyectan como providers; los controllers nunca instancian implementaciones concretas (Dependency Inversion, RNF-MAIN-004 indirectamente).

Estructura por feature:

```
features/<feature>/presentation/controllers/
├── <feature>_controller.dart      # @riverpod-anotado
└── <feature>_controller.g.dart    # generado por build_runner
```

## Alternativas consideradas

### Opción A — Provider (clásico, sin codegen)
- **Pros:** El más simple; ancestro de Riverpod; muy poco código nuevo.
- **Contras:** Limitaciones en composición; obliga a `BuildContext` para leer dependencies → testing requiere `Widget` ancestor; no resuelve `Future`/`Stream` de forma idiomática.
- **Por qué se descartó:** El acoplamiento a `BuildContext` complica el testing puro de UseCases.

### Opción B — BLoC (flutter_bloc)
- **Pros:** Patrón claro y consolidado; separación events/states explícita.
- **Contras:** Mucho boilerplate por feature (Event, State, Bloc, mapEventToState); para un equipo de 2 personas en 10 sprints, fricción alta sin ganancia clara para nuestro tamaño de dominio.
- **Por qué se descartó:** El boilerplate compite con tiempo de feature; la separación events/states es valiosa pero excesiva para 5 features MVP.

### Opción C — GetX
- **Pros:** Único paquete con state management + routing + DI + i18n.
- **Contras:** Mezcla estado, routing y DI en un mismo monolito → testing unitario difícil; el "GetX way" se desvía del idiom Flutter; comunidad más fragmentada.
- **Por qué se descartó:** Dificulta el testing unitario y empuja a un patrón heterodoxo dentro del ecosistema Flutter.

### Opción D — Riverpod 2.x con codegen (elegida)
- **Pros:** Testing sin Widget context (`ProviderContainer`); codegen elimina boilerplate; `AsyncValue<T>` resuelve idiomáticamente loading/error/data; compatible web y desktop.
- **Contras explícitos:** `build_runner` debe correr tras cada cambio de interfaz anotada; curva del codegen mayor que Provider clásico.

## Consecuencias

### Positivas
- Testing sin contexto de Widget: los providers son testeables con `ProviderContainer` y `overrideWith` para inyectar mocks.
- Codegen elimina boilerplate y reduce errores en la declaración de providers.
- `AsyncNotifier` cubre loading/error/data sin código manual.
- Riverpod es compatible con todas las plataformas Flutter (web incluido) — alineado con [ADR-0001](0001-flutter-multiplataforma.md).
- Inyección de repositorios via provider permite cumplir SOLID-D sin un container DI externo.

### Negativas / costo
- `build_runner` debe correr después de cada cambio de interfaz anotada. Se integra como `dart run build_runner watch` en el flujo de dev y como step de CI antes de los tests.
- La curva de aprendizaje del codegen es mayor que Provider clásico. Mitigación: Fernando (frontend lead) toma ownership del patrón de controllers y deja ejemplos canónicos en `features/auth/` y `features/orders/`.
- Aumenta el peso de la suite de tests por la cantidad de archivos generados (mitigable con `--delete-conflicting-outputs`).

### Neutras
- Los archivos `*.g.dart` se commitean al repo (no se regeneran en el clone) — alineado con la convención mayoritaria del ecosistema Flutter.

## Cumplimiento / verificación

- Code review rechaza cualquier widget que instancie un repositorio o datasource directamente.
- Code review rechaza cualquier `provider.read()` dentro de la capa de dominio.
- CI corre `dart run build_runner build --delete-conflicting-outputs` antes de `flutter analyze` para garantizar que los `.g.dart` estén actualizados.
- RNF-MAIN-004: lógica de negocio no vive en widgets — verificado en code review (DoD).

## Referencias

- [SRS § 4.6 Maintainability](../../requirements/srs.md) — RNF-MAIN-004.
- [Architecture Components](../c4-components.md).
- ADRs relacionados: [ADR-0001](0001-flutter-multiplataforma.md), [ADR-0004](0004-drift-persistencia-local.md).
- Doc oficial: [riverpod.dev](https://riverpod.dev/).
