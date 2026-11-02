import 'package:flutter/material.dart';

import '../state.dart';

const pageTabs = [
  (Icons.menu_book_outlined, Icons.menu_book, 'Ler'),
  (Icons.list_alt_outlined, Icons.list_alt, 'Sumário'),
  (Icons.search, Icons.search, 'Buscar'),
  (Icons.bookmark_border, Icons.bookmark, 'Marcadores'),
  (Icons.sticky_note_2_outlined, Icons.sticky_note_2, 'Notas'),
];

/// Ação, não página: leva ao ponto de leitura.
const _resumeValue = -1;

/// Botão do topo: mostra o ícone da página atual; ao tocar lista as outras páginas.
class PageMenuButton extends StatelessWidget {
  const PageMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return PopupMenuButton<int>(
      tooltip: 'Páginas',
      icon: Icon(pageTabs[s.tab].$2),
      onSelected: (i) => i == _resumeValue ? s.resume() : s.setTab(i),
      itemBuilder: (_) => [
        for (var i = 0; i < pageTabs.length; i++)
          if (i != s.tab && (i != 3 || s.flag(Opt.marcadores)) && (i != 4 || s.flag(Opt.anotacoes)))
            PopupMenuItem(
              value: i,
              child: Row(children: [Icon(pageTabs[i].$1), const SizedBox(width: 12), Text(pageTabs[i].$3)]),
            ),
        if (s.useResume)
          PopupMenuItem(
          value: _resumeValue,
          enabled: s.resumeAt != null,
          child: const Row(children: [Icon(Icons.bookmark_added_outlined), SizedBox(width: 12), Text('Retomar')]),
        ),
      ],
    );
  }
}
