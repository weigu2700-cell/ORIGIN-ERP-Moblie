import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

class AppTokens {
  // 与 Web 管理端同一套品牌色：深青蓝主色 + 琥珀强调色。
  static const brand = Color(0xFF245B78),
      brandDeep = Color(0xFF18384B),
      brandMark = Color(0xFF203F54),
      brandSoft = Color(0xFFE6F1F4),
      accent = Color(0xFFD99A2B),
      ink = Color(0xFF162631),
      muted = Color(0xFF5E707B),
      canvas = Color(0xFFEEF3F5),
      line = Color(0xFFD7E2E7);
  static const page = 20.0, gap = 12.0, radius = 14.0;
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    splashFactory: NoSplash.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    scaffoldBackgroundColor: canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: brand,
      primary: brand,
      surface: Colors.white,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 15, color: ink),
      titleLarge: TextStyle(
        fontSize: 22,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: canvas,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(color: line, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFE3EBEE),
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(radius),
      ),
      contentPadding: const EdgeInsets.all(16),
      hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF8798A2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      minVerticalPadding: 12,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Color(0xF7FFFFFF),
      indicatorColor: Colors.transparent,
      height: 64,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected) ? brand : muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: states.contains(WidgetState.selected) ? brand : muted,
        ),
      ),
    ),
  );
}
