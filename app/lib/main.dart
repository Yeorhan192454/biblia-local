import 'package:flutter/material.dart';

import 'data/bible_db.dart';
import 'data/user_db.dart';
import 'state.dart';
import 'theme.dart';
import 'ui/home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BibliaApp());
}

class BibliaApp extends StatefulWidget {
  const BibliaApp({super.key});

  @override
  State<BibliaApp> createState() => _BibliaAppState();
}

class _BibliaAppState extends State<BibliaApp> {
  static final _noTheme = ValueNotifier(ThemeMode.system);
  AppState? _state;
  String _status = 'Abrindo…';
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bible = await BibleDb.open(onStatus: (m) => setState(() => _status = m));
      final user = await UserDb.open();
      setState(() => _state = AppState(bible, user));
    } catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _state?.themeMode ?? _noTheme,
      builder: (context, mode, _) => MaterialApp(
      title: 'Bíblia Local',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: mode,
      home: _state == null
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Bíblia Local', style: TextStyle(fontFamily: serif, fontSize: 30, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    if (_error == null) ...[
                      const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
                      const SizedBox(height: 12),
                      Text(_status, textAlign: TextAlign.center),
                    ] else
                      Text('Não foi possível abrir os textos: $_error', textAlign: TextAlign.center),
                  ]),
                ),
              ),
            )
          : AppScope(state: _state!, child: const HomeShell()),
      ),
    );
  }
}
