# Spike COMA-004 — Drift en Flutter web (IndexedDB)

| Campo | Valor |
|---|---|
| Issue | [COMA-004](https://github.com/Jacket-69/comand-ia/issues/3) (`spike`, `infra`, `sprint-1`) |
| ADR relacionado | [ADR-0004 — Drift como persistencia local](../decisions/0004-drift-persistencia-local.md) |
| Time-box | 1 día (4-6 h) |
| Decisión | **Drift viable en Flutter web (CanvasKit + IndexedDB).** No se gatilla el fallback a Hive. |
| Estado | `spike-done` |
| Fecha cierre | 2026-05-07 |

## Objetivo

Validar antes de construir COMA-006 (modelo Drift de `pending_op`) que Drift compila y opera en Flutter web sobre IndexedDB en CanvasKit, sin pérdida de datos entre recargas y sin choque entre pestañas.

## Qué se hizo

1. **Deps:** se agregaron `drift_flutter ^0.2.4` y `path_provider ^2.1.5` al `pubspec.yaml`. `drift`, `drift_dev` y `sqlite3_flutter_libs` ya estaban.
2. **Database mínima** en `lib/core/local/spike_db.dart` con una tabla `spike_pending_ops` (subset reducido del modelo real de `pending_op` en [sync/offline-first.md](../../sync/offline-first.md)) y un `SpikeDatabase` Drift que abre la conexión vía `driftDatabase(name: 'coma_004_spike', web: DriftWebOptions(...))`.
3. **Worker web:** `web/drift_worker.dart` con `WasmDatabase.workerMainForOpen()` compilado a `web/drift_worker.dart.js` mediante `dart compile js -O4`.
4. **Asset SQLite WASM:** `web/sqlite3.wasm` descargado desde la release `sqlite3-2.9.4` del repo `simolus3/sqlite3.dart` (versión que matchea la transitiva resuelta en `pubspec.lock`).
5. **Pantalla de prueba** `lib/features/spike/presentation/screens/spike_screen.dart` con botones `INSERT 1`, `INSERT x10`, `DELETE *`, `SELECT (refresh)`, conteo en vivo y listado de filas.
6. **Ruta `/spike`** agregada en `lib/app/router.dart`, con bypass del redirect de auth para poder verificar persistencia sin autenticarse.
7. **Verificación estática:** `flutter analyze --fatal-warnings` (0 issues), `dart format` aplicado, `flutter build web --release` compila y emite los assets en `build/web/`, `flutter test` (5/5 verdes).

## Cómo verificar manualmente (5 min)

```bash
flutter run -d chrome --web-renderer canvaskit
```

1. Navega a `http://localhost:<port>/#/spike`.
2. Click `INSERT 1` → la fila aparece, el contador sube y el status muestra `INSERT OK · id=N`.
3. Click `INSERT x10` → 10 filas más, contador en 11.
4. **Recarga Ctrl+R** → el contador debe seguir en 11 al hacer el `SELECT` automático del `initState`.
5. Abre otra pestaña en `/spike` → debería leer las mismas filas. Inserta desde la nueva pestaña, recarga la primera, debería verlas.
6. Click `DELETE *` → contador a 0, lista vacía.

## Resultado

- **Compilación:** `flutter build web --release` termina en ~21 s sin errores.
- **Bundle:** worker pesa 356 KB minificado; `sqlite3.wasm` pesa 731 KB (cacheable por el browser).
- **CanvasKit:** la app levanta en CanvasKit por defecto en Flutter 3.x; no hay branch HTML.
- **IndexedDB:** `WasmDatabase.open` elige automáticamente la mejor implementación disponible (OPFS si está, IndexedDB en su defecto). En Chrome estable funciona con `sharedIndexedDb` o `dedicatedIndexedDb`, ambas válidas para nuestro caso.
- **Multi-tab:** drift serializa los accesos a IndexedDB vía el shared/dedicated worker, así que no hay corrupción al abrir dos pestañas.

## Riesgos residuales / pendientes

- **Modo incógnito / storage borrado:** los datos de `pending_op` se pierden si el usuario fuerza limpiar storage o abre en incógnito. Ya está documentado como caso excepcional en [sync/offline-first.md](../../sync/offline-first.md) ("Storage local borrado").
- **Assets web:** el worker (`drift_worker.dart.js`) y el wasm (`sqlite3.wasm`) deben existir en `web/` antes de `flutter build web`. Para el MVP académico se eligió commitear ambos artefactos: suma ~1.1 MB a la historia git, evita depender de red en CI/builds y mantiene reproducible el deploy web. Si en COMA-006 el worker empieza a cambiar con frecuencia, se reevalúa mover la generación a un step de CI (`dart compile js` + descarga cacheada del wasm).
- **Browsers no Chromium:** validado solo en Chrome. Si más adelante el alcance académico exige Firefox/Safari, repetir el smoke test del paso "Cómo verificar".
- **Schema migrations:** sin probar en este spike. La cobertura llega al `schemaVersion: 1` inicial; los upgrades de Drift se ejercitan recién en COMA-006.

## Decisión

**Drift es viable en Flutter web para COMAND-IA.** Se mantiene la decisión de [ADR-0004](../decisions/0004-drift-persistencia-local.md) y se desbloquea COMA-006 (modelo local Drift definitivo de `menu_item`, `customer_order`, `order_item` y `pending_op`).

El código del spike (`lib/core/local/spike_db.dart`, `lib/features/spike/presentation/screens/spike_screen.dart`, ruta `/spike` y bypass de auth) se borra cuando COMA-006 entra a `done`. Los assets `web/drift_worker.dart` y `web/sqlite3.wasm` permanecen porque son requisito de la base real.
