import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';

/// Licença: uso, direitos autorais e notas de cada versão e fonte. As licenças CC BY e CC BY-SA exigem que a fonte seja citada.
class AboutPage extends StatelessWidget {
  final AppState state;
  const AboutPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final c = ReaderColors.of(context);
    Widget section(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
          child: Text(t.toUpperCase(),
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.9, color: c.muted)),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Licença')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const Text('Bíblia Local', style: TextStyle(fontFamily: serif, fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Funciona sem internet. Marcadores, anotações e capítulos lidos ficam só neste aparelho.',
                  style: TextStyle(color: c.muted)),
              section('Uso'),
              const Text(
                  'Cada tradução tem a sua licença, indicada abaixo. Os textos com "uso pessoal" não podem ser '
                  'redistribuídos nem publicados. As licenças Creative Commons exigem que a fonte seja citada.'),
              section('Traduções'),
              for (final v in state.bible.versions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${v.name} (${v.abbr})'),
                  subtitle: Text('Licença: ${v.license}\n${v.credit}'),
                  isThreeLine: true,
                ),
              section('Textos originais e dicionários'),
              for (final (name, credit) in state.bible.credits)
                ListTile(contentPadding: EdgeInsets.zero, title: Text(name), subtitle: Text(credit)),
              section('Fontes tipográficas'),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Gentium Book Plus e Noto Serif Hebrew'),
                subtitle: Text('SIL Open Font License 1.1.'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
