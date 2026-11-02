import 'dart:typed_data';

import 'package:sqlite3/common.dart';

import 'db_open.dart';
import 'speech.dart';

class Book {
  final int id;
  final String code;
  final String name;
  final String testament;
  final int chapters;
  const Book(this.id, this.code, this.name, this.testament, this.chapters);
}

class Version {
  final String id;
  final String name;
  final String abbr;
  final String lang;
  final String license;
  final String credit;
  const Version(this.id, this.name, this.abbr, this.lang, this.license, this.credit);
}

class Verse {
  final int book;
  final int chapter;
  final int verse;
  final String text;
  const Verse(this.book, this.chapter, this.verse, this.text);
}

class Word {
  final int pos;
  final String lang;
  final String text;
  final String translit;
  final String gloss;
  final String strong;
  final String morph;
  final String ed;
  /// Glosa desta ocorrência em português; vazia enquanto não traduzida.
  final String glossPt;
  const Word(this.pos, this.lang, this.text, this.translit, this.gloss, this.strong, this.morph, this.ed, this.glossPt);

  bool get isHebrew => lang == 'he';

  /// No grego: K/k = Textus Receptus, N/n = edição crítica (Nestle-Aland/SBL).
  bool inTR() => ed.contains('K') || ed.contains('k');
  bool inCritical() => ed.contains('N') || ed.contains('n');
}

class LexEntry {
  final String strong;
  final String lemma;
  final String translit;
  final String glossEn;
  final String glossPt;
  final String defEn;
  final String defPt;
  const LexEntry(this.strong, this.lemma, this.translit, this.glossEn, this.glossPt, this.defEn, this.defPt);
}

/// Vínculo (referência cruzada) para um versículo ou trecho.
class CrossRef {
  final int book;
  final int chapter;
  final int verse;
  final int endChapter;
  final int endVerse;
  final int votes;
  const CrossRef(this.book, this.chapter, this.verse, this.endChapter, this.endVerse, this.votes);

  bool get isRange => endChapter != chapter || endVerse != verse;
}

/// Pessoa, lugar ou outro nome próprio (TIPNR, STEPBible).
class NameEntry {
  final int id;
  final String group; // pessoa, lugar, outro
  final String kind; // Male, Female, Place, Group...
  final String nameEn;
  final String namePt;
  final String summaryEn;
  final String summaryPt;
  final String articleEn;
  final String articlePt;
  final List<int> parents, siblings, partners, children;
  final int total;
  const NameEntry(this.id, this.group, this.kind, this.nameEn, this.namePt, this.summaryEn, this.summaryPt,
      this.articleEn, this.articlePt, this.parents, this.siblings, this.partners, this.children, this.total);

  String get name => namePt.isNotEmpty ? namePt : nameEn;
  String get summary => summaryPt.isNotEmpty ? summaryPt : summaryEn;
  String get article => articlePt.isNotEmpty ? articlePt : articleEn;
  bool get summaryInEnglish => summaryPt.isEmpty && summaryEn.isNotEmpty;
  bool get articleInEnglish => articlePt.isEmpty && articleEn.isNotEmpty;
}

/// Nota de estudo sobre um versículo ou trecho; [html] usa só p, br, em, strong, u e a.
class StudyNote {
  final String label;
  final String html;
  const StudyNote(this.label, this.html);
}

class SearchHit {
  final String version;
  final int book;
  final int chapter;
  final int verse;
  final String marked; // trechos encontrados entre \u0001 e \u0002
  const SearchHit(this.version, this.book, this.chapter, this.verse, this.marked);
}

/// Banco de textos (somente leitura), copiado dos assets na primeira execução.
class BibleDb {
  final CommonDatabase _db;
  late final List<Book> books;
  late final List<Version> versions;
  late final List<(int, int)> chapterIndex; // (livro, capítulo) em ordem
  late final List<(String, String)> credits;
  final Map<String, String> _morphCache = {};
  /// Traduções que marcam as falas com aspas (meta 'versoes_aspas'); nas outras o trecho é estimado pela pontuação.
  late final Set<String> quotedVersions;
  /// Fonte das notas de estudo (meta 'notas_fonte'); [hasStudyNotes] é falso quando o banco não traz notas.
  late final String studyNotesSource;
  late final bool hasStudyNotes;

  BibleDb._(this._db) {
    books = _db
        .select('SELECT id, code, name, testament, chapters FROM books ORDER BY id')
        .map((r) => Book(r['id'], r['code'], r['name'], r['testament'], r['chapters']))
        .toList();
    versions = _db
        .select('SELECT id, name, abbr, lang, license, credit FROM versions ORDER BY sort')
        .map((r) => Version(r['id'], r['name'], r['abbr'], r['lang'], r['license'], r['credit']))
        .toList();
    chapterIndex = [
      for (final b in books)
        for (var c = 1; c <= b.chapters; c++) (b.id, c)
    ];
    String meta(String k) {
      final r = _db.select('SELECT value FROM meta WHERE key=?', [k]);
      return r.isEmpty ? '' : (r.first['value'] as String? ?? '');
    }

    quotedVersions = meta('versoes_aspas').split(',').where((e) => e.isNotEmpty).toSet();
    studyNotesSource = meta('notas_fonte');
    hasStudyNotes = _db.select('SELECT 1 FROM notas LIMIT 1').isNotEmpty;
    credits = _db.select('SELECT name, credit FROM credits').map((r) => (r['name'] as String, r['credit'] as String)).toList();
  }

