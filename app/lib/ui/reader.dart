import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/speech.dart';
import '../data/user_db.dart';
import '../state.dart';
import '../theme.dart';
import 'page_menu.dart';
import 'settings.dart';

/// Leitura: um capítulo inteiro por página; deslizar para o lado troca de capítulo.
class ReaderView extends StatefulWidget {
  const ReaderView({super.key});

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  late PageController _pages;
  late AppState _state;
  final _pointers = <int, Offset>{};
  double _startDist = 0, _startScale = 1;
  bool _pinching = false;

  @override
  void initState() {
    super.initState();
    _state = AppScope.read(context);
    _pages = PageController(initialPage: _state.chapterPos);
    _state.addListener(_sync);
  }

  void _sync() {
    if (_pages.hasClients && _pages.page?.round() != _state.chapterPos) {
      _pages.jumpToPage(_state.chapterPos);
    }
  }

  @override
  void dispose() {
    _state.removeListener(_sync);
    _pages.dispose();
    super.dispose();
  }

  double get _dist => (_pointers.values.first - _pointers.values.elementAt(1)).distance;

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2 && _state.pinchZoom) {
      _startDist = _dist;
      _startScale = _state.fontScale;
      setState(() => _pinching = true);
    }
  }

  void _move(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    if (_pinching && _pointers.length >= 2 && _startDist > 0) {
      _state.setFontScale(_startScale * _dist / _startDist, save: false);
    }
  }

  void _up(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pinching && _pointers.length < 2) {
      _state.saveFontScale();
      setState(() => _pinching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const PageMenuButton(),
        centerTitle: true,
        title: _VersionMenu(),
        actions: [
          const SettingsButton(),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
      ),
      body: Listener(
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: PageView.builder(
          controller: _pages,
          physics: _pinching ? const NeverScrollableScrollPhysics() : null,
          itemCount: s.bible.chapterIndex.length,
          onPageChanged: (i) {
            s.setChapterPos(i, notify: false);
            s.select(null);
          },
          itemBuilder: (_, i) => ChapterPage(pos: i, locked: _pinching),
        ),
      ),
    );
  }
}

class _VersionMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final v = s.bible.version(s.version);
    return PopupMenuButton<String>(
      tooltip: 'Versão',
      initialValue: s.version,
      onSelected: s.setVersion,
      itemBuilder: (_) => [
        for (final x in s.bible.versions)
          PopupMenuItem(value: x.id, child: Text(x.name)),
      ],
      child: Padding(
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: 104,
          child: Chip(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            label: FittedBox(fit: BoxFit.scaleDown, child: Text(v.abbr)),
          ),
        ),
      ),
    );
  }
}

class ChapterPage extends StatefulWidget {
  final int pos;
  final bool locked; // pinça em andamento: não rola
  const ChapterPage({super.key, required this.pos, this.locked = false});

  @override
  State<ChapterPage> createState() => _ChapterPageState();
}

class _ChapterPageState extends State<ChapterPage> {
  final _keys = <int, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final (book, ch) = s.bible.chapterIndex[widget.pos];
    final verses = s.bible.chapter(s.version, book, ch);
    final speech = s.showSpeech ? s.bible.speech(book, ch) : const <int, List<Speech>>{};
    final useQuotes = s.bible.quotedVersions.contains(s.version);
    var quoteDepth = 0;
    final marks = s.flag(Opt.marcadores) ? s.user.bookmarkedVerses(book, ch) : const <int>{};
    final notes = s.flag(Opt.anotacoes) ? s.user.notedVerses(book, ch) : const <int>{};
    final resume = s.resumeAt;
    final colors = ReaderColors.of(context);
    final theme = Theme.of(context);
    final size = 19.0 * s.fontScale;
    final b = s.bible.book(book);

