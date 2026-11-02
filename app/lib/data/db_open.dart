// Abertura dos bancos: arquivo local (Android, desktop) ou WebAssembly + IndexedDB (web).
export 'db_open_io.dart' if (dart.library.js_interop) 'db_open_web.dart';
