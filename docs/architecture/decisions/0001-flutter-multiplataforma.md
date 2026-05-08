---
adr: 0001
title: Flutter multiplataforma como frontend único
status: accepted
date: 2026-04-27
deciders: Benjamín López, Fernando Godoy
tags: [adr, arquitectura, frontend]
---

# ADR 0001 — Flutter multiplataforma como frontend único

## Contexto

COMAND-IA tiene tres canales de uso simultáneos en un mismo local:

- **Garzón** sobre tablet o móvil en sala (Android/iOS).
- **Cocina** sobre tablet montada en pared (web o nativa).
- **Owner** sobre desktop o tablet con calma relativa (web).

Mantener cuatro codebases separados (Android nativo, iOS nativo, web SPA, desktop) es inviable para un equipo de **2 personas con ~20 h/sprint efectivas en 10 sprints académicos**. Además, la lógica de dominio (toma de pedido, cálculo de totales, sincronización offline-first) es idéntica en los tres canales: duplicarla por plataforma multiplica los bugs y rompe los invariantes ACID-1..7.

Las tecnologías evaluadas debían producir **una sola base de código** que compile a todos los targets sin bifurcación de la capa de dominio, con type-safety, soporte web maduro y comunidad activa.

## Decisión

Adoptamos **Flutter 3.x** con un único codebase para Android, iOS, web (CanvasKit) y desktop. La lógica de dominio es **pura Dart sin dependencias de plataforma** (RNF-PORT-001). Las adaptaciones de layout (responsive) se manejan con `LayoutBuilder` y breakpoints, no con código duplicado.

Para el MVP académico el canal principal es **web** sobre tablet/desktop; los builds nativos Android/iOS quedan habilitados desde el mismo codebase y se validan en CI (RNF-COMPAT-002, RNF-COMPAT-003).

## Alternativas consideradas

### Opción A — React Native + web SPA paralela
- **Pros:** Ecosistema JS conocido; muchas libs.
- **Contras:** No cubre desktop ni web nativo; obliga a mantener una SPA web paralela (React/Next) → dos codebases. Bridge JS↔nativo introduce latencia para gestos rápidos del garzón.
- **Por qué se descartó:** No cumple el requisito de "un solo codebase para los 4 targets".

### Opción B — Kotlin Multiplatform Mobile (KMM) + web SPA
- **Pros:** Type-safe; nativo real en mobile.
- **Contras:** UI no compartida (cada plataforma reimplementa la UI); web no soportado oficialmente en estado estable.
- **Por qué se descartó:** Mismo problema que React Native respecto a la UI compartida; además la curva de aprendizaje en el equipo es mayor.

### Opción C — Flutter (elegida)
- **Pros:** Un codebase real para los 4 targets; Dart type-safe; rendering propio (no depende de WebView); Riverpod + Drift + Supabase tienen soporte oficial en web.
- **Contras explícitos:** Bundle web inicial pesado (~2 MB CanvasKit WASM); algunas libs no tienen soporte web maduro; CanvasKit no usa widgets HTML nativos, lo que afecta accesibilidad screen reader si no se cuidan los `Semantics`.

## Consecuencias

### Positivas
- Un solo codebase: el equipo no fragmenta atención entre plataformas.
- Dart es type-safe; el compilador captura errores en tiempo de compilación.
- KDS, dashboard owner y toma de pedido se optimizan para tablet/desktop con el mismo código que mobile.
- Habilita CI build-matrix por plataforma sin duplicar tests de dominio.

### Negativas / costo
- Bundle inicial web pesado (~2 MB WASM). Mitigación: preloader + lazy loading de features.
- Algunas libs Flutter no tienen soporte completo en web. Mitigación: evaluar compatibilidad web en cada dependencia nueva antes de agregarla (anti-fricción del contrato de agentes).
- Rendering CanvasKit no usa widgets HTML nativos → screen readers requieren `Semantics` widgets explícitos (RNF-USAB-004 indirectamente).

### Neutras
- El equipo aprende Dart como lenguaje principal en lugar de TypeScript.
- El "build nativo" se reduce a `flutter build apk|ipa|web|macos`; el deploy nativo a stores queda fuera del MVP académico.

## Cumplimiento / verificación

- CI ejecuta `flutter build web --no-pub` en cada PR; falla bloquea merge.
- Capa `domain/` tiene 0 imports de `dart:html` y `dart:io` directamente (RNF-PORT-001). Verificable con `flutter analyze` + lint rule futura si entran imports de plataforma.
- Smoke test manual en Chromium/Firefox/Safari antes de Avance 2 (RNF-COMPAT-001).

## Referencias

- [SRS § 2.4 Restricciones](../../requirements/srs.md)
- [SRS § 4.7 Portability](../../requirements/srs.md) — RNF-PORT-001, RNF-PORT-002.
- [SRS § 4.2 Compatibility](../../requirements/srs.md) — RNF-COMPAT-001..003.
- [Architecture Overview](../overview.md)
- ADRs relacionados: [ADR-0003](0003-riverpod-codegen.md) (state management), [ADR-0004](0004-drift-persistencia-local.md) (persistencia local).
