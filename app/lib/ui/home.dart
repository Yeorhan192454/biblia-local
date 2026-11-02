import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state.dart';
import '../theme.dart';
import '../update.dart';
import 'contents.dart';
import 'lists.dart';
import 'reader.dart';
import 'search.dart';
import 'verse_panel.dart';

const _wide = 900.0;

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  bool _sheetOpen = false;
  bool _exitOpen = false;

  @override
  void initState() {
    super.initState();
    // procura uma versão nova a cada abertura do app
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!AppScope.read(context).flag(Opt.atualizacaoAuto)) return;
      try {
        final r = await checkForUpdate();
        if (r != null && mounted) await offerUpdate(context, r);
      } catch (_) {
        // sem internet: tenta de novo na próxima abertura
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final wide = MediaQuery.sizeOf(context).width >= _wide;
    final body = IndexedStack(
      index: s.tab,
      children: const [ReaderView(), ContentsView(), SearchView(), BookmarksView(), NotesView()],
    );

    if (!wide && s.selected != null && !_sheetOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openSheet(s));
    }

    // voltar desfaz os vínculos seguidos, um versículo por vez; sem histórico, avisa antes de sair do app
    Widget back(Widget child) => PopScope(
          canPop: kIsWeb,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (s.linkHistory.isNotEmpty) {
              s.backFromLink();
            } else {
              _confirmExit();
            }
          },
          child: child,
        );

    if (wide) {
      return back(Scaffold(
        body: SafeArea(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: body),
            const VerticalDivider(width: 1),
            SizedBox(
              width: 400,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: s.selected == null
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Toque num versículo para comparar as versões, ver cada palavra do original com sua explicação, marcar ou anotar.',
                          style: TextStyle(color: ReaderColors.of(context).muted, height: 1.5),
                        ),
                      )
                    : VersePanel(key: ValueKey(s.selected), ref: s.selected!, onClose: () => s.select(null)),
              ),
            ),
          ]),
        ),
      ));
    }

    return back(Scaffold(
      body: body,
    ));
  }

  /// Aviso de saída: tocar fora volta ao app; tocar no aviso ou voltar de novo fecha o app.
  Future<void> _confirmExit() {
    if (_exitOpen) return Future.value();
    _exitOpen = true;
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      pageBuilder: (ctx, _, _) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) SystemNavigator.pop();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(ctx).pop(),
          child: Center(
            child: GestureDetector(
              onTap: SystemNavigator.pop,
              child: Material(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(ctx).colorScheme.surfaceContainerHigh,
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.all(20),
                  child: const Text(
                    'Se apertar voltar novamente, o app será fechado.\n\nToque fora deste aviso para continuar lendo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, height: 1.4),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(() => _exitOpen = false);
  }

  Future<void> _openSheet(AppState s) async {
    if (_sheetOpen || s.selected == null || !mounted) return;
    _sheetOpen = true;
    final ref = s.selected!;
    // Página fixa que entra deslizando da esquerda para a direita; o botão flutuante volta ao versículo.
    await Navigator.of(context).push<void>(PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, _) => AppScope(
        state: s,
        child: Builder(builder: (ctx) {
          final back = Navigator.of(ctx).pop;
          return Scaffold(
            backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerLow,
            body: Stack(children: [
              Positioned.fill(
                child: SafeArea(child: VersePanel(key: ValueKey(ref), ref: ref, fullPage: true)),
              ),
              Positioned(
                top: MediaQuery.paddingOf(ctx).top + 8,
                left: 8,
                child: FloatingActionButton.small(
                  heroTag: null,
                  tooltip: 'Voltar',
                  shape: const CircleBorder(),
                  onPressed: back,
                  child: const Icon(Icons.arrow_back),
                ),
              ),
            ]),
          );
        }),
      ),
      transitionsBuilder: (_, anim, _, child) => SlideTransition(
        position: Tween(begin: const Offset(-1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ));
    _sheetOpen = false;
    if (s.selected == ref) s.select(null);
  }
}
