import 'package:flutter/material.dart';

import '../data/bible_db.dart';
import '../data/refs.dart';
import '../data/user_db.dart';
import '../state.dart';
import '../theme.dart';
import 'confirm.dart';
import 'page_menu.dart';
import 'picker.dart';
import 'settings.dart';

/// Sumário: os 66 livros; tocar num livro abre a lista de capítulos.
class ContentsView extends StatefulWidget {
  const ContentsView({super.key});

  @override
  State<ContentsView> createState() => _ContentsViewState();
}

class _ContentsViewState extends State<ContentsView> {
  final _q = TextEditingController();
  int? _open; // livro com os capítulos abertos: só um por vez

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final muted = ReaderColors.of(context).muted;
    final q = fold(_q.text.trim());
    bool match(Book b) => q.isEmpty || fold(b.name).contains(q);
    return Scaffold(
      appBar: AppBar(
        leading: const PageMenuButton(),
        centerTitle: true,
        title: const Text('Sumário'),
        actions: [
          if (s.flag(Opt.lidos))
            Center(
                child: Text(
                    '${s.user.readCount()}/${s.bible.chapterIndex.length} lidos · ${percent(s.user.readCount(), s.bible.chapterIndex.length)}',
                    style: TextStyle(fontSize: 12.5, color: muted))),
          const SettingsButton(),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: TextField(
                  controller: _q,
                  textAlign: TextAlign.center,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar livro',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _q.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(_q.clear),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              for (final t in ['AT', 'NT'])
                if (s.bible.books.any((b) => b.testament == t && match(b))) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                  child: Text(t == 'AT' ? 'ANTIGO TESTAMENTO' : 'NOVO TESTAMENTO',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, letterSpacing: 0.8, color: muted, fontWeight: FontWeight.w600)),
                ),
                for (final b in s.bible.books.where((b) => b.testament == t && match(b)))
                  BookTile(
                    key: PageStorageKey('sumario-${b.id}'),
                    book: b,
                    expanded: _open == b.id,
                    onExpansion: (v) => setState(() {
                      if (v) {
                        _open = b.id;
                      } else if (_open == b.id) {
                        _open = null;
                      }
                    }),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Percentual inteiro (arredondado para baixo, para só chegar a 100% quando completo).
String percent(int part, int whole) => '${whole == 0 ? 0 : part * 100 ~/ whole}%';

/// Um livro que se abre mostrando seus capítulos (usado no sumário e na busca).
/// Com [expanded] definido, o pai controla a abertura (acordeão): fechar quando vira false.
class BookTile extends StatefulWidget {
  final Book book;
  final bool initiallyExpanded;
  final bool? expanded;
  final ValueChanged<bool>? onExpansion;
  const BookTile({super.key, required this.book, this.initiallyExpanded = false, this.expanded, this.onExpansion});

  @override
  State<BookTile> createState() => _BookTileState();
}

class _BookTileState extends State<BookTile> {
  final _ctrl = ExpansibleController();

  @override
  void initState() {
    super.initState();
    _closeIfNotOpen(); // o PageStorage pode restaurar aberto um livro que o pai já fechou
  }

  @override
  void didUpdateWidget(BookTile old) {
    super.didUpdateWidget(old);
    if (old.expanded != false) _closeIfNotOpen();
  }

  void _closeIfNotOpen() {
    if (widget.expanded != false) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _ctrl.isExpanded) _ctrl.collapse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final s = AppScope.of(context);
    final muted = ReaderColors.of(context).muted;
    final isCurrent = s.current.$1 == book.id;
    final read = s.flag(Opt.lidos) ? s.user.readChapters(book.id).length : 0;
    final total = book.chapters == 1 ? '1 capítulo' : '${book.chapters} capítulos';
    return ExpansionTile(
      controller: _ctrl,
      initiallyExpanded: widget.initiallyExpanded,
      onExpansionChanged: widget.onExpansion,
      shape: const Border(),
      collapsedShape: const Border(),
      title: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Flexible(
          child: Text(book.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: serif,
                  fontSize: 18,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                  color: isCurrent ? Theme.of(context).colorScheme.primary : null)),
        ),
        if (s.resumeAt?.book == book.id)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Icon(Icons.bookmark_added, size: 16, color: ReaderColors.of(context).mark),
          ),
        const SizedBox(width: 10),
        Text(read > 0 ? '$total · $read ${read == 1 ? 'lido' : 'lidos'} · ${percent(read, book.chapters)}' : total,
            style: TextStyle(fontSize: 12.5, color: read == book.chapters ? ReaderColors.of(context).read : muted)),
      ]),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      children: [
        ChapterGrid(book: book),
        if (read > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final ok = await confirm(context,
                    title: 'Limpar lidos de ${book.name}?',
                    message: 'Remove a marca de "lido" dos $read capítulos lidos de ${book.name}. Não dá para desfazer.',
                    action: 'Limpar');
                if (ok) s.user.clearRead(book: book.id);
              },
              icon: const Icon(Icons.layers_clear, size: 18),
              label: Text('Limpar lidos de ${book.name}'),
            ),
          ),
      ],
    );
  }
}

/// Grade com os capítulos de um livro; tocar abre o capítulo no leitor.
class ChapterGrid extends StatelessWidget {
  final Book book;
  final VoidCallback? onPicked;
  const ChapterGrid({super.key, required this.book, this.onPicked});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final readSet = s.flag(Opt.lidos) ? s.user.readChapters(book.id) : const <int>{};
    final resumeAt = s.resumeAt;
    return LayoutBuilder(builder: (context, box) {
      const gap = 8.0;
      final cols = ((box.maxWidth + gap) / (52 + gap)).floor().clamp(1, 12);
      final side = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (var c = 1; c <= book.chapters; c++)
          SizedBox(
            width: side,
            height: side.clamp(0, 52),
            child: ChapterButton(
              n: c,
              read: readSet.contains(c),
              resume: resumeAt != null && resumeAt.book == book.id && resumeAt.chapter == c,
              current: s.current.$1 == book.id && s.current.$2 == c,
              onTap: () {
                onPicked?.call();
                s.goTo(Ref(book.id, c, 1), select: false);
              },
            ),
          ),
      ]);
    });
  }
}
