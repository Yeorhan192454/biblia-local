import 'package:flutter/material.dart';

import '../data/bible_db.dart';
import '../data/refs.dart';
import '../data/user_db.dart';
import '../state.dart';
import '../theme.dart';

Future<void> showChapterPicker(BuildContext context) {
  final s = AppScope.read(context);
  return showDialog(
    context: context,
    builder: (_) => AppScope(state: s, child: const _Picker()),
  );
}

class _Picker extends StatefulWidget {
  const _Picker();

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  Book? _book;
  final _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  /// Livros que combinam com o que foi digitado (todos quando o campo está vazio).
  List<Book> _visible(List<Book> books) {
    final q = _filter.text.trim();
    if (q.isEmpty) return books;
    final refs = parseRef(books, q).map((r) => r.book).toSet();
    final f = fold(q);
    return [for (final b in books) if (refs.contains(b) || fold(b.name).contains(f)) b];
  }

  void _submit(AppState s) {
    final refs = parseRef(s.bible.books, _filter.text);
    if (refs.isEmpty) return;
    final r = refs.first;
    if (r.chapter != null) {
      Navigator.pop(context);
      s.goTo(Ref(r.book.id, r.chapter!, r.verse ?? 1), select: r.verse != null);
    } else if (r.book.chapters == 1) {
      _go(s, r.book, 1);
    } else {
      setState(() => _book = r.book);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final muted = ReaderColors.of(context).muted;
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: size.height * 0.85),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (_book != null)
                  IconButton(onPressed: () => setState(() => _book = null), icon: const Icon(Icons.arrow_back)),
                Expanded(
                  child: Text(_book?.name ?? 'Escolha o livro',
                      style: const TextStyle(fontFamily: serif, fontSize: 22, fontWeight: FontWeight.w700)),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: 8),
              if (_book == null)
                TextField(
                  controller: _filter,
                  autofocus: MediaQuery.sizeOf(context).width >= 900,
                  textInputAction: TextInputAction.go,
                  decoration: const InputDecoration(
                    hintText: 'Livro ou referência, ex.: jo 3 16',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(s),
                ),
              Flexible(
                child: _book == null
                    ? ListView(
                        shrinkWrap: true,
                        children: [
                          for (final t in ['AT', 'NT'])
                            if (_visible(s.bible.books).any((b) => b.testament == t)) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                              child: Text(t == 'AT' ? 'ANTIGO TESTAMENTO' : 'NOVO TESTAMENTO',
                                  style: TextStyle(fontSize: 11.5, letterSpacing: 0.8, color: muted, fontWeight: FontWeight.w600)),
                            ),
                            Wrap(spacing: 6, runSpacing: 6, children: [
                              for (final b in _visible(s.bible.books).where((b) => b.testament == t))
                                ActionChip(
                                  label: Text(b.name),
                                  onPressed: b.chapters == 1 ? () => _go(s, b, 1) : () => setState(() => _book = b),
                                  side: b.id == s.current.$1
                                      ? BorderSide(color: Theme.of(context).colorScheme.primary)
                                      : null,
                                ),
                            ]),
                          ],
                        ],
                      )
                    : GridView.extent(
                        shrinkWrap: true,
                        maxCrossAxisExtent: 56,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          for (var c = 1; c <= _book!.chapters; c++)
                            ChapterButton(
                              n: c,
                              read: s.flag(Opt.lidos) && s.user.readChapters(_book!.id).contains(c),
                              resume: s.resumeAt?.book == _book!.id && s.resumeAt?.chapter == c,
                              current: _book!.id == s.current.$1 && c == s.current.$2,
                              onTap: () => _go(s, _book!, c),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _go(AppState s, Book b, int c) {
    Navigator.pop(context);
    s.goTo(Ref(b.id, c, 1), select: false);
  }
}

/// Botão de capítulo usado no seletor e na busca.
class ChapterButton extends StatelessWidget {
  final int n;
  final bool current;
  final bool read, resume;
  final VoidCallback onTap;
  const ChapterButton(
      {super.key, required this.n, required this.current, required this.onTap, this.read = false, this.resume = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: current ? scheme.primary : Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), side: BorderSide(color: scheme.outlineVariant)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Stack(alignment: Alignment.center, children: [
          Text('$n',
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: current ? scheme.onPrimary : scheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          if (read)
            Positioned(
                top: 3,
                right: 3,
                child: Icon(Icons.check_circle, size: 12, color: current ? scheme.onPrimary : ReaderColors.of(context).read)),
          if (resume)
            Positioned(
                bottom: 3,
                right: 3,
                child: Icon(Icons.bookmark_added, size: 12, color: current ? scheme.onPrimary : ReaderColors.of(context).mark)),
        ]),
      ),
    );
  }
}
