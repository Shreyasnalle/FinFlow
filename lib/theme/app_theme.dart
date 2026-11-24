import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// FinFlow design system. Only four brand colors exist; everything else is a
/// tint (alpha blend) of those four plus pure white.
class AppTheme {
  // ── The palette ──
  static const Color blue = Color(0xFF3760F9);
  static const Color ink = Color(0xFF17161B);
  static const Color lime = Color(0xFFD2FC59);
  static const Color lavender = Color(0xFFDAD9FB);
  static const Color white = Color(0xFFFFFFFF);

  // ── Radii ──
  static const double radiusCard = 28;
  static const double radiusTile = 22;
  static const double radiusPill = 999;

  // ── Derived surfaces ──
  /// Very light lavender wash used for tiles/inputs on the light theme.
  static final Color lightSurface =
      Color.alphaBlend(lavender.withValues(alpha: 0.28), white);
  static final Color lightBorder = lavender.withValues(alpha: 0.7);

  /// Raised surface on the ink background.
  static final Color darkSurface =
      Color.alphaBlend(white.withValues(alpha: 0.07), ink);
  static final Color darkBorder = white.withValues(alpha: 0.10);

  static TextTheme _textTheme(Brightness b) {
    final base = b == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    final primary = b == Brightness.dark ? white : ink;
    final secondary = primary.withValues(alpha: 0.6);
    return GoogleFonts.urbanistTextTheme(base).copyWith(
      displayLarge: GoogleFonts.urbanist(fontSize: 44, fontWeight: FontWeight.w700, height: 1.1, color: primary),
      headlineLarge: GoogleFonts.urbanist(fontSize: 34, fontWeight: FontWeight.w700, height: 1.15, color: primary),
      headlineMedium: GoogleFonts.urbanist(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2, color: primary),
      titleLarge: GoogleFonts.urbanist(fontSize: 22, fontWeight: FontWeight.w700, color: primary),
      titleMedium: GoogleFonts.urbanist(fontSize: 17, fontWeight: FontWeight.w600, color: primary),
      bodyLarge: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w500, color: primary),
      bodyMedium: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w500, color: secondary),
      labelLarge: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w700, color: primary),
    );
  }

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final bg = dark ? ink : white;
    final surface = dark ? darkSurface : lightSurface;
    final border = dark ? darkBorder : lightBorder;
    final onBg = dark ? white : ink;

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      primaryColor: blue,
      colorScheme: ColorScheme(
        brightness: b,
        primary: dark ? lime : blue,
        onPrimary: dark ? ink : white,
        secondary: lime,
        onSecondary: ink,
        tertiary: lavender,
        onTertiary: ink,
        error: blue,
        onError: white,
        surface: surface,
        onSurface: onBg,
      ),
      textTheme: _textTheme(b),
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: onBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.urbanist(fontSize: 22, fontWeight: FontWeight.w700, color: onBg),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bg,
        selectedItemColor: dark ? lime : blue,
        unselectedItemColor: onBg.withValues(alpha: 0.4),
        selectedLabelStyle: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w600),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: dark ? lime : ink,
          foregroundColor: dark ? ink : white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          textStyle: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dark ? lime : blue,
          textStyle: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: lime,
        foregroundColor: ink,
        elevation: 0,
        shape: const CircleBorder(),
      ),
      cardTheme: CardThemeData(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: border),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: lime,
        labelStyle: GoogleFonts.urbanist(fontWeight: FontWeight.w600, color: onBg),
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: GoogleFonts.urbanist(color: onBg.withValues(alpha: 0.45), fontWeight: FontWeight.w500),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: dark ? lime : blue, width: 2),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusCard)),
      ),
    );
  }

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);
}

/// Context-aware palette access so screens never hard-code a color.
extension AppColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Page background.
  Color get bg => isDark ? AppTheme.ink : AppTheme.white;

  /// Tile / input / list-row surface.
  Color get surface => isDark ? AppTheme.darkSurface : AppTheme.lightSurface;

  Color get border => isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

  /// Main text and icons.
  Color get fg => isDark ? AppTheme.white : AppTheme.ink;

  /// Secondary text.
  Color get fgMuted => fg.withValues(alpha: 0.6);

  /// Faint text / disabled.
  Color get fgFaint => fg.withValues(alpha: 0.4);

  /// Accent used for links, active tab, small highlights (readable on bg).
  Color get accent => isDark ? AppTheme.lime : AppTheme.blue;

  /// Primary call-to-action fill (dark pill on light, lime pill on dark).
  Color get cta => isDark ? AppTheme.lime : AppTheme.ink;
  Color get onCta => isDark ? AppTheme.ink : AppTheme.white;

  /// Hero card (blue block like the reference's task counter).
  Color get hero => AppTheme.blue;

  /// Soft secondary card (lavender block).
  Color get soft => isDark ? AppTheme.lavender.withValues(alpha: 0.16) : AppTheme.lavender;
  Color get onSoft => isDark ? AppTheme.white : AppTheme.ink;
}
