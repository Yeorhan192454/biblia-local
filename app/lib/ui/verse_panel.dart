import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data/bible_db.dart';
import '../data/user_db.dart';
import '../state.dart';
import '../theme.dart';
import 'study.dart';

/// Painel do versículo: marcar, anotar, comparar versões, vínculos, pessoas e lugares e o original palavra por palavra.
class VersePanel extends StatefulWidget {
  final Ref ref;
  final VoidCallback? onClose;
  final ScrollController? scroll;

  /// Página inteira (celular): deixa espaço à esquerda do título para o botão flutuante de voltar.
  final bool fullPage;
  const VersePanel({super.key, required this.ref, this.onClose, this.scroll, this.fullPage = false});

  @override
  State<VersePanel> createState() => _VersePanelState();
}

class _VersePanelState extends State<VersePanel> {
  int? _word;
  bool _editing = false;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: AppScope.read(context).user.note(widget.ref) ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final r = widget.ref;
    final c = ReaderColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final marked = s.user.isBookmarked(r);
    final note = s.flag(Opt.anotacoes) ? s.user.note(r) : null;
    final edition = s.activeEdition;
    final notes = s.flag(Opt.notasEstudo) ? s.bible.studyNotes(r.book, r.chapter, r.verse) : const <StudyNote>[];
    final all = s.bible.words(r.book, r.chapter, r.verse);
    final isNT = r.book >= 40;
    final words = isNT ? all.where((w) => edition == Edition.tr ? w.inTR() : w.inCritical()).toList() : all;
    final word = _word == null || _word! >= words.length ? null : words[_word!];

    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        Row(children: [
          if (widget.fullPage) const SizedBox(width: 48),
          Expanded(
            child: Text(s.refLabel(r), style: const TextStyle(fontFamily: serif, fontSize: 21, fontWeight: FontWeight.w700)),
          ),
          if (widget.onClose != null)
            IconButton(tooltip: 'Fechar', onPressed: widget.onClose, icon: const Icon(Icons.close)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          if (s.flag(Opt.resumo))
          ActionChip(
            avatar: const Icon(Icons.auto_stories_outlined, size: 18),
            label: const Text('Resumo'),
            // o diálogo é outra rota, fora do AppScope: repassa o estado
            onPressed: () => showDialog<void>(
                context: context, builder: (_) => AppScope(state: s, child: _ResumoDialog(ref: r))),
          ),
          if (s.flag(Opt.marcadores))
          FilterChip(
            selected: marked,
            showCheckmark: false,
            avatar: Icon(marked ? Icons.bookmark : Icons.bookmark_border, size: 18, color: marked ? c.mark : null),
            label: Text(marked ? 'Marcado' : 'Marcar'),
            onSelected: (_) => s.user.toggleBookmark(r),
            selectedColor: c.markSoft,
          ),
          if (s.flag(Opt.anotacoes))
          FilterChip(
            selected: note != null,
            showCheckmark: false,
            avatar: Icon(Icons.edit_note, size: 18, color: note != null ? c.mark : null),
            label: Text(note != null ? 'Anotação' : 'Anotar'),
            onSelected: (_) => setState(() => _editing = true),
            selectedColor: c.markSoft,
          ),
          if (s.flag(Opt.copiar))
          ActionChip(
            avatar: const Icon(Icons.share, size: 18),
            label: const Text('Compartilhar'),
            onPressed: () async {
              final text = s.bible.verseText(s.version, r.book, r.chapter, r.verse) ??
                  s.bible.compare(r.book, r.chapter, r.verse).firstOrNull?.$2 ??
                  '';
              final m = ScaffoldMessenger.of(context);
              final msg = '${s.refLabel(r)} $text';
              final box = context.findRenderObject() as RenderBox?;
              var shared = false;
              try {
                final res = await SharePlus.instance.share(ShareParams(
                  text: msg,
                  sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
                ));
                shared = res.status != ShareResultStatus.unavailable;
              } catch (_) {}
              if (shared) return;
              // Sem compartilhamento no aparelho/navegador: copia para a área de transferência.
              await Clipboard.setData(ClipboardData(text: msg));
              m
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Versículo copiado.'), duration: Duration(seconds: 2)));
            },
          ),
        ]),
        if (s.flag(Opt.anotacoes) && (_editing || note != null)) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            autofocus: _editing && note == null,
            minLines: 2,
            maxLines: 8,
            decoration: const InputDecoration(labelText: 'Sua anotação', border: OutlineInputBorder()),
            onChanged: (t) => s.user.setNote(r, t),
          ),
        ],
        // Seções recolhíveis: abrir uma fecha a que estava aberta (estado em AppState.openSection).
        if (s.showCompare)
          _Section(id: 'compare', title: 'Comparar versões', children: [
            for (final (v, text) in s.bible.compare(r.book, r.chapter, r.verse))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '${v.abbr}  ',
                        style: TextStyle(
                            fontFamily: null,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                            letterSpacing: 0.5)),
                    TextSpan(text: text),
                  ]),
                  style: TextStyle(
                      fontFamily: serif,
                      fontSize: 16.5,
                      height: 1.5,
                      fontWeight: v.id == s.version ? FontWeight.w700 : FontWeight.w400),
                ),
              ),
          ]),
        if (notes.isNotEmpty) _Section(id: 'notes', title: s.bible.studyNotesSource.isEmpty ? 'Notas de estudo' : 'Notas de estudo (${s.bible.studyNotesSource})', children: [StudyNotes(notes: notes)]),
        if (s.showCrossRefs) _Section(id: 'links', title: 'Vínculos', children: [CrossRefList(ref: r)]),
        if (s.showNames) _Section(id: 'names', title: 'Pessoas e lugares', children: [NamesInVerse(ref: r)]),
        if (s.showOriginal)
          _Section(
            id: 'original',
            title: isNT ? 'Grego' : 'Hebraico',
            children: [
              if (isNT && s.flag(Opt.edicao))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SegmentedButton<Edition>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    segments: const [
                      ButtonSegment(value: Edition.tr, label: Text('Textus Receptus')),
                      ButtonSegment(value: Edition.critical, label: Text('Crítico')),
                    ],
                    selected: {s.edition},
                    onSelectionChanged: (e) => setState(() {
                      _word = null;
                      s.setEdition(e.first);
                    }),
                  ),
                ),
              if (words.isEmpty)
                Text('Sem texto original para este versículo.', style: TextStyle(color: c.muted))
              else ...[
                Text('Toque numa palavra para ver a explicação.', style: TextStyle(fontSize: 12.5, color: c.muted)),
                const SizedBox(height: 6),
                Directionality(
                  textDirection: isNT ? TextDirection.ltr : TextDirection.rtl,
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (var i = 0; i < words.length; i++)
                      _WordChip(
                        word: words[i],
                        selected: _word == i,
                        variant: isNT && s.flag(Opt.edicao) && !(words[i].inTR() && words[i].inCritical()),
                        onTap: () => setState(() => _word = _word == i ? null : i),
                      ),
                  ]),
                ),
                if (isNT && s.flag(Opt.edicao) && words.any((w) => !(w.inTR() && w.inCritical())))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Sublinhado laranja: palavra que aparece só nesta edição.',
                        style: TextStyle(fontSize: 12, color: c.mark)),
                  ),
                if (word != null) _WordCard(word: word, isNT: isNT && s.flag(Opt.edicao)),
              ],
            ],
          ),
      ],
    );
  }
}

