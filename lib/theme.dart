import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta da identidade visual OmniTool.
class BrandColors {
  BrandColors._();

  static const navy = Color(0xFF243C86);
  static const blue = Color(0xFF047BFB);
  static const orange = Color(0xFFFD9704);
  static const gray = Color(0xFF4C4C4C);
  static const white = Color(0xFFFFFFFF);

  /// Fundo da splash e do ícone adaptativo (mesmo valor do pubspec.yaml).
  static const splash = Color(0xFF1C3884);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final base = ColorScheme.fromSeed(seedColor: BrandColors.navy, brightness: brightness);
  final scheme = dark
      ? base.copyWith(
          primary: BrandColors.blue,
          onPrimary: BrandColors.white,
          secondary: BrandColors.blue,
          onSecondary: BrandColors.white,
          tertiary: BrandColors.orange,
          onTertiary: BrandColors.white,
          // Superfícies em azul-marinho, como no mockup da splash.
          surface: const Color(0xFF16255E),
          surfaceContainerLowest: const Color(0xFF111E50),
          surfaceContainerLow: const Color(0xFF1A2A66),
          surfaceContainer: const Color(0xFF1D2F6E),
          surfaceContainerHigh: const Color(0xFF223676),
          surfaceContainerHighest: const Color(0xFF283D7F),
          onSurface: BrandColors.white,
          onSurfaceVariant: const Color(0xFFC5CCE6),
          outline: const Color(0xFF6F7FB5),
          outlineVariant: const Color(0xFF34488C),
        )
      : base.copyWith(
          primary: BrandColors.navy,
          onPrimary: BrandColors.white,
          secondary: BrandColors.blue,
          onSecondary: BrandColors.white,
          tertiary: BrandColors.orange,
          onTertiary: BrandColors.white,
          onSurfaceVariant: BrandColors.gray,
        );

  final textTheme = GoogleFonts.interTextTheme(ThemeData(brightness: brightness).textTheme);
  return ThemeData(
    colorScheme: scheme,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: BrandColors.orange,
      foregroundColor: BrandColors.white,
    ),
  );
}
