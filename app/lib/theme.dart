import 'package:flutter/material.dart';

const serif = 'Gentium';
const hebrew = 'NotoSerifHebrew';

/// Cores extras do leitor (marcadores, destaque), por tema.
@immutable
class ReaderColors extends ThemeExtension<ReaderColors> {
  final Color mark;
  final Color markSoft;
  final Color accentSoft;
  final Color muted;
  final Color god; // falas de Deus
  final Color jesus; // falas de Jesus
  final Color read; // capítulo lido
  const ReaderColors(
      {required this.mark,
      required this.markSoft,
      required this.accentSoft,
      required this.muted,
      required this.god,
      required this.jesus,
      required this.read});

  @override
  ReaderColors copyWith(
          {Color? mark, Color? markSoft, Color? accentSoft, Color? muted, Color? god, Color? jesus, Color? read}) =>
      ReaderColors(
          mark: mark ?? this.mark,
          markSoft: markSoft ?? this.markSoft,
          accentSoft: accentSoft ?? this.accentSoft,
          muted: muted ?? this.muted,
          god: god ?? this.god,
          jesus: jesus ?? this.jesus,
          read: read ?? this.read);

  @override
  ReaderColors lerp(ReaderColors? other, double t) => other == null
      ? this
      : ReaderColors(
          mark: Color.lerp(mark, other.mark, t)!,
          markSoft: Color.lerp(markSoft, other.markSoft, t)!,
          accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
          muted: Color.lerp(muted, other.muted, t)!,
          god: Color.lerp(god, other.god, t)!,
          jesus: Color.lerp(jesus, other.jesus, t)!,
          read: Color.lerp(read, other.read, t)!);

  static ReaderColors of(BuildContext c) => Theme.of(c).extension<ReaderColors>()!;
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final accent = dark ? const Color(0xFF86B6D8) : const Color(0xFF23577A);
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF23577A), brightness: b).copyWith(
    primary: accent,
    surface: dark ? const Color(0xFF13161B) : const Color(0xFFF3F4F1),
    surfaceContainerLow: dark ? const Color(0xFF1B1F26) : const Color(0xFFFFFFFF),
    onSurface: dark ? const Color(0xFFE7E4DD) : const Color(0xFF1E232C),
    outlineVariant: dark ? const Color(0xFF2C323B) : const Color(0xFFD9DCDD),
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontFamily: serif, fontSize: 21, fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: dark ? const Color(0xFF1F3140) : const Color(0xFFE2ECF3),
      surfaceTintColor: Colors.transparent,
    ),
    extensions: [
      ReaderColors(
        mark: dark ? const Color(0xFFE2A84E) : const Color(0xFFA9701A),
        markSoft: dark ? const Color(0xFF3A2D18) : const Color(0xFFF6EAD3),
        accentSoft: dark ? const Color(0xFF1F3140) : const Color(0xFFE2ECF3),
        muted: dark ? const Color(0xFF9AA1AC) : const Color(0xFF646B77),
        god: dark ? const Color(0xFFE5B84B) : const Color(0xFF9A6B00),
        jesus: dark ? const Color(0xFFF28B82) : const Color(0xFFB3261E),
        read: dark ? const Color(0xFF7FCB8F) : const Color(0xFF2E7D45),
      ),
    ],
  );
}
