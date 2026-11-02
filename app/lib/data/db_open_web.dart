import 'dart:js_interop';

import 'package:sqlite3/wasm.dart';
import 'package:typed_data/typed_data.dart';
import 'package:web/web.dart' as web;

WasmSqlite3? _sqlite;

Future<WasmSqlite3> _load() async => _sqlite ??= await WasmSqlite3.loadFromUrlString('sqlite3.wasm');

/// Banco de textos: baixa o .gz (fica no cache do navegador para uso offline), descompacta e abre na memória.
Future<CommonDatabase> openBibleDatabase({void Function(String)? onStatus}) async {
  final sqlite = await _load();
  onStatus?.call('Preparando a Bíblia para uso offline…');
  final res = await web.window.fetch('assets/assets/db/biblia.db.gz'.toJS).toDart;
  if (!res.ok) throw Exception('Não foi possível carregar os textos (${res.status}).');
  final ds = web.DecompressionStream('gzip');
  final plain = res.body!.pipeThrough(web.ReadableWritablePair(readable: ds.readable, writable: ds.writable));
  final buf = await web.Response(plain).arrayBuffer().toDart;
  final fs = InMemoryFileSystem(name: 'biblia-memoria');
  fs.fileData['/biblia.db'] = Uint8Buffer()..addAll(buf.toDart.asUint8List());
  sqlite.registerVirtualFileSystem(fs);
  return sqlite.open('/biblia.db', vfs: 'biblia-memoria', mode: OpenMode.readOnly);
}

/// Marcadores, anotações e preferências, guardados no IndexedDB do navegador.
Future<CommonDatabase> openUserDatabase() async {
  final sqlite = await _load();
  // pede ao navegador que não apague os dados do usuário quando faltar espaço
  try {
    await web.window.navigator.storage.persist().toDart;
  } catch (_) {}
  final fs = await IndexedDbFileSystem.open(dbName: 'biblia_usuario', vfsName: 'biblia-usuario');
  sqlite.registerVirtualFileSystem(fs);
  return sqlite.open('/usuario.db', vfs: 'biblia-usuario');
}
