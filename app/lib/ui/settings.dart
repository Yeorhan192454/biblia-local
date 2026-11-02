import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../state.dart';
import '../update.dart';
import 'about.dart';
import 'confirm.dart';

/// Botão de engrenagem que abre as configurações.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Configurações',
        icon: const Icon(Icons.settings_outlined),
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AppScope(state: AppScope.read(context), child: const SettingsPage()))),
      );
}

/// Configurações, agrupadas por categoria (cada grupo abre e fecha).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final read = s.user.readCount();
    Widget group(IconData icon, String title, List<Widget> children) => ExpansionTile(
          leading: Icon(icon),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          shape: const Border(),
          collapsedShape: const Border(),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: children,
        );
    final mobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              group(Icons.palette_outlined, 'Aparência', [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ValueListenableBuilder<ThemeMode>(
                    valueListenable: s.themeMode,
                    builder: (context, mode, _) => SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('Automático')),
                        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Claro')),
                        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Escuro')),
                      ],
                      selected: {mode},
                      onSelectionChanged: (v) => s.setThemeMode(v.first),
                    ),
                  ),
                ),
                if (mobile) ...[
                SwitchListTile(
                  secondary: const Icon(Icons.access_time),
                  title: const Text('Esconder barra do relógio'),
                  subtitle: const Text('Barra de cima, com hora e bateria.'),
                  value: s.hideStatusBar,
                  onChanged: s.setHideStatusBar,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.smart_button),
                  title: const Text('Esconder botões de baixo'),
                  subtitle: const Text('Barra de navegação do Android.'),
                  value: s.hideNavBar,
                  onChanged: s.setHideNavBar,
                ),
                ],
              ]),
              group(Icons.text_fields, 'Texto', [
                ListTile(
                  leading: const Icon(Icons.format_size),
                  title: Text('Tamanho da fonte: ${(s.fontScale * 100).round()}%'),
                  subtitle: Slider(
                    value: s.fontScale.clamp(AppState.minFontScale, AppState.maxFontScale),
                    min: AppState.minFontScale,
                    max: AppState.maxFontScale,
                    divisions: 17,
                    onChanged: (v) => s.setFontScale(v, save: false),
                    onChangeEnd: (_) => s.saveFontScale(),
                  ),
                  trailing: TextButton(
                    onPressed: s.fontScale == 1 ? null : () => s.setFontScale(1),
                    child: const Text('Padrão'),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.pinch),
                  title: const Text('Pinça de dedo'),
                  subtitle: const Text('Aproximar ou afastar dois dedos na leitura muda o tamanho da fonte.'),
                  value: s.pinchZoom,
                  onChanged: s.setPinchZoom,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.format_color_text),
                  title: const Text('Falas de Deus e de Jesus em cores'),
                  value: s.showSpeech,
                  onChanged: s.setShowSpeech,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.format_list_numbered),
                  title: const Text('Contagem de versículos'),
                  subtitle: const Text('Linha “N versículos” abaixo do título do capítulo.'),
                  value: s.flag(Opt.contagem),
                  onChanged: (v) => s.setFlag(Opt.contagem, v),
                ),
              ]),
              group(Icons.view_sidebar_outlined, 'Painel do versículo', [
                SwitchListTile(
                  secondary: const Icon(Icons.touch_app),
                  title: const Text('Tocar no versículo abre o painel'),
                  subtitle: const Text('Versões, original, marcar e anotar.'),
                  value: s.tapVerse,
                  onChanged: s.setTapVerse,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.compare_arrows),
                  title: const Text('Diferentes versões do versículo'),
                  value: s.showCompare,
                  onChanged: s.tapVerse ? s.setShowCompare : null,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.link),
                  title: const Text('Vínculos'),
                  subtitle: const Text('Outros versículos relacionados.'),
                  value: s.showCrossRefs,
                  onChanged: s.tapVerse ? s.setShowCrossRefs : null,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.groups_outlined),
                  title: const Text('Pessoas e lugares'),
                  value: s.showNames,
                  onChanged: s.tapVerse ? s.setShowNames : null,
                ),
                if (s.bible.hasStudyNotes)
                SwitchListTile(
                  secondary: const Icon(Icons.school_outlined),
                  title: const Text('Notas de estudo'),
                  subtitle: Text(s.bible.studyNotesSource.isEmpty
                      ? 'Comentários sobre o versículo.'
                      : 'Comentários: ${s.bible.studyNotesSource}.'),
                  value: s.flag(Opt.notasEstudo),
                  onChanged: s.tapVerse ? (v) => s.setFlag(Opt.notasEstudo, v) : null,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.auto_stories_outlined),
                  title: const Text('Botão Resumo'),
                  subtitle: const Text('Resumo do livro e do capítulo, com base nas notas unfoldingWord.'),
                  value: s.flag(Opt.resumo),
                  onChanged: s.tapVerse ? (v) => s.setFlag(Opt.resumo, v) : null,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.translate),
                  title: const Text('Hebraico/Grego'),
                  subtitle: const Text('Original palavra por palavra, com explicação.'),
                  value: s.showOriginal,
                  onChanged: s.tapVerse ? s.setShowOriginal : null,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.menu_book_outlined),
                  title: const Text('Textus Receptus e edição crítica'),
                  subtitle: const Text('Seletor de edição do Novo Testamento e palavras que mudam entre elas.'),
                  value: s.flag(Opt.edicao),
                  onChanged: s.tapVerse && s.showOriginal ? (v) => s.setFlag(Opt.edicao, v) : null,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.manage_search),
                  title: const Text('Detalhes da palavra do original'),
                  subtitle: const Text('Strong, ocorrências, análise gramatical e verbete.'),
                  value: s.flag(Opt.detalhesPalavra),
                  onChanged: s.tapVerse && s.showOriginal ? (v) => s.setFlag(Opt.detalhesPalavra, v) : null,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.share),
                  title: const Text('Botão Compartilhar'),
                  subtitle: const Text('Envia o versículo com livro, capítulo e número por WhatsApp, Instagram, TikTok ou outro app.'),
                  value: s.flag(Opt.copiar),
                  onChanged: s.tapVerse ? (v) => s.setFlag(Opt.copiar, v) : null,
                ),
              ]),
              group(Icons.bookmark_border, 'Marcações e leitura', [
                SwitchListTile(
                  secondary: const Icon(Icons.bookmark_border),
                  title: const Text('Marcadores'),
                  subtitle: const Text('Marcar versículos, aba Marcadores e o ícone no texto.'),
                  value: s.flag(Opt.marcadores),
                  onChanged: (v) => s.setFlag(Opt.marcadores, v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.sticky_note_2_outlined),
                  title: const Text('Anotações'),
                  subtitle: const Text('Anotar versículos, aba Notas e o ícone no texto.'),
                  value: s.flag(Opt.anotacoes),
                  onChanged: (v) => s.setFlag(Opt.anotacoes, v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.bookmark_added_outlined),
                  title: const Text('Ponto de leitura (Bookmark)'),
                  subtitle: const Text('Segurar o toque num versículo marca onde parou; Retomar volta a ele.'),
                  value: s.useResume,
                  onChanged: s.setUseResume,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration),
                  title: const Text('Vibração ao marcar o ponto de leitura'),
                  value: s.flag(Opt.vibracao),
                  onChanged: s.useResume ? (v) => s.setFlag(Opt.vibracao, v) : null,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.check_circle_outline),
                  title: const Text('Capítulos lidos'),
                  subtitle: const Text('Botão “Marcar como lido”, checks no Sumário e contagem de lidos.'),
                  value: s.flag(Opt.lidos),
                  onChanged: (v) => s.setFlag(Opt.lidos, v),
                ),
                if (s.flag(Opt.lidos))
                  ListTile(
                    leading: const Icon(Icons.layers_clear),
                    title: const Text('Desmarcar todos os lidos'),
                    subtitle: Text(read == 0
                        ? 'Nenhum capítulo marcado como lido.'
                        : '$read de ${s.bible.chapterIndex.length} capítulos marcados como lidos.'),
                    enabled: read > 0,
                    onTap: () async {
                      final ok = await confirm(context,
                          title: 'Desmarcar todos os lidos?',
                          message: 'Remove a marca de "lido" de todos os $read capítulos. Não dá para desfazer.',
                          action: 'Desmarcar tudo');
                      if (ok) s.user.clearRead();
                    },
                  ),
                SwitchListTile(
                  secondary: const Icon(Icons.swap_horiz),
                  title: const Text('Botões de capítulo anterior e próximo'),
                  subtitle: const Text('No fim do capítulo. Deslizar a página continua funcionando.'),
                  value: s.flag(Opt.navCapitulo),
                  onChanged: (v) => s.setFlag(Opt.navCapitulo, v),
                ),
              ]),
              group(Icons.info_outline, 'Sobre', [
                SwitchListTile(
                  secondary: const Icon(Icons.system_update_alt),
                  title: const Text('Procurar atualização ao abrir'),
                  subtitle: const Text('Se desligado, só procura quando você tocar em “Versão”.'),
                  value: s.flag(Opt.atualizacaoAuto),
                  onChanged: (v) => s.setFlag(Opt.atualizacaoAuto, v),
                ),
                ListTile(
                  leading: const Icon(Icons.system_update),
                  title: Text('Versão $appVersion'),
                  subtitle: Text(updatesEnabled
                      ? 'Toque para procurar atualização.'
                      : 'Atualização automática desligada nesta cópia do app.'),
                  enabled: updatesEnabled,
                  onTap: () async {
                    final m = ScaffoldMessenger.of(context);
                    m.showSnackBar(const SnackBar(content: Text('Procurando atualização…'), duration: Duration(seconds: 2)));
                    final Release? r;
                    try {
                      r = await checkForUpdate();
                    } catch (_) {
                      m.hideCurrentSnackBar();
                      m.showSnackBar(const SnackBar(content: Text('Sem conexão com o GitHub agora. Tente mais tarde.')));
                      return;
                    }
                    if (!context.mounted) return;
                    m.hideCurrentSnackBar();
                    if (r == null) {
                      m.showSnackBar(const SnackBar(content: Text('Você já está na versão mais nova.')));
                    } else {
                      await offerUpdate(context, r);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.gavel),
                  title: const Text('Licença'),
                  subtitle: const Text('Uso, direitos autorais e notas de cada versão e fonte.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AboutPage(state: s))),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
