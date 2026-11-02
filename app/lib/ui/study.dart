import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/bible_db.dart';
import '../data/user_db.dart';
import '../state.dart';
import '../theme.dart';

const _kinds = {
  'Male': 'Homem',
  'Female': 'Mulher',
  'Place': 'Lugar',
  'Group': 'Povo ou grupo',
  'Supernatural': 'Ser espiritual ou divindade',
  'Musical': 'Termo musical',
  'Time': 'Mês ou festa',
  'Title': 'Título',
  'Star': 'Astro',
  'Other': 'Outro',
};

String kindLabel(NameEntry n) =>
    _kinds[n.kind] ?? (n.group == 'lugar' ? 'Lugar' : n.group == 'pessoa' ? 'Pessoa' : 'Outro');

/// Fecha painéis e páginas abertas e leva o leitor até o versículo.
void openRef(BuildContext context, Ref r) {
  final s = AppScope.read(context);
  // no computador o painel fica ao lado e passa a mostrar o versículo novo
  final wide = MediaQuery.sizeOf(context).width >= 900;
  final from = s.selected; // versículo de origem, para o botão de voltar
  Navigator.of(context).popUntil((route) => route.isFirst);
  s.goTo(r, select: wide, from: from);
}

String crossRefLabel(AppState s, CrossRef x) {
  final name = s.bible.book(x.book).name;
  if (!x.isRange) return '$name ${x.chapter}:${x.verse}';
  if (x.endChapter == x.chapter) return '$name ${x.chapter}:${x.verse}–${x.endVerse}';
  return '$name ${x.chapter}:${x.verse}–${x.endChapter}:${x.endVerse}';
}

/// Lista de vínculos do versículo, com o texto na versão em leitura.
class CrossRefList extends StatefulWidget {
  final Ref ref;
  const CrossRefList({super.key, required this.ref});

  @override
  State<CrossRefList> createState() => _CrossRefListState();
}

class _CrossRefListState extends State<CrossRefList> {
  static const _first = 6;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = ReaderColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final r = widget.ref;
    final refs = s.bible.crossRefs(r.book, r.chapter, r.verse);
    if (refs.isEmpty) return Text('Nenhum vínculo para este versículo.', style: TextStyle(color: c.muted));
    final shown = _all ? refs : refs.take(_first).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final x in shown)
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => openRef(context, Ref(x.book, x.chapter, x.verse)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '${crossRefLabel(s, x)}  ',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.primary)),
                TextSpan(
                    text: (s.bible.verseText(s.version, x.book, x.chapter, x.verse) ?? '') + (x.isRange ? ' …' : '')),
              ]),
              style: const TextStyle(fontFamily: serif, fontSize: 15.5, height: 1.45),
            ),
          ),
        ),
      if (refs.length > _first)
        TextButton(
          onPressed: () => setState(() => _all = !_all),
          child: Text(_all ? 'Mostrar menos' : 'Ver todos os ${refs.length} vínculos'),
        ),
    ]);
  }
}

/// Pessoas e lugares citados no versículo, como botões que abrem a ficha.
class NamesInVerse extends StatelessWidget {
  final Ref ref;
  const NamesInVerse({super.key, required this.ref});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = ReaderColors.of(context);
    final names = s.bible.namesIn(ref.book, ref.chapter, ref.verse);
    if (names.isEmpty) return Text('Nenhuma pessoa ou lugar citado neste versículo.', style: TextStyle(color: c.muted));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final n in names)
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => openName(context, n.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 10),
                child: Icon(n.group == 'lugar' ? Icons.place_outlined : Icons.person_outline, size: 20, color: c.muted),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                  if (n.summary.isNotEmpty)
                    Text(n.summary, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5, height: 1.35, color: c.muted)),
                ]),
              ),
            ]),
          ),
        ),
    ]);
  }
}

void openName(BuildContext context, int id) {
  final s = AppScope.read(context);
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => AppScope(state: s, child: NamePage(id: id))));
}

/// Ficha de uma pessoa ou lugar: resumo, família, artigo e onde aparece.
class NamePage extends StatefulWidget {
  final int id;
  const NamePage({super.key, required this.id});

  @override
  State<NamePage> createState() => _NamePageState();
}

class _NamePageState extends State<NamePage> {
  static const _firstRefs = 30;
  bool _allRefs = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = ReaderColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final n = s.bible.name(widget.id);
    if (n == null) return Scaffold(appBar: AppBar());
    final refs = s.bible.nameRefs(n.id);
    final shownRefs = _allRefs ? refs : refs.take(_firstRefs).toList();
    final family = [
      ('Pais', n.parents),
      ('Irmãos', n.siblings),
      ('Cônjuges', n.partners),
      ('Filhos', n.children),
    ].where((f) => f.$2.isNotEmpty);