  static Future<BibleDb> open({void Function(String)? onStatus}) async {
    return BibleDb._(await openBibleDatabase(onStatus: onStatus));
  }

  Book book(int id) => books[id - 1];
  Version version(String id) => versions.firstWhere((v) => v.id == id, orElse: () => versions.first);
  int indexOf(int book, int chapter) => chapterIndex.indexWhere((e) => e.$1 == book && e.$2 == chapter);

  /// Trechos de fala de Deus e de Jesus no capítulo, por versículo.
  Map<int, List<Speech>> speech(int book, int chapter) {
    final out = <int, List<Speech>>{};
    for (final r in _db.select('SELECT verse, quem, ini, fim FROM falas WHERE book=? AND chapter=? ORDER BY verse, ini',
        [book, chapter])) {
      out.putIfAbsent(r['verse'] as int, () => []).add(
          Speech(r['quem'] == 'J' ? Speaker.jesus : Speaker.god, (r['ini'] as num).toDouble(), (r['fim'] as num).toDouble()));
    }
    return out;
  }

  List<Verse> chapter(String version, int book, int chapter) => _db
      .select('SELECT verse, text FROM verses WHERE book=? AND chapter=? AND version=? ORDER BY verse',
          [book, chapter, version])
      .map((r) => Verse(book, chapter, r['verse'], r['text']))
      .toList();

  /// Texto do versículo em cada versão que o contém, na ordem das versões.
  List<(Version, String)> compare(int book, int chapter, int verse) {
    final rows = {
      for (final r in _db.select('SELECT version, text FROM verses WHERE book=? AND chapter=? AND verse=?',
          [book, chapter, verse]))
        r['version'] as String: r['text'] as String
    };
    return [for (final v in versions) if (rows.containsKey(v.id)) (v, rows[v.id]!)];
  }

  String? verseText(String version, int book, int chapter, int verse) {
    final r = _db.select('SELECT text FROM verses WHERE version=? AND book=? AND chapter=? AND verse=?',
        [version, book, chapter, verse]);
    return r.isEmpty ? null : r.first['text'] as String;
  }

  List<Word> words(int book, int chapter, int verse) => _db
      .select(
          'SELECT pos, lang, text, translit, gloss, strong, morph, ed, gloss_pt FROM words '
          'WHERE book=? AND chapter=? AND verse=? ORDER BY pos',
          [book, chapter, verse])
      .map((r) => Word(r['pos'], r['lang'], r['text'], r['translit'], r['gloss'], r['strong'], r['morph'], r['ed'],
          r['gloss_pt'] ?? ''))
      .toList();

  LexEntry? lex(String strong) {
    final r = _db.select(
        'SELECT strong, lemma, translit, gloss_en, gloss_pt, def_en, def_pt FROM lexicon WHERE strong=?', [strong]);
    if (r.isEmpty) return null;
    final x = r.first;
    return LexEntry(x['strong'], x['lemma'] ?? '', x['translit'] ?? '', x['gloss_en'] ?? '', x['gloss_pt'] ?? '',
        x['def_en'] ?? '', x['def_pt'] ?? '');
  }

  /// Quantas vezes a palavra (número Strong) aparece na Bíblia.
  int occurrences(String strong) =>
      _db.select('SELECT count(*) AS n FROM words WHERE strong=?', [strong]).first['n'] as int;

  /// Análise gramatical em português; morfemas hebraicos separados por " + ".
  String morphPt(String code) {
    if (code.isEmpty) return '';
    return _morphCache.putIfAbsent(code, () {
      final parts = <String>[];
      for (final seg in code.split('/')) {
        final r = _db.select('SELECT pt FROM morph WHERE code=?', [seg]);
        parts.add(r.isEmpty ? seg : r.first['pt'] as String);
      }
      return parts.join(' + ');
    });
  }

  static int _code(int book, int chapter, int verse) => book * 1000000 + chapter * 1000 + verse;

  /// Vínculos do versículo, os mais relevantes primeiro.
  List<CrossRef> crossRefs(int book, int chapter, int verse) => _db
      .select('SELECT alvo, fim, votos FROM vinculos WHERE ref=? ORDER BY votos DESC', [_code(book, chapter, verse)])
      .map((r) {
        final a = r['alvo'] as int, f = r['fim'] as int;
        return CrossRef(a ~/ 1000000, a ~/ 1000 % 1000, a % 1000, f ~/ 1000 % 1000, f % 1000, r['votos'] as int);
      }).toList();