/// Seção recolhível do painel: o título é o botão de mostrar/esconder; só uma fica aberta por vez.
class _Section extends StatelessWidget {
  final String id, title;
  final List<Widget> children;
  const _Section({required this.id, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final muted = ReaderColors.of(context).muted;
    return ValueListenableBuilder<String?>(
      valueListenable: s.openSection,
      builder: (context, current, _) {
        final open = current == id;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 6),
          const Divider(height: 1),
          InkWell(
            onTap: () => s.toggleSection(id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                Expanded(
                  child: Text(title.toUpperCase(),
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.9, color: muted)),
                ),
                Icon(open ? Icons.expand_less : Icons.expand_more, size: 20, color: muted),
              ]),
            ),
          ),
          if (open) ...children,
        ]);
      },
    );
  }
}

/// Popup do resumo: escolhe entre o resumo do livro e o do capítulo do versículo.
class _ResumoDialog extends StatefulWidget {
  final Ref ref;
  const _ResumoDialog({required this.ref});

  @override
  State<_ResumoDialog> createState() => _ResumoDialogState();
}

class _ResumoDialogState extends State<_ResumoDialog> {
  bool _book = true;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = ReaderColors.of(context);
    final r = widget.ref;
    final bookName = s.bible.books.firstWhere((b) => b.id == r.book).name;
    final text = s.bible.intro(r.book, _book ? 0 : r.chapter);
    return AlertDialog(
      title: Text(_book ? bookName : '$bookName ${r.chapter}', style: const TextStyle(fontFamily: serif)),
      content: SizedBox(
        width: 560,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: true, label: Text('Resumo do livro')),
              ButtonSegment(value: false, label: Text('Resumo do capítulo')),
            ],
            selected: {_book},
            onSelectionChanged: (v) => setState(() => _book = v.first),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: text == null
                  ? Text('Este ${_book ? 'livro' : 'capítulo'} não tem resumo.', style: TextStyle(color: c.muted))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      for (final p in text.split('\n').where((p) => p.trim().isNotEmpty))
                        Padding(padding: const EdgeInsets.only(bottom: 10), child: _paragraph(p)),
                    ]),
            ),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
    );
  }

  /// Parágrafo com rótulo inicial em negrito ("Autoria e data: ...").
  static Widget _paragraph(String p) {
    final m = RegExp(r'^([A-ZÀ-Ú][^:]{2,30}): ').firstMatch(p);
    const style = TextStyle(fontFamily: serif, fontSize: 16, height: 1.5);
    if (m == null) return Text(p, style: style);
    return Text.rich(TextSpan(children: [
      TextSpan(text: '${m[1]}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
      TextSpan(text: p.substring(m.end)),
    ]), style: style);
  }
}

