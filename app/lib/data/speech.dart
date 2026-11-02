/// Falas de Deus e de Jesus: os dados dizem que parte de cada versículo (em fração das palavras do
/// original) é fala de quem; aqui isso vira trechos de caracteres no texto de uma tradução.
enum Speaker { god, jesus }

class Speech {
  final Speaker who;
  final double start, end;
  const Speech(this.who, this.start, this.end);
}

class SpeechRange {
  final int start, end;
  final Speaker who;
  const SpeechRange(this.start, this.end, this.who);
}

const _open = {'“', '«'};
const _close = {'”', '»'};

/// Calcula os trechos coloridos de um versículo.
///
/// [quoteDepth] é o nível de aspas abertas vindo do versículo anterior; o valor devolvido em
/// `depth` alimenta o próximo versículo do capítulo.
({List<SpeechRange> ranges, int depth}) speechRanges(String text, List<Speech> segs,
    {required bool useQuotes, int quoteDepth = 0}) {
  final len = text.length;
  final inQuote = List<bool>.filled(len, false);
  var depth = quoteDepth;
  if (useQuotes) {
    var lastMark = -1;
    for (var i = 0; i < len; i++) {
      final c = text[i];
      var opens = _open.contains(c), closes = _close.contains(c);
      if (c == '"') {
        opens = i == 0 || RegExp(r'[\s(\[—–-]').hasMatch(text[i - 1]);
        closes = !opens;
      }
      if (opens) {
        depth++;
        inQuote[i] = true;
      } else if (closes) {
        if (depth == 0) {
          // fecha sem ter aberto: a fala vem desde a marca anterior (ou do versículo anterior)
          var j = lastMark + 1;
          while (j < i && ' .,;:'.contains(text[j])) {
            j++;
          }
          for (; j < i; j++) {
            inQuote[j] = true;
          }
        }
        inQuote[i] = true;
        depth = depth > 0 ? depth - 1 : 0;
      } else {
        inQuote[i] = depth > 0;
      }
      if (opens || closes) lastMark = i;
    }
  }
  if (segs.isEmpty || len == 0) return (ranges: const [], depth: depth);

  final hasQuotes = inQuote.contains(true);
  final ranges = <SpeechRange>[];
  for (final s in segs) {
    final a = (s.start * len).round(), z = (s.end * len).round();
    final whole = s.start < 0.04 && s.end > 0.96;
    if (useQuotes && hasQuotes && !whole) {
      // aspas que caem no trecho (com folga, já que a ordem das palavras muda na tradução)
      final pad = (len * 0.15).round();
      final lo = (a - pad).clamp(0, len), hi = (z + pad).clamp(0, len);
      var i = lo, found = false;
      while (i < hi) {
        if (!inQuote[i]) {
          i++;
          continue;
        }
        var j = i;
        while (j < len && inQuote[j]) {
          j++;
        }
        ranges.add(SpeechRange(i, j, s.who));
        found = true;
        i = j;
      }
      if (found) continue;
    }
    final start = s.start < 0.04 ? 0 : _snapStart(text, a);
    final end = s.end > 0.96 ? len : _snapEnd(text, z);
    if (end > start) ranges.add(SpeechRange(start, end, s.who));
  }
  ranges.sort((x, y) => x.start.compareTo(y.start));
  final merged = <SpeechRange>[];
  for (final r in ranges) {
    if (merged.isNotEmpty && r.start <= merged.last.end) {
      final last = merged.removeLast();
      merged.add(SpeechRange(last.start, r.end > last.end ? r.end : last.end, last.who));
    } else {
      merged.add(r);
    }
  }
  return (ranges: merged, depth: depth);
}

/// Início de fala: logo depois de "disse:" / "said," perto do ponto estimado.
int _snapStart(String t, int target) {
  final win = (t.length * 0.3).round();
  final verb = RegExp(
      r'(diz|disse|dizendo|respond|clam|perguntou|ordenou|falou|said|saith|saying|answer|cried|spake|commanded)\w*\s*$',
      caseSensitive: false);
  int? pos;
  var bestScore = 1 << 30;
  for (var i = 0; i < t.length; i++) {
    if (!':,;'.contains(t[i]) || (i + 1 - target).abs() > win) continue;
    final before = t.substring(i < 30 ? 0 : i - 30, i);
    var score = (i + 1 - target).abs();
    if (verb.hasMatch(before)) score -= t.length;
    if (score < bestScore) {
      bestScore = score;
      pos = i + 1;
    }
  }
  var p = pos ?? _wordBoundary(t, target);
  while (p < t.length && t[p] == ' ') {
    p++;
  }
  return p;
}

/// Fim de fala: depois da pontuação mais próxima do ponto estimado.
int _snapEnd(String t, int target) {
  final win = (t.length * 0.3).round();
  int? pos;
  for (var i = 0; i < t.length; i++) {
    if ('.;:?!,'.contains(t[i]) && (i + 1 - target).abs() <= win) {
      if (pos == null || (i + 1 - target).abs() < (pos - target).abs()) pos = i + 1;
    }
  }
  return pos ?? _wordBoundary(t, target);
}

int _wordBoundary(String t, int target) {
  var p = target.clamp(0, t.length);
  while (p < t.length && t[p] != ' ') {
    p++;
  }
  return p;
}
