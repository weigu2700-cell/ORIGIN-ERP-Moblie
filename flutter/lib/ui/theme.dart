import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

class AppTokens {
  static const brand = Color(0xFF2C60E8),
      ink = Color(0xFF1C2536),
      muted = Color(0xFF536279),
      canvas = Color(0xFFF2F3F7),
      line = Color(0xFFE4E6EB);
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
      fillColor: const Color(0xFFE9EBF0),
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(radius),
      ),
      contentPadding: const EdgeInsets.all(16),
      hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF8A94A6)),
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