  final Map<int, Uint8List?> _images = {};

  /// Imagem de uma nota (mapa, quadro), nos bytes do arquivo (JPG, PNG ou WebP).
  Uint8List? noteImage(int id) => _images.putIfAbsent(id, () {
        final r = _db.select('SELECT data FROM imagens WHERE id=?', [id]);
        return r.isEmpty ? null : r.first['data'] as Uint8List;
      });

  /// Notas de estudo do versículo. Notas que cobrem mais de um capítulo só aparecem no versículo em que começam.
  List<StudyNote> studyNotes(int book, int chapter, int verse) {
    final code = chapter * 1000 + verse;
    return _db
        .select('SELECT rotulo, html FROM notas WHERE book=? AND ini<=? AND fim>=? AND (ini=? OR fim-ini<1000) ORDER BY id',
            [book, code, code, code])
        .map((r) => StudyNote(r['rotulo'], r['html']))
        .toList();
  }

  /// Resumo do livro (chapter 0) ou do capítulo; nulo se não houver.
  String? intro(int book, int chapter) {
    final r = _db.select('SELECT texto FROM intros WHERE book=? AND chapter=?', [book, chapter]);
    return r.isEmpty ? null : r.first['texto'] as String;
  }

  static List<int> _ids(Object? v) =>
      (v as String? ?? '').split(' ').where((e) => e.isNotEmpty).map(int.parse).toList();

  static NameEntry _name(Row r) => NameEntry(
      r['id'], r['grupo'], r['tipo'] ?? '', r['nome_en'] ?? '', r['nome_pt'] ?? '', r['resumo_en'] ?? '',
      r['resumo_pt'] ?? '', r['artigo_en'] ?? '', r['artigo_pt'] ?? '', _ids(r['pais']), _ids(r['irmaos']),
      _ids(r['conjuges']), _ids(r['filhos']), r['total'] ?? 0);

  /// Pessoas e lugares citados no versículo.
  List<NameEntry> namesIn(int book, int chapter, int verse) => _db
      .select(
          'SELECT n.* FROM nome_refs r JOIN nomes n ON n.id = r.nome WHERE r.book=? AND r.chapter=? AND r.verse=? '
          'ORDER BY n.total DESC',
          [book, chapter, verse])
      .map(_name)
      .toList();

  NameEntry? name(int id) {
    final r = _db.select('SELECT * FROM nomes WHERE id=?', [id]);
    return r.isEmpty ? null : _name(r.first);
  }

  /// Todos os versículos onde o nome aparece, em ordem.
  List<(int, int, int)> nameRefs(int id) => _db
      .select('SELECT book, chapter, verse FROM nome_refs WHERE nome=? ORDER BY book, chapter, verse', [id])
      .map((r) => (r['book'] as int, r['chapter'] as int, r['verse'] as int))
      .toList();

  /// Faixa de livros da busca: (primeiro, último), ou null para a Bíblia toda.
  static String _scopeSql((int, int)? books, List<Object> args) {
    if (books == null) return '';
    args.addAll([books.$1, books.$2]);
    return ' AND v.book BETWEEN ? AND ?';
  }

  List<SearchHit> search(String query, {String? version, (int, int)? books, int limit = 300}) {
    final terms = RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(query).map((m) => m.group(0)!).toList();
    if (terms.isEmpty) return [];
    final fts = terms.map((t) => '"$t"*').join(' ');
    final sql = StringBuffer(
        "SELECT v.version, v.book, v.chapter, v.verse, highlight(verses_fts, 0, char(1), char(2)) AS h "
        'FROM verses_fts JOIN verses v ON v.id = verses_fts.rowid WHERE verses_fts MATCH ?');
    final args = <Object>[fts];
    if (version != null) {
      sql.write(' AND v.version = ?');
      args.add(version);
    }
    sql.write(_scopeSql(books, args));
    sql.write(' ORDER BY v.id LIMIT $limit');
    return _db
        .select(sql.toString(), args)
        .map((r) => SearchHit(r['version'], r['book'], r['chapter'], r['verse'], r['h']))
        .toList();
  }

  int searchCount(String query, {String? version, (int, int)? books}) {
    final terms = RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(query).map((m) => m.group(0)!).toList();
    if (terms.isEmpty) return 0;
    final fts = terms.map((t) => '"$t"*').join(' ');
    final args = <Object>[fts];
    var sql = 'SELECT count(*) AS n FROM verses_fts JOIN verses v ON v.id = verses_fts.rowid WHERE verses_fts MATCH ?';
    if (version != null) {
      sql += ' AND v.version = ?';
      args.add(version);
    }
    sql += _scopeSql(books, args);
    return _db.select(sql, args).first['n'] as int;
  }
}
