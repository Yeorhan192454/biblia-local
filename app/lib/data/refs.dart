import 'bible_db.dart';

/// Texto sem acentos e em minúsculas, para comparar nomes de livros.
String fold(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().runes) {
    final c = String.fromCharCode(ch);
    final i = from.indexOf(c);
    b.write(i >= 0 ? to[i] : c);
  }
  return b.toString();
}

/// Abreviações comuns em português (sem acento), por número do livro.
const _abbr = {
  'gn': 1, 'gen': 1, 'ex': 2, 'lv': 3, 'lev': 3, 'nm': 4, 'num': 4, 'dt': 5, 'js': 6, 'jos': 6, 'jz': 7, 'jui': 7,
  'rt': 8, '1sm': 9, '1sam': 9, '2sm': 10, '2sam': 10, '1rs': 11, '1re': 11, '2rs': 12, '2re': 12, '1cr': 13,
  '2cr': 14, 'ed': 15, 'esd': 15, 'ne': 16, 'nee': 16, 'et': 17, 'est': 17, 'job': 18, 'sl': 19, 'sal': 19,
  'pv': 20, 'prov': 20, 'ec': 21, 'ecl': 21, 'ct': 22, 'cant': 22, 'is': 23, 'isa': 23, 'jr': 24, 'jer': 24,
  'lm': 25, 'lam': 25, 'ez': 26, 'eze': 26, 'dn': 27, 'dan': 27, 'os': 28, 'jl': 29, 'am': 30, 'ob': 31,
  'jn': 32, 'mq': 33, 'na': 34, 'hc': 35, 'hab': 35, 'sf': 36, 'sof': 36, 'ag': 37, 'zc': 38, 'zac': 38,
  'ml': 39, 'mal': 39, 'mt': 40, 'mat': 40, 'mc': 41, 'mar': 41, 'lc': 42, 'luc': 42, 'jo': 43, 'joa': 43,
  'at': 44, 'rm': 45, 'rom': 45, '1co': 46, '1cor': 46, '2co': 47, '2cor': 47, 'gl': 48, 'gal': 48, 'ef': 49,
  'fp': 50, 'fil': 50, 'cl': 51, 'col': 51, '1ts': 52, '1tes': 52, '2ts': 53, '2tes': 53, '1tm': 54, '1tim': 54,
  '2tm': 55, '2tim': 55, 'tt': 56, 'tit': 56, 'fm': 57, 'flm': 57, 'hb': 58, 'heb': 58, 'tg': 59, 'tia': 59,
  '1pe': 60, '1ped': 60, '2pe': 61, '2ped': 61, '1jo': 62, '2jo': 63, '3jo': 64, 'jd': 65, 'jud': 65,
  'ap': 66, 'apoc': 66, 'salmo': 19, 'cantares': 22, 'canticos': 22, 'apocalipse': 66,
};

class RefMatch {
  final Book book;
  final int? chapter;
  final int? verse;
  const RefMatch(this.book, this.chapter, this.verse);
}

/// Interpreta o que foi digitado como livro ou referência: "jo 3 16", "joão 3:16", "1 cor 13", "salmos".
/// Devolve os livros possíveis, o mais provável primeiro; vazio quando não parece referência.
List<RefMatch> parseRef(List<Book> books, String input) {
  final m = RegExp(r'^\s*([1-3]?)\s*([^\d:.,]+?)\s*(?:(\d+)(?:\s*[:.,\s]\s*(\d+))?)?\s*$').firstMatch(input);
  if (m == null) return [];
  final raw = m.group(2)!.trim();
  // "Jó" com acento é o livro de Jó; sem acento "jo" é João
  final isJob = m.group(1)!.isEmpty && raw.toLowerCase() == 'jó';
  final name = m.group(1)! + fold(raw).replaceAll(RegExp(r'\s+'), '');
  if (name.isEmpty || name.length < 2 && m.group(3) == null) return [];
  final ch = m.group(3) == null ? null : int.parse(m.group(3)!);
  final vs = m.group(4) == null ? null : int.parse(m.group(4)!);

  final found = <Book>[];
  void add(Book b) {
    if (!found.contains(b)) found.add(b);
  }

  if (isJob) add(books[17]);
  final ab = _abbr[name];
  if (ab != null) add(books[ab - 1]);
  for (final b in books) {
    final n = fold(b.name).replaceAll(' ', '');
    if (n == name) add(b);
  }
  // nome começado: só quando não há abreviação ou nome exato
  if (found.isEmpty) {
    for (final b in books) {
      if (fold(b.name).replaceAll(' ', '').startsWith(name)) add(b);
    }
  }
  return [
    for (final b in found)
      // livros de um capítulo só: "Judas 5" é o versículo 5
      if (b.chapters == 1 && ch != null && vs == null)
        RefMatch(b, 1, ch)
      else if (ch == null || ch <= b.chapters)
        RefMatch(b, ch, vs)
  ];
}
