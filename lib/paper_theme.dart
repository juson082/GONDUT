import 'package:flutter/material.dart';

const themeColors = <String, (String, Color)>{
  'lavender': ('라벤더', Color(0xffded3f4)),
  'rose': ('장미', Color(0xfff4d3df)),
  'peach': ('복숭아', Color(0xffffdfcf)),
  'sage': ('세이지', Color(0xffd3ebdc)),
  'sky': ('하늘', Color(0xffd3eaf7)),
  'sand': ('샌드', Color(0xfff4e8cd)),
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
