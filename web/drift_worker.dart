import 'package:drift/wasm.dart';

/// Entry point para el worker de Drift en Flutter web.
/// Compilado a `drift_worker.dart.js` con `dart compile js -O4`.
void main() => WasmDatabase.workerMainForOpen();