    Widget label(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 6),
          child: Text(t.toUpperCase(),
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.9, color: c.muted)),
        );
    Widget english() => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Ainda em inglês, a tradução está em andamento.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: c.muted)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(n.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Text(kindLabel(n), style: TextStyle(fontSize: 13, color: c.muted)),
          if (n.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(n.summary, style: const TextStyle(fontFamily: serif, fontSize: 17, height: 1.5)),
            if (n.summaryInEnglish) english(),
          ],
          for (final (title, ids) in family) ...[
            label(title),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final id in ids)
                if (s.bible.name(id) case final m?)
                  ActionChip(label: Text(m.name), onPressed: () => openName(context, m.id)),
            ]),
          ],
          if (n.article.isNotEmpty) ...[
            label('Contexto'),
            for (final p in n.article.split('\n'))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(p, style: TextStyle(fontFamily: serif, fontSize: 15.5, height: 1.5, color: scheme.onSurface)),
              ),
            if (n.articleInEnglish) english(),
          ],
          label(refs.length == 1 ? 'Aparece em 1 versículo' : 'Aparece em ${refs.length} versículos'),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final (b, ch, v) in shownRefs)
              ActionChip(
                label: Text('${s.bible.book(b).name} $ch:$v'),
                visualDensity: VisualDensity.compact,
                onPressed: () => openRef(context, Ref(b, ch, v)),
              ),
          ]),
          if (refs.length > _firstRefs)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _allRefs = !_allRefs),
                child: Text(_allRefs ? 'Mostrar menos' : 'Ver todos'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Notas de estudo do versículo, cada uma com o trecho a que se refere; as longas começam recolhidas.
class StudyNotes extends StatelessWidget {
  final List<StudyNote> notes;
  const StudyNotes({super.key, required this.notes});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final n in notes)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: scheme.primary)),
            const SizedBox(height: 2),
            _NoteText(html: n.html),
          ]),
        ),
    ]);
  }
}

class _NoteText extends StatefulWidget {
  final String html;
  const _NoteText({required this.html});

  @override
  State<_NoteText> createState() => _NoteTextState();
}

class _NoteTextState extends State<_NoteText> {
  static const _limit = 420;
  final _taps = <TapGestureRecognizer>[];
  // trechos de texto (List<InlineSpan>) e imagens (id) na ordem em que aparecem na nota
  List<Object> _parts = const [];
  int _length = 0;
  bool _open = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _build();
  }

  @override
  void didUpdateWidget(_NoteText old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html) _build();
  }

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  static String _entities(String t) => t
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&');

  /// Converte o HTML simples da nota em texto e imagens; links `#bLIVRO.CAP.VER` abrem o versículo.
  void _build() {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    final scheme = Theme.of(context).colorScheme;
    final parts = <Object>[];
    var spans = <InlineSpan>[];
    var bold = 0, italic = 0, under = 0, length = 0;
    Ref? link;
    void flush() {
      if (spans.isNotEmpty) parts.add(spans);
      spans = <InlineSpan>[];
    }

    void text(String t) {
      if (t.isEmpty) return;
      length += t.length;
      TapGestureRecognizer? tap;
      final target = link;
      if (target != null) {
        tap = TapGestureRecognizer()..onTap = () => openRef(context, target);
        _taps.add(tap);
      }
      spans.add(TextSpan(
        text: t,
        recognizer: tap,
        style: TextStyle(
          fontWeight: bold > 0 ? FontWeight.w700 : null,
          fontStyle: italic > 0 ? FontStyle.italic : null,
          decoration: under > 0 || target != null ? TextDecoration.underline : null,
          color: target != null ? scheme.primary : null,
        ),
      ));
    }

    for (final m in RegExp(r'<(/?)(\w+)([^>]*)>|([^<]+)').allMatches(widget.html)) {
      if (m[4] != null) {
        text(_entities(m[4]!));
        continue;
      }
      final close = m[1] == '/', tag = m[2]!.toLowerCase();
      switch (tag) {
        case 'strong' || 'b':
          bold += close ? -1 : 1;
        case 'em' || 'i':
          italic += close ? -1 : 1;
        case 'u':
          under += close ? -1 : 1;
        case 'br':
          text('\n');
        case 'p':
          if (!close && spans.isNotEmpty) text('\n');
        case 'img':
          final id = RegExp(r"src='(\d+)'").firstMatch(m[3] ?? '');
          if (id != null) {
            flush();
            parts.add(int.parse(id[1]!));
          }
        case 'a':
          if (close) {
            link = null;
          } else {
            final h = RegExp(r'#b(\d+)\.(\d+)\.(\d+)').firstMatch(m[3] ?? '');
            link = h == null ? null : Ref(int.parse(h[1]!), int.parse(h[2]!), int.parse(h[3]!) == 0 ? 1 : int.parse(h[3]!));
          }
      }
    }
    flush();
    _parts = parts;
    _length = length;
  }

  @override
  Widget build(BuildContext context) {
    final long = _length > _limit;
    final collapsed = long && !_open;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final p in _parts)
        if (p is int)
          _NoteImage(id: p)
        else
          Text.rich(
            TextSpan(children: p as List<InlineSpan>),
            maxLines: collapsed ? 6 : null,
            overflow: collapsed ? TextOverflow.ellipsis : TextOverflow.clip,
            style: const TextStyle(fontFamily: serif, fontSize: 15.5, height: 1.45),
          ),
      if (long)
        TextButton(
          onPressed: () => setState(() => _open = !_open),
          child: Text(_open ? 'Mostrar menos' : 'Ler nota completa'),
        ),
    ]);
  }
}

/// Mapa ou quadro de uma nota; toque para ampliar e aproximar com os dedos.
class _NoteImage extends StatelessWidget {
  final int id;
  const _NoteImage({required this.id});

  @override
  Widget build(BuildContext context) {
    final bytes = AppScope.read(context).bible.noteImage(id);
    if (bytes == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => Dialog.fullscreen(
            child: Stack(children: [
              InteractiveViewer(maxScale: 6, child: Center(child: Image.memory(bytes, fit: BoxFit.contain))),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ]),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380),
          child: Image.memory(bytes, fit: BoxFit.contain, alignment: Alignment.centerLeft, gaplessPlayback: true),
        ),
      ),
    );
  }
}
