import 'dart:async';

import 'package:flutter/material.dart';

import '../data/bible_db.dart';
import '../data/refs.dart';
import '../data/user_db.dart';
import '../state.dart';
import '../theme.dart';
import 'contents.dart';
import 'page_menu.dart';
import 'settings.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final _q = TextEditingController();
  Timer? _debounce;
  String? _version; // null = todas
  String _scope = 'all'; // 'all', 'AT', 'NT' ou 'b<livro>'
  List<SearchHit> _hits = [];
  List<RefMatch> _refs = [];
  int _total = 0;

  (int, int)? get _books => switch (_scope) {
        'AT' => (1, 39),
        'NT' => (40, 66),
        _ when _scope.startsWith('b') => (int.parse(_scope.substring(1)), int.parse(_scope.substring(1))),
        _ => null,
      };

  String _scopeLabel(BibleDb bible) => switch (_scope) {
        'AT' => 'Antigo Testamento',
        'NT' => 'Novo Testamento',
        _ when _scope.startsWith('b') => bible.book(int.parse(_scope.substring(1))).name,
        _ => 'Toda a Bíblia',
      };

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    _q.text = s.user.setting('lastSearch') ?? '';
    _version = s.user.setting('searchVersion');
    if (_version == '') _version = null;
    _scope = s.user.setting('searchScope') ?? 'all';
    if (!RegExp(r'^(all|AT|NT|b\d+)$').hasMatch(_scope)) _scope = 'all';
    _run();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _run() {
    final s = AppScope.read(context);
    final q = _q.text.trim();
    s.user.setSetting('lastSearch', q);
    setState(() {
      _refs = parseRef(s.bible.books, q).take(4).toList();
      if (q.length < 2) {
        _hits = [];
        _total = 0;
      } else {
        _hits = s.bible.search(q, version: _version, books: _books);
        _total = s.bible.searchCount(q, version: _version, books: _books);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = ReaderColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const PageMenuButton(),
        centerTitle: true,
        title: const Text('Buscar'),
        actions: const [SettingsButton()],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: TextField(
                controller: _q,
                autofocus: _q.text.isEmpty,
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Palavra, livro ou referência, ex.: graça, salmos, jo 3 16',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _q.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _q.clear();
                            _run();
                          }),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), _run);
                },
                onSubmitted: (_) => _run(),
              ),
            ),
            SizedBox(
              height: 48,
              child: Center(
                child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(children: [
                  PopupMenuButton<String>(
                    tooltip: 'Onde buscar',
                    onSelected: (v) {
                      _scope = v;
                      s.user.setSetting('searchScope', v);
                      _run();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'all', child: Text('Toda a Bíblia')),
                      const PopupMenuItem(value: 'AT', child: Text('Antigo Testamento')),
                      const PopupMenuItem(value: 'NT', child: Text('Novo Testamento')),
                      const PopupMenuDivider(),
                      for (final b in s.bible.books) PopupMenuItem(value: 'b${b.id}', child: Text(b.name)),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Chip(
                        avatar: const Icon(Icons.filter_list, size: 16),
                        label: Text('Em: ${_scopeLabel(s.bible)}'),
                        backgroundColor: _scope == 'all' ? null : c.accentSoft,
                      ),
                    ),
                  ),
                  for (final v in <Version?>[null, ...s.bible.versions])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(v?.abbr ?? 'Todas'),
                        selected: _version == v?.id,
                        onSelected: (_) {
                          _version = v?.id;
                          s.user.setSetting('searchVersion', _version ?? '');
                          _run();
                        },
                      ),
                    ),
                ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  _q.text.trim().length < 2
                      ? 'Busca sem acento: "coracao" encontra "coração".'
                      : _total == 0 && _refs.isNotEmpty
                          ? ''
                      : _total > _hits.length
                          ? '$_total resultados · mostrando os ${_hits.length} primeiros'
                          : '$_total resultado${_total == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12.5, color: c.muted),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: _refs.length + _hits.length,
                separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
                itemBuilder: (_, i) {
                  if (i < _refs.length) return _refTile(s, _refs[i], first: i == 0);
                  final h = _hits[i - _refs.length];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text.rich(TextSpan(children: [
                      TextSpan(text: s.refLabel(Ref(h.book, h.chapter, h.verse))),
                      TextSpan(text: '  ${s.bible.version(h.version).abbr}', style: TextStyle(color: c.muted, fontWeight: FontWeight.w400)),
                    ]), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text.rich(_highlight(h.marked, c.accentSoft),
                          style: TextStyle(fontFamily: serif, fontSize: 16, height: 1.45, color: scheme.onSurface)),
                    ),
                    onTap: () {
                      s.setVersion(h.version);
                      s.goTo(Ref(h.book, h.chapter, h.verse));
                    },
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// Livro ou referência encontrada no que foi digitado.
  Widget _refTile(AppState s, RefMatch r, {required bool first}) {
    final scheme = Theme.of(context).colorScheme;
    if (r.chapter != null) {
      final label = '${r.book.name} ${r.chapter}${r.verse != null ? ':${r.verse}' : ''}';
      return ListTile(
        leading: Icon(Icons.arrow_forward, color: scheme.primary),
        title: Text('Ir para $label', style: TextStyle(fontWeight: FontWeight.w600, color: scheme.primary)),
        onTap: () => s.goTo(Ref(r.book.id, r.chapter!, r.verse ?? 1), select: r.verse != null),
      );
    }
    return BookTile(key: ValueKey('ref-${r.book.id}'), book: r.book, initiallyExpanded: first && _refs.length == 1);
  }

  TextSpan _highlight(String marked, Color bg) {
    final spans = <TextSpan>[];
    final parts = marked.split('\u0001');
    spans.add(TextSpan(text: parts.first));
    for (final part in parts.skip(1)) {
      final i = part.indexOf('\u0002');
      if (i < 0) {
        spans.add(TextSpan(text: part));
        continue;
      }
      spans.add(TextSpan(text: part.substring(0, i), style: TextStyle(backgroundColor: bg, fontWeight: FontWeight.w700)));
      spans.add(TextSpan(text: part.substring(i + 1)));
    }
    return TextSpan(children: spans);
  }
}
