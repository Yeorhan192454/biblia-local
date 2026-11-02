import 'package:flutter/material.dart';

import '../data/user_db.dart';
import '../state.dart';
import '../theme.dart';
import 'page_menu.dart';
import 'settings.dart';

class BookmarksView extends StatelessWidget {
  const BookmarksView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final refs = s.user.bookmarks();
    return _ListScaffold(
      title: 'Marcadores',
      empty: 'Nenhum marcador ainda. Toque num versículo e escolha Marcar.',
      children: [
        if (s.resumeAt case final r?)
          _RefTile(
            r: r,
            extra: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Icon(Icons.bookmark_added, size: 16, color: ReaderColors.of(context).mark),
                const SizedBox(width: 6),
                Text('Ponto de leitura', style: TextStyle(fontSize: 12.5, color: ReaderColors.of(context).mark)),
              ]),
            ),
            trailing: IconButton(
              tooltip: 'Remover ponto de leitura',
              icon: const Icon(Icons.bookmark_remove_outlined),
              onPressed: () => s.user.setResumePoint(null),
            ),
          ),
        for (final r in refs)
          _RefTile(
            r: r,
            trailing: IconButton(
              tooltip: 'Remover marcador',
              icon: const Icon(Icons.bookmark_remove_outlined),
              onPressed: () => s.user.toggleBookmark(r),
            ),
          ),
      ],
    );
  }
}

class NotesView extends StatelessWidget {
  const NotesView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = ReaderColors.of(context);
    return _ListScaffold(
      title: 'Notas',
      empty: 'Nenhuma anotação ainda. Toque num versículo e escolha Anotar.',
      children: [
        for (final n in s.user.notes())
          _RefTile(
            r: n.ref,
            extra: Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: c.markSoft, borderRadius: BorderRadius.circular(8)),
              child: Text(n.text, style: const TextStyle(fontSize: 14.5)),
            ),
          ),
      ],
    );
  }
}

class _ListScaffold extends StatelessWidget {
  final String title, empty;
  final List<Widget> children;
  const _ListScaffold({required this.title, required this.empty, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageMenuButton(),
        centerTitle: true,
        title: Text(title),
        actions: [
          const SettingsButton(),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
      ),
      body: children.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(empty, textAlign: TextAlign.center, style: TextStyle(color: ReaderColors.of(context).muted)),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView.separated(
                  itemCount: children.length,
                  separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
                  itemBuilder: (_, i) => children[i],
                ),
              ),
            ),
    );
  }
}

class _RefTile extends StatelessWidget {
  final Ref r;
  final Widget? trailing;
  final Widget? extra;
  const _RefTile({required this.r, this.trailing, this.extra});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final text = s.bible.verseText(s.version, r.book, r.chapter, r.verse) ??
        s.bible.compare(r.book, r.chapter, r.verse).firstOrNull?.$2 ??
        '';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(s.refLabel(r), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 3),
        Text(text, style: TextStyle(fontFamily: serif, fontSize: 16, height: 1.45, color: Theme.of(context).colorScheme.onSurface)),
        ?extra,
      ]),
      trailing: trailing,
      onTap: () => s.goTo(r),
    );
  }
}
