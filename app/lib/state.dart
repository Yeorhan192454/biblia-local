import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/bible_db.dart';
import 'data/user_db.dart';

enum Edition { tr, critical }

/// Chaves das opções que ligam/desligam partes do app (todas começam ligadas).
class Opt {
  static const lidos = 'lidos';
  static const marcadores = 'marcadores';
  static const anotacoes = 'anotacoes';
  static const copiar = 'copiar';
  static const navCapitulo = 'navCapitulo';
  static const contagem = 'contagem';
  static const edicao = 'edicao';
  static const detalhesPalavra = 'detalhesPalavra';
  static const notasEstudo = 'notasEstudo';
  static const resumo = 'resumo';
  static const vibracao = 'vibracao';
  static const atualizacaoAuto = 'atualizacaoAuto';
}

/// Estado compartilhado do app: posição de leitura, versão, versículo selecionado.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  final BibleDb bible;
  final UserDb user;

  late String version;
  late int chapterPos; // índice em bible.chapterIndex
  late double fontScale;
  late Edition edition;
  late bool hideStatusBar; // esconde a barra do relógio (Android)
  late bool hideNavBar; // esconde os botões de baixo (Android)
  late bool pinchZoom; // pinça de dedo muda o tamanho da fonte
  late bool tapVerse; // tocar no versículo abre o painel
  late bool showCompare; // painel: outras versões do versículo
  late bool showCrossRefs; // painel: vínculos
  late bool showNames; // painel: pessoas e lugares
  late bool useResume; // toque longo marca o ponto de leitura; menu Retomar
  late bool showOriginal; // painel: hebraico/grego palavra por palavra
  late bool showSpeech; // falas de Deus em dourado e de Jesus em vermelho
  late final ValueNotifier<ThemeMode> themeMode; // claro, escuro ou o do sistema
  Ref? selected;
  int tab = 0;

  /// Seção aberta no painel do versículo (só uma por vez; nula = todas fechadas). Começa em "Comparar versões".
  final ValueNotifier<String?> openSection = ValueNotifier('compare');

  void toggleSection(String id) => openSection.value = openSection.value == id ? null : id;

  /// Versículos de origem, na ordem em que o leitor seguiu vínculos. Trocar de capítulo por outro caminho zera.
  final List<Ref> linkHistory = [];
  bool _following = false;

  /// Pedido de rolagem até um versículo depois de trocar de capítulo.
  int? scrollToVerse;

  AppState(this.bible, this.user) {
    version = user.setting('version') ?? bible.versions.first.id;
    if (!bible.versions.any((v) => v.id == version)) version = bible.versions.first.id;
    chapterPos = int.tryParse(user.setting('chapterPos') ?? '') ?? bible.indexOf(43, 3);
    if (chapterPos < 0 || chapterPos >= bible.chapterIndex.length) chapterPos = 0;
    fontScale = double.tryParse(user.setting('fontScale') ?? '') ?? 1.0;
    edition = user.setting('edition') == 'critical' ? Edition.critical : Edition.tr;
    pinchZoom = user.setting('pinca') != 'nao';
    tapVerse = user.setting('toqueVersiculo') != 'nao';
    showCompare = user.setting('versoesVersiculo') != 'nao';
    showCrossRefs = user.setting('vinculos') != 'nao';
    showNames = user.setting('pessoasLugares') != 'nao';
    useResume = user.setting('pontoLeitura') != 'nao';
    showOriginal = user.setting('originais') != 'nao';
    showSpeech = user.setting('falas') != 'nao';
    themeMode = ValueNotifier(switch (user.setting('tema')) {
      'claro' => ThemeMode.light,
      'escuro' => ThemeMode.dark,
      _ => ThemeMode.system,
    });
    hideStatusBar = user.setting('esconderStatus') == 'sim';
    hideNavBar = user.setting('esconderNav') == 'sim';
    _applyChrome();
    WidgetsBinding.instance.addObserver(this);
    user.addListener(notifyListeners);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _applyChrome();
  }

  void _applyChrome() {
    if (hideStatusBar && hideNavBar) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [
        if (!hideStatusBar) SystemUiOverlay.top,
        if (!hideNavBar) SystemUiOverlay.bottom,
      ]);
    }
  }

  void setHideStatusBar(bool on) {
    hideStatusBar = on;
    user.setSetting('esconderStatus', on ? 'sim' : 'nao');
    _applyChrome();
    notifyListeners();
  }

  void setHideNavBar(bool on) {
    hideNavBar = on;
    user.setSetting('esconderNav', on ? 'sim' : 'nao');
    _applyChrome();
    notifyListeners();
  }

  (int, int) get current => bible.chapterIndex[chapterPos];
  Book get currentBook => bible.book(current.$1);
  String get currentTitle => '${currentBook.name} ${current.$2}';

  String refLabel(Ref r) => '${bible.book(r.book).name} ${r.chapter}:${r.verse}';

  void setVersion(String id) {
    version = id;
    user.setSetting('version', id);
    notifyListeners();
  }

  void setChapterPos(int pos, {bool notify = true}) {
    if (pos < 0 || pos >= bible.chapterIndex.length) return;
    if (pos != chapterPos && !_following) linkHistory.clear();
    chapterPos = pos;
    user.setSetting('chapterPos', '$pos');
    if (notify) notifyListeners();
  }

  void goTo(Ref r, {bool select = true, Ref? from}) {
    tab = 0;
    scrollToVerse = r.verse;
    if (select) selected = r;
    if (from == null) linkHistory.clear();
    _following = from != null;
    if (from != null && (linkHistory.isEmpty || linkHistory.last != from)) linkHistory.add(from);
    try {
      setChapterPos(bible.indexOf(r.book, r.chapter));
    } finally {
      _following = false;
    }
    notifyListeners();
  }

  /// Volta ao versículo de origem do último vínculo seguido.
  void backFromLink() {
    if (linkHistory.isEmpty) return;
    final r = linkHistory.removeLast();
    _following = true;
    try {
      tab = 0;
      scrollToVerse = r.verse;
      selected = r;
      setChapterPos(bible.indexOf(r.book, r.chapter));
    } finally {
      _following = false;
    }
    notifyListeners();
  }

  /// Marca (ou, se já for ele, desmarca) o ponto de leitura.
  void toggleResume(Ref r) => user.setResumePoint(resumeAt == r ? null : r);

  /// Volta ao capítulo e versículo do ponto de leitura.
  void resume() {
    final r = resumeAt;
    if (r != null) goTo(r, select: false);
  }

  void select(Ref? r) {
    selected = r;
    notifyListeners();
  }

  void setTab(int t) {
    tab = t;
    notifyListeners();
  }

  static const minFontScale = 0.7, maxFontScale = 2.4;

  void setFontScale(double s, {bool save = true}) {
    fontScale = s.clamp(minFontScale, maxFontScale);
    if (save) user.setSetting('fontScale', '$fontScale');
    notifyListeners();
  }

  void saveFontScale() => user.setSetting('fontScale', '$fontScale');

  void setPinchZoom(bool on) {
    pinchZoom = on;
    user.setSetting('pinca', on ? 'sim' : 'nao');
    notifyListeners();
  }

  void setTapVerse(bool on) {
    tapVerse = on;
    user.setSetting('toqueVersiculo', on ? 'sim' : 'nao');
    if (!on) selected = null;
    notifyListeners();
  }

  void setShowCompare(bool on) {
    showCompare = on;
    user.setSetting('versoesVersiculo', on ? 'sim' : 'nao');
    notifyListeners();
  }

  void setShowCrossRefs(bool on) {
    showCrossRefs = on;
    user.setSetting('vinculos', on ? 'sim' : 'nao');
    notifyListeners();
  }

  void setShowNames(bool on) {
    showNames = on;
    user.setSetting('pessoasLugares', on ? 'sim' : 'nao');
    notifyListeners();
  }

  final _flags = <String, bool>{};

  bool flag(String key) => _flags[key] ??= user.setting(key) != 'nao';

  void setFlag(String key, bool on) {
    _flags[key] = on;
    user.setSetting(key, on ? 'sim' : 'nao');
    // não deixa a pessoa numa aba que acabou de sumir do menu
    if ((key == Opt.marcadores && tab == 3) || (key == Opt.anotacoes && tab == 4)) tab = 0;
    notifyListeners();
  }

  /// Edição do original em uso: sem o seletor, vale sempre o Textus Receptus.
  Edition get activeEdition => flag(Opt.edicao) ? edition : Edition.tr;

  void setUseResume(bool on) {
    useResume = on;
    user.setSetting('pontoLeitura', on ? 'sim' : 'nao');
    notifyListeners();
  }

  /// Ponto de leitura, ou nulo se o recurso estiver desligado (a marca fica guardada).
  Ref? get resumeAt => useResume ? user.resumePoint() : null;

  void setShowOriginal(bool on) {
    showOriginal = on;
    user.setSetting('originais', on ? 'sim' : 'nao');
    notifyListeners();
  }

  void setShowSpeech(bool on) {
    showSpeech = on;
    user.setSetting('falas', on ? 'sim' : 'nao');
    notifyListeners();
  }

  void setThemeMode(ThemeMode m) {
    themeMode.value = m;
    user.setSetting('tema', switch (m) { ThemeMode.light => 'claro', ThemeMode.dark => 'escuro', _ => 'sistema' });
  }

  void setEdition(Edition e) {
    edition = e;
    user.setSetting('edition', e == Edition.critical ? 'critical' : 'tr');
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
