import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors (Stitch)
  static const Color brandDefault = Color(0xFF89eb00);
  static const Color brandDark = Color(0xFF6ebc00);
  static const Color brandLight = Color(0xFFa6f040);

  // DEPRECATED: Legacy colors left for compilation until all screens are rewritten
  static const Color background = Color(0xFF111111);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color accent = Color(0xFF89eb00); // Mapped to brandDefault
  static const Color secondaryAccent = Color(0xFF00BFFF);
  static const Color cardColor = Color(0xFF222222);
  static const Color borderColor = Color(0xFF333333);
  static const Color textPrimary = Color(0xFFEEEEEE);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textMuted = Color(0xFF777777);
  static const Color warningAmber = Color(0xFFFFC107);
  static const Color errorRed = Color(0xFFFF5252);

  // Dark Mode
  static const Color darkBackground = Color(0xFF222222);
  static const Color darkSurface = Color(0xFF2e2e2e);
  static const Color darkBorder = Color(0x0DFFFFFF); // 5% white

  // Light Mode
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFf3f4f6);
  static const Color lightBorder = Color(0x0D000000); // 5% black

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: brandDefault,
      canvasColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: brandDefault,
        secondary: brandDark,
        surface: lightSurface,
        onSurface: Color(0xFF1a1a1a),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
        titleLarge: const TextStyle(color: Color(0xFF1a1a1a), fontWeight: FontWeight.bold),
        titleMedium: const TextStyle(color: Color(0xFF1a1a1a), fontWeight: FontWeight.w600),
        bodyLarge: const TextStyle(color: Color(0xFF1a1a1a)),
        bodyMedium: const TextStyle(color: Color(0xFF4b5563)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: Color(0xFF1a1a1a),
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightBackground,
        selectedItemColor: brandDark,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandDefault,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brandDefault,
        foregroundColor: Colors.black,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: lightBorder)),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: brandDefault, width: 2),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: brandDefault,
      canvasColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: brandDefault,
        secondary: brandLight,
        surface: darkSurface,
        onSurface: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        titleLarge: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        titleMedium: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        bodyLarge: const TextStyle(color: Colors.white),
        bodyMedium: const TextStyle(color: Colors.grey),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkBackground,
        selectedItemColor: brandDefault,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandDefault,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brandDefault,
        foregroundColor: Colors.black,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: darkBorder)),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: brandDefault, width: 2),
        ),
      ),
    );
  }
}