    if (s.scrollToVerse != null && s.chapterPos == widget.pos) {
      final v = s.scrollToVerse!;
      s.scrollToVerse = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[v]?.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.3, duration: const Duration(milliseconds: 250));
      });
    }

    return SingleChildScrollView(
      key: PageStorageKey('ch-${widget.pos}'),
      physics: widget.locked ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text('${b.name} $ch',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: serif, fontSize: 30, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
              ),
              if (s.flag(Opt.contagem)) ...[
                const SizedBox(height: 2),
                Center(
                  child: Text('${verses.length} VERSÍCULOS',
                      style: TextStyle(fontSize: 11.5, letterSpacing: 0.8, color: colors.muted)),
                ),
              ],
              const SizedBox(height: 16),
              if (verses.isEmpty)
                Text('Esta versão não tem este capítulo. Escolha outra versão no topo.',
                    style: TextStyle(color: colors.muted)),
              for (final v in verses)
                _VerseTile(
                  key: _keys.putIfAbsent(v.verse, GlobalKey.new),
                  number: v.verse,
                  text: v.text,
                  speech: () {
                    final r = speechRanges(v.text, speech[v.verse] ?? const [],
                        useQuotes: useQuotes, quoteDepth: quoteDepth);
                    quoteDepth = r.depth;
                    return r.ranges;
                  }(),
                  size: size,
                  marked: marks.contains(v.verse),
                  noted: notes.contains(v.verse),
                  selected: s.selected == Ref(book, ch, v.verse),
                  resume: resume == Ref(book, ch, v.verse),
                  onLongPress: !s.useResume
                      ? null
                      : () {
                    final r = Ref(book, ch, v.verse);
                    final was = resume == r;
                    if (s.flag(Opt.vibracao)) HapticFeedback.mediumImpact();
                    s.toggleResume(r);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                          duration: const Duration(seconds: 2),
                          content: Text(was ? 'Ponto de leitura removido.' : 'Ponto de leitura: ${s.refLabel(r)}')));
                  },
                  onTap: s.tapVerse ? () => s.select(Ref(book, ch, v.verse)) : null,
                ),
              const SizedBox(height: 24),
              const Divider(),
              if (s.flag(Opt.lidos) || s.flag(Opt.navCapitulo)) ...[
                const SizedBox(height: 12),
                // anterior, lido e próximo na mesma linha, com a mesma altura
                Row(children: [
                  Expanded(
                    child: s.flag(Opt.navCapitulo) && widget.pos > 0
                        ? Tooltip(
                            message: _title(s, widget.pos - 1),
                            child: OutlinedButton.icon(
                              style: _barButton,
                              onPressed: () => s.setChapterPos(widget.pos - 1),
                              icon: const Icon(Icons.chevron_left),
                              label: const Text('Anterior'),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: !s.flag(Opt.lidos)
                        ? const SizedBox.shrink()
                        : s.user.isRead(book, ch)
                            ? FilledButton.tonalIcon(
                                style: _barButton,
                                onPressed: () => s.user.toggleRead(book, ch),
                                icon: Icon(Icons.check_circle, color: colors.read),
                                label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Lido')),
                              )
                            : FilledButton.icon(
                                style: _barButton,
                                onPressed: () => s.user.toggleRead(book, ch),
                                icon: const Icon(Icons.check),
                                label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Marcar lido')),
                              ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: s.flag(Opt.navCapitulo) && widget.pos < s.bible.chapterIndex.length - 1
                        ? Tooltip(
                            message: _title(s, widget.pos + 1),
                            child: OutlinedButton.icon(
                              style: _barButton,
                              onPressed: () => s.setChapterPos(widget.pos + 1),
                              iconAlignment: IconAlignment.end,
                              icon: const Icon(Icons.chevron_right),
                              label: const Text('Próximo'),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static final _barButton = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
  );

  String _title(AppState s, int pos) {
    final (b, c) = s.bible.chapterIndex[pos];
    return '${s.bible.book(b).name} $c';
  }
}

class _VerseTile extends StatelessWidget {
  List<TextSpan> _textSpans(ReaderColors c) {
    if (speech.isEmpty) return [TextSpan(text: text)];
    final out = <TextSpan>[];
    var at = 0;
    for (final r in speech) {
      if (r.start > at) out.add(TextSpan(text: text.substring(at, r.start)));
      out.add(TextSpan(
          text: text.substring(r.start, r.end), style: TextStyle(color: r.who == Speaker.god ? c.god : c.jesus)));
      at = r.end;
    }
    if (at < text.length) out.add(TextSpan(text: text.substring(at)));
    return out;
  }

  final int number;
  final String text;
  final List<SpeechRange> speech;
  final double size;
  final bool marked, noted, selected, resume;
  final VoidCallback? onTap, onLongPress;
  const _VerseTile(
      {super.key,
      required this.number,
      required this.text,
      required this.speech,
      required this.size,
      required this.marked,
      required this.noted,
      required this.selected,
      required this.resume,
      required this.onLongPress,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = ReaderColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? c.accentSoft : (marked ? c.markSoft : Colors.transparent),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            decoration: selected
                ? BoxDecoration(border: Border(left: BorderSide(color: scheme.primary, width: 3)))
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text.rich(
              TextSpan(children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.top,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text('$number',
                        style: TextStyle(fontSize: size * 0.6, fontWeight: FontWeight.w600, color: scheme.primary)),
                  ),
                ),
                ..._textSpans(c),
                if (resume)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(Icons.bookmark_added, size: size * 0.8, color: c.mark),
                    ),
                  ),
                if (marked) TextSpan(text: '  🔖', style: TextStyle(fontSize: size * 0.7)),
                if (noted) TextSpan(text: '  📝', style: TextStyle(fontSize: size * 0.7)),
              ]),
              style: TextStyle(fontFamily: serif, fontSize: size, height: 1.65, color: scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}