class _WordChip extends StatelessWidget {
  final Word word;
  final bool selected, variant;
  final VoidCallback onTap;
  const _WordChip({required this.word, required this.selected, required this.variant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = ReaderColors.of(context);
    return Material(
      color: selected ? scheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: selected ? Colors.transparent : (variant ? c.mark : c.muted), width: variant ? 2 : 1)),
          ),
          child: Text(word.text.replaceAll('¶', '').trim(),
              style: TextStyle(
                  fontFamily: word.isHebrew ? hebrew : serif,
                  fontSize: word.isHebrew ? 22 : 19,
                  color: selected ? scheme.onPrimary : scheme.onSurface)),
        ),
      ),
    );
  }
}

class _WordCard extends StatefulWidget {
  final Word word;
  final bool isNT;
  const _WordCard({required this.word, required this.isNT});

  @override
  State<_WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<_WordCard> {
  bool _full = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final w = widget.word;
    final c = ReaderColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final lex = s.bible.lex(w.strong);
    final count = s.bible.occurrences(w.strong);
    final strongNum = w.strong
        .replaceFirstMapped(RegExp(r'^([HG])0*'), (m) => m[1]!)
        .replaceAll(RegExp(r'[A-Z]$'), '');
    // Tudo em português; o inglês da STEPBible só aparece, marcado, onde a tradução ainda não chegou.
    final defPt = lex?.defPt ?? '';
    final def = defPt.isNotEmpty ? defPt : lex?.defEn ?? '';
    final defInEnglish = defPt.isEmpty && def.isNotEmpty;
    final here = w.glossPt.isNotEmpty ? w.glossPt : w.gloss;
    final short = def.length > 420 && !_full;
    final details = s.flag(Opt.detalhesPalavra);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
          Text(w.text.replaceAll('¶', '').trim(), style: TextStyle(fontFamily: w.isHebrew ? hebrew : serif, fontSize: 26)),
          if (lex != null && lex.lemma.isNotEmpty)
            Text('← ${lex.lemma}',
                style: TextStyle(fontFamily: w.isHebrew ? hebrew : serif, fontSize: 17, color: c.muted)),
        ]),
        const SizedBox(height: 4),
        Text(
          [
            w.translit,
            if (details) ...[
              if (lex != null && lex.translit.isNotEmpty && lex.translit != w.translit) 'forma básica: ${lex.translit}',
              'Strong $strongNum',
              '$count ocorrências',
            ],
          ]
              .join(' · '),
          style: TextStyle(fontSize: 12.5, color: c.muted),
        ),
        if (details) ...[
          const SizedBox(height: 2),
          Text(s.bible.morphPt(w.morph), style: TextStyle(fontSize: 12.5, color: c.muted)),
        ],
        const SizedBox(height: 10),
        Text.rich(TextSpan(children: [
          if (lex != null && lex.glossPt.isNotEmpty)
            TextSpan(text: lex.glossPt, style: const TextStyle(fontWeight: FontWeight.w700))
          else if (lex != null && lex.glossEn.isNotEmpty) ...[
            TextSpan(text: lex.glossEn, style: const TextStyle(fontWeight: FontWeight.w700, fontStyle: FontStyle.italic)),
            TextSpan(text: '  (em inglês, tradução em andamento)', style: TextStyle(fontSize: 12.5, color: c.muted)),
          ] else
            const TextSpan(text: 'Significado em português em preparação', style: TextStyle(fontStyle: FontStyle.italic)),
        ]), style: const TextStyle(fontSize: 16)),
        if (widget.isNT && !w.inCritical())
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Esta palavra está no Textus Receptus, mas não na edição crítica (Nestle-Aland/SBL).',
                style: TextStyle(fontSize: 12.5, color: c.mark)),
          ),
        if (widget.isNT && !w.inTR())
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Esta palavra está na edição crítica, mas não no Textus Receptus.',
                style: TextStyle(fontSize: 12.5, color: c.mark)),
          ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 10),
        Text('NESTE VERSÍCULO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.9, color: c.muted)),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: here, style: const TextStyle(fontStyle: FontStyle.italic)),
            if (w.glossPt.isEmpty && here.isNotEmpty) const TextSpan(text: '  (em inglês, tradução em andamento)'),
          ]),
          style: TextStyle(fontSize: 13.5, color: c.muted),
        ),
        if (details && def.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('VERBETE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.9, color: c.muted)),
          if (defInEnglish)
            Text('Ainda em inglês, a tradução está em andamento.', style: TextStyle(fontSize: 12.5, color: c.muted)),
          const SizedBox(height: 4),
          Text(short ? '${def.substring(0, 420)}…' : def,
              style: TextStyle(fontFamily: serif, fontSize: 14.5, height: 1.45, color: scheme.onSurface)),
          if (def.length > 420)
            TextButton(
                onPressed: () => setState(() => _full = !_full),
                child: Text(_full ? 'Mostrar menos' : 'Ler verbete completo')),
        ],
      ]),
    );
  }
}
