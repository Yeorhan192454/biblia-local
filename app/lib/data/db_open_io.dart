import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

/// Banco de textos: descompacta o do app na primeira vez e a cada versão nova.
Future<CommonDatabase> openBibleDatabase({void Function(String)? onStatus}) async {
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  final dbFile = File(p.join(dir.path, 'biblia.db'));
  final stamp = File(p.join(dir.path, 'biblia.version'));
  final assetVersion = (await rootBundle.loadString('assets/db/version.txt')).trim();
  final current = await stamp.exists() ? (await stamp.readAsString()).trim() : '';
  if (!await dbFile.exists() || current != assetVersion) {
    onStatus?.call('Preparando a Bíblia para uso offline…');
    final data = await rootBundle.load('assets/db/biblia.db.gz');
    final bytes = gzip.decode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    final tmp = File('${dbFile.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(dbFile.path);
    await stamp.writeAsString(assetVersion);
  }
  return sqlite3.open(dbFile.path, mode: OpenMode.readOnly);
}

/// Marcadores, anotações e preferências.
Future<CommonDatabase> openUserDatabase() async {
  final dir = await getApplicationSupportDirectory();
  return sqlite3.open(p.join(dir.path, 'usuario.db'));
}
