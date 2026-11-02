import 'package:flutter/foundation.dart';
import 'package:sqlite3/common.dart';

import 'db_open.dart';

/// Referência a um versículo: marcadores e anotações ficam presos a ela,
/// não ao texto, para sobreviver a correções nas traduções.
@immutable
class Ref {
  final int book;
  final int chapter;
  final int verse;
  const Ref(this.book, this.chapter, this.verse);

  @override
  bool operator ==(Object other) =>
      other is Ref && other.book == book && other.chapter == chapter && other.verse == verse;

  @override
  int get hashCode => Object.hash(book, chapter, verse);
}

class Note {
  final Ref ref;
  final String text;
  final DateTime updated;
  const Note(this.ref, this.text, this.updated);
}

/// Dados do usuário (marcadores, anotações, preferências), separados do banco de textos.
class UserDb extends ChangeNotifier {
  final CommonDatabase _db;
  UserDb._(this._db) {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS bookmarks(book INTEGER, chapter INTEGER, verse INTEGER, created INTEGER,
        PRIMARY KEY(book, chapter, verse));
      CREATE TABLE IF NOT EXISTS notes(book INTEGER, chapter INTEGER, verse INTEGER, text TEXT, updated INTEGER,
        PRIMARY KEY(book, chapter, verse));
      CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY, value TEXT);
      CREATE TABLE IF NOT EXISTS chapters_read(book INTEGER, chapter INTEGER, created INTEGER,
        PRIMARY KEY(book, chapter));
    ''');
  }

  static Future<UserDb> open() async {
    return UserDb._(await openUserDatabase());
  }

  String? setting(String key) {
    final r = _db.select('SELECT value FROM settings WHERE key=?', [key]);
    return r.isEmpty ? null : r.first['value'] as String;
  }

  void setSetting(String key, String value) {
    _db.execute('INSERT OR REPLACE INTO settings VALUES(?,?)', [key, value]);
  }

  bool isBookmarked(Ref r) =>
      _db.select('SELECT 1 FROM bookmarks WHERE book=? AND chapter=? AND verse=?', [r.book, r.chapter, r.verse]).isNotEmpty;

  void toggleBookmark(Ref r) {
    if (isBookmarked(r)) {
      _db.execute('DELETE FROM bookmarks WHERE book=? AND chapter=? AND verse=?', [r.book, r.chapter, r.verse]);
    } else {
      _db.execute('INSERT INTO bookmarks VALUES(?,?,?,?)',
          [r.book, r.chapter, r.verse, DateTime.now().millisecondsSinceEpoch]);
    }
    notifyListeners();
  }

  /// Ponto de leitura (um só): onde a pessoa parou, marcado com toque longo no versículo.
  Ref? resumePoint() {
    final v = setting('retomar')?.split(':').map(int.tryParse).toList();
    if (v == null || v.length != 3 || v.contains(null)) return null;
    return Ref(v[0]!, v[1]!, v[2]!);
  }

  void setResumePoint(Ref? r) {
    if (r == null) {
      _db.execute("DELETE FROM settings WHERE key='retomar'");
    } else {
      setSetting('retomar', '${r.book}:${r.chapter}:${r.verse}');
    }
    notifyListeners();
  }

  List<Ref> bookmarks() => _db
      .select('SELECT book, chapter, verse FROM bookmarks ORDER BY book, chapter, verse')
      .map((x) => Ref(x['book'], x['chapter'], x['verse']))
      .toList();

  Set<int> bookmarkedVerses(int book, int chapter) => _db
      .select('SELECT verse FROM bookmarks WHERE book=? AND chapter=?', [book, chapter])
      .map((x) => x['verse'] as int)
      .toSet();

  Set<int> readChapters(int book) => _db
      .select('SELECT chapter FROM chapters_read WHERE book=?', [book])
      .map((x) => x['chapter'] as int)
      .toSet();

  int readCount() => _db.select('SELECT COUNT(*) AS n FROM chapters_read').first['n'] as int;

  bool isRead(int book, int chapter) =>
      _db.select('SELECT 1 FROM chapters_read WHERE book=? AND chapter=?', [book, chapter]).isNotEmpty;

  void toggleRead(int book, int chapter) {
    if (isRead(book, chapter)) {
      _db.execute('DELETE FROM chapters_read WHERE book=? AND chapter=?', [book, chapter]);
    } else {
      _db.execute('INSERT INTO chapters_read VALUES(?,?,?)', [book, chapter, DateTime.now().millisecondsSinceEpoch]);
    }
    notifyListeners();
  }

  void clearRead({int? book}) {
    if (book == null) {
      _db.execute('DELETE FROM chapters_read');
    } else {
      _db.execute('DELETE FROM chapters_read WHERE book=?', [book]);
    }
    notifyListeners();
  }

  String? note(Ref r) {
    final x = _db.select('SELECT text FROM notes WHERE book=? AND chapter=? AND verse=?', [r.book, r.chapter, r.verse]);
    return x.isEmpty ? null : x.first['text'] as String;
  }

  void setNote(Ref r, String text) {
    if (text.trim().isEmpty) {
      _db.execute('DELETE FROM notes WHERE book=? AND chapter=? AND verse=?', [r.book, r.chapter, r.verse]);
    } else {
      _db.execute('INSERT OR REPLACE INTO notes VALUES(?,?,?,?,?)',
          [r.book, r.chapter, r.verse, text, DateTime.now().millisecondsSinceEpoch]);
    }
    notifyListeners();
  }

  List<Note> notes() => _db
      .select('SELECT book, chapter, verse, text, updated FROM notes ORDER BY book, chapter, verse')
      .map((x) => Note(Ref(x['book'], x['chapter'], x['verse']), x['text'],
          DateTime.fromMillisecondsSinceEpoch(x['updated'])))
      .toList();

  Set<int> notedVerses(int book, int chapter) => _db
      .select('SELECT verse FROM notes WHERE book=? AND chapter=?', [book, chapter])
      .map((x) => x['verse'] as int)
      .toSet();
}
