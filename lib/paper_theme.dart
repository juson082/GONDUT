import 'package:flutter/material.dart';
import 'notebook_motion.dart';

const themeColors = <String, (String, Color)>{
  // Keep the stored IDs so existing settings and backups remain valid.
  'lavender': ('새싹', Color(0xffdceccf)),
  'rose': ('꽃잎', Color(0xfff1d9dc)),
  'peach': ('햇살', Color(0xfff1e6c8)),
  'sage': ('이끼', Color(0xffd2e2d2)),
  'sky': ('허브', Color(0xffd2e7df)),
  'sand': ('마른 잎', Color(0xffe9dec9)),
  'snow': ('눈 덮인 숲', Color(0xffdceced)),
};

ThemeData paperTheme(String name) {
  final seed = (themeColors[name] ?? themeColors['lavender']!).$2;
  final background = Color.alphaBlend(
    seed.withValues(alpha: .54),
    const Color(0xfffffbf6),
  );
  final paper = Color.alphaBlend(
    seed.withValues(alpha: .32),
    const Color(0xfffffdf9),
  );
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
    surface: background,
  ).copyWith(primaryContainer: paper, surfaceContainerLowest: paper);
  final handwriting = ThemeData.light().textTheme.apply(
    fontFamily: 'GondutHand',
  );
  TextStyle? larger(TextStyle? style, double add) =>
      style?.copyWith(fontSize: (style.fontSize ?? 14) + add);
  return ThemeData(
    useMaterial3: true,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: NotebookPageTransitions(),
        TargetPlatform.iOS: NotebookPageTransitions(),
        TargetPlatform.linux: NotebookPageTransitions(),
        TargetPlatform.macOS: NotebookPageTransitions(),
        TargetPlatform.windows: NotebookPageTransitions(),
        TargetPlatform.fuchsia: NotebookPageTransitions(),
      },
    ),
    textTheme: handwriting.copyWith(
      bodySmall: larger(handwriting.bodySmall, 3),
      bodyMedium: larger(handwriting.bodyMedium, 4),
      bodyLarge: larger(handwriting.bodyLarge, 4),
      titleMedium: larger(handwriting.titleMedium, 4),
      titleLarge: larger(handwriting.titleLarge, 4),
      labelSmall: larger(handwriting.labelSmall, 2),
      labelMedium: larger(handwriting.labelMedium, 3),
      labelLarge: larger(handwriting.labelLarge, 3),
    ),
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(backgroundColor: background, centerTitle: false),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: paper,
      foregroundColor: scheme.primary,
      elevation: 0,
      highlightElevation: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: background,
      indicatorColor: scheme.primaryContainer,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: .7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
