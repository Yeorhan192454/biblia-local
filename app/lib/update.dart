import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Atualização automática: cada versão publicada no GitHub (v0.1.N, uma por merge na main) é uma
/// atualização. Os dados vêm do build (--dart-define); sem token o app simplesmente não procura.
const appBuild = int.fromEnvironment('BUILD');
const _repo = String.fromEnvironment('REPO', defaultValue: 'Yeorhan192454/Bible');
const _token = String.fromEnvironment('UPDATE_TOKEN');

String get appVersion => appBuild == 0 ? 'desenvolvimento' : '0.1.$appBuild';

bool get updatesEnabled =>
    !kIsWeb && _token.isNotEmpty && appBuild > 0 && (Platform.isAndroid || Platform.isWindows || Platform.isLinux);

class Release {
  final int build;
  final String page;
  final String? assetUrl; // instalador para esta plataforma
  final String? assetName;
  const Release(this.build, this.page, this.assetUrl, this.assetName);
  String get version => '0.1.$build';
}

Map<String, String> get _auth => {'Authorization': 'Bearer $_token', 'X-GitHub-Api-Version': '2022-11-28'};

/// Última versão publicada, ou null se não houver uma mais nova que esta. Lança erro sem conexão.
Future<Release?> checkForUpdate() async {
  if (!updatesEnabled) return null;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final req = await client.getUrl(Uri.parse('https://api.github.com/repos/$_repo/releases/latest'));
    _auth.forEach(req.headers.set);
    req.headers.set('Accept', 'application/vnd.github+json');
    final res = await req.close();
    if (res.statusCode != 200) throw HttpException('GitHub respondeu ${res.statusCode}');
    final j = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
    final m = RegExp(r'^v0\.1\.(\d+)$').firstMatch(j['tag_name'] as String? ?? '');
    if (m == null) return null;
    final build = int.parse(m.group(1)!);
    if (build <= appBuild) return null;
    final suffix = Platform.isAndroid ? '-android.apk' : Platform.isWindows ? '-windows-instalador.exe' : null;
    Map<String, dynamic>? asset;
    for (final a in (j['assets'] as List).cast<Map<String, dynamic>>()) {
      if (suffix != null && (a['name'] as String).endsWith(suffix)) asset = a;
    }
    return Release(build, j['html_url'] as String, asset?['url'] as String?, asset?['name'] as String?);
  } finally {
    client.close();
  }
}

/// Baixa o instalador; [progress] recebe de 0 a 1.
Future<File> download(Release r, void Function(double) progress) async {
  final client = HttpClient();
  try {
    // a API responde com um redirecionamento para o arquivo; o token não pode seguir junto
    final req = await client.getUrl(Uri.parse(r.assetUrl!));
    req.followRedirects = false;
    _auth.forEach(req.headers.set);
    req.headers.set('Accept', 'application/octet-stream');
    var res = await req.close();
    if (res.isRedirect) {
      await res.drain<void>();
      final next = await client.getUrl(Uri.parse(res.headers.value(HttpHeaders.locationHeader)!));
      res = await next.close();
    }
    if (res.statusCode != 200) throw HttpException('download falhou (${res.statusCode})');
    final dir = Directory('${(await getTemporaryDirectory()).path}/atualizacao');
    await dir.create(recursive: true);
    final file = File('${dir.path}/${r.assetName}');
    final sink = file.openWrite();
    var got = 0;
    final total = res.contentLength;
    await for (final chunk in res) {
      sink.add(chunk);
      got += chunk.length;
      if (total > 0) progress(got / total);
    }
    await sink.close();
    return file;
  } finally {
    client.close();
  }
}

const _channel = MethodChannel('biblia/atualizacao');

/// Abre o instalador baixado. No Windows o app fecha para o instalador poder substituí-lo.
Future<void> install(File f) async {
  if (Platform.isAndroid) {
    await _channel.invokeMethod('instalarApk', f.path);
  } else if (Platform.isWindows) {
    await Process.start(f.path, ['/SILENT', '/NOCANCEL', '/SP-'], mode: ProcessStartMode.detached);
    exit(0);
  }
}

Future<void> _openPage(String url) async {
  if (Platform.isLinux) await Process.start('xdg-open', [url], mode: ProcessStartMode.detached);
}

/// Pergunta se quer atualizar e conduz o download e a instalação.
Future<void> offerUpdate(BuildContext context, Release r) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.system_update),
      title: const Text('Atualização disponível'),
      content: Text('A versão ${r.version} está pronta (você usa a $appVersion).'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Depois')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Atualizar')),
      ],
    ),
  );
  if (go != true || !context.mounted) return;
  if (r.assetUrl == null) {
    await _openPage(r.page);
    return;
  }
  final progress = ValueNotifier<double?>(null);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Baixando atualização…'),
      content: ValueListenableBuilder<double?>(
        valueListenable: progress,
        builder: (_, p, _) => Column(mainAxisSize: MainAxisSize.min, children: [
          LinearProgressIndicator(value: p),
          const SizedBox(height: 8),
          Text(p == null ? '' : '${(p * 100).round()}%'),
        ]),
      ),
    ),
  );
  try {
    final f = await download(r, (p) => progress.value = p);
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    await install(f);
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Não deu para baixar a atualização. Tente de novo mais tarde.')));
  }
}
