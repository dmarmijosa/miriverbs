import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Stitch Kinetic Colors ────────────────────────────────────────────────
  static const Color primary = Color(0xFF0040E0);          // Electric Blue
  static const Color primaryDark = Color(0xFF002994);      // Electric Blue Darker (for 3D edge)
  static const Color primaryLight = Color(0xFFB8C3FF);
  
  static const Color secondary = Color(0xFFFDD400);        // Sunflower Yellow
  static const Color secondaryDark = Color(0xFFC7A500);    // Sunflower Yellow Darker (for 3D edge)
  
  static const Color tertiary = Color(0xFF2ECC71);         // Soft Mint Green
  static const Color tertiaryDark = Color(0xFF229954);     // Soft Mint Green Darker (for 3D edge)
  static const Color success = tertiary;
  static const Color successDark = tertiaryDark;

  static const Color error = Color(0xFFBA1A1A);
  static const Color errorDark = Color(0xFF93000A);
  
  static const Color background = Color(0xFFF6FAFE);       // Off-White background
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFD6DADE);
  static const Color surfaceContainer = Color(0xFFEAEEF2);
  
  static const Color onBackground = Color(0xFF171C1F);     // Cool Dark Slate
  static const Color onSurface = Color(0xFF171C1F);
  static const Color onSurfaceVariant = Color(0xFF434656);
  static const Color outline = Color(0xFFC4C5D9);

  // ── Stitch Typography ────────────────────────────────────────────────────
  static TextStyle get displayLg => GoogleFonts.rubik(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.8,
        color: onBackground,
      );

  static TextStyle get headlineLg => GoogleFonts.rubik(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: onBackground,
      );

  static TextStyle get headlineMd => GoogleFonts.rubik(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: onBackground,
      );

  static TextStyle get bodyLg => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: onBackground,
      );

  static TextStyle get bodyMd => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: onBackground,
      );

  static TextStyle get labelLg => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: onBackground,
      );

  static TextStyle get labelMd => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: onBackground,
      );

  // ── Stitch Shapes ────────────────────────────────────────────────────────
  static const double radiusSmall = 4.0;
  static const double radiusDefault = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;   // Custom container soft squircle
  static const double radiusXLarge = 24.0;  // Modal sheets / Dialogs
  static const double radiusExtraLarge = 24.0;
  static const double radiusFull = 9999.0;  // Pill buttons

  // ── Global ThemeData ─────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        error: error,
        surface: surface,
        onSurface: onSurface,
      ),
      textTheme: TextTheme(
        displayLarge: displayLg,
        headlineLarge: headlineLg,
        headlineMedium: headlineMd,
        bodyLarge: bodyLg,
        bodyMedium: bodyMd,
        labelLarge: labelLg,
        labelMedium: labelMd,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: surfaceContainer, width: 1.5),
        ),
      ),
    );
  }
}
