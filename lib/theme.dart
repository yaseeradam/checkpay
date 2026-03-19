import 'package:flutter/material.dart';

// ── Brand colors extracted from logo (android-chrome-512x512.png) ──
const kPrimary    = Color(0xFF335BBD); // logo blue
const kPrimaryDark  = Color(0xFF1E3D8F); // darker shade for gradients
const kPrimaryLight = Color(0xFF5B7FD4); // lighter shade for accents
const kAccent     = Color(0xFF4A6FD4); // mid blue accent

const kBackground = Color(0xFFF4F6FB); // very light blue-tinted bg
const kSlate900   = Color(0xFF0F172A);
const kSlate500   = Color(0xFF64748B);
const kSlate400   = Color(0xFF94A3B8);
const kSlate100   = Color(0xFFEEF2FF); // blue-tinted light

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimary,
      primary: kPrimary,
      surface: kBackground,
    ),
    scaffoldBackgroundColor: kBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: kSlate900,
      ),
      iconTheme: IconThemeData(color: kSlate900),
    ),
  );
}

TextStyle ts(double size, FontWeight weight, Color color, {double? letterSpacing, double? height}) {
  return TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}
