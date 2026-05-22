import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Go2-Parking — Relate-inspired Design System
/// Linen canvas #fcfcfc, Signal Blue #145aff accent, Inter font
/// Quiet, paper-like, professional — blue as highlighter not paint

class Go2Colors {
  // Surfaces
  static const Color canvas = Color(0xFFFCFCFC);        // Linen canvas
  static const Color skyWash = Color(0xFFF0F4FE);       // Subtle blue tint sections
  static const Color surface = Color(0xFFFFFFFF);       // Card surface
  static const Color background = Color(0xFFFCFCFC);    // Page background

  // Text
  static const Color textPrimary = Color(0xFF020520);   // Midnight ink
  static const Color textSecondary = Color(0xFF696A72); // Ash
  static const Color textHint = Color(0xFF95959B);      // Fog
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Brand
  static const Color primary = Color(0xFF145AFF);       // Signal blue
  static const Color primaryLight = Color(0xFF3B82F6);  // Hero blue
  static const Color primaryDark = Color(0xFF0F1F3D);   // Primary action accent

  // Accent (used sparingly)
  static const Color accent = Color(0xFF145AFF);
  static const Color accentLight = Color(0xFFB6CBFD);   // Periwinkle glow
  static const Color accentDark = Color(0xFF0F1F3D);

  // Semantic
  static const Color success = Color(0xFF16CA2E);       // Emerald status
  static const Color warning = Color(0xFFFFA64D);       // Amber tag
  static const Color warningLight = Color(0xFFFFF8E1);
  static const Color error = Color(0xFFF26052);         // Coral alert
  static const Color errorLight = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF0099FF);          // Azure info
  static const Color infoLight = Color(0xFFE3F2FD);

  // Structure
  static const Color divider = Color(0xFFE5E7EB);
  static const Color border = Color(0xFFCFCFCF);
  static const Color disabled = Color(0xFFBDBDBD);

  // Dark mode
  static const Color darkBg = Color(0xFF0F1219);
  static const Color darkSurface = Color(0xFF1A1F2E);
  static const Color darkCard = Color(0xFF232836);
  static const Color darkText = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
}

class Go2Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

class Go2Radius {
  static const double sm = 4;    // badges
  static const double md = 8;    // cards
  static const double lg = 12;   // buttons, inputs
  static const double xl = 16;   // images
  static const double xxl = 32;  // modals
  static const double full = 100; // pills
}

class Go2Theme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: Go2Colors.primary,
        secondary: Go2Colors.primary,
        surface: Go2Colors.surface,
        error: Go2Colors.error,
        onPrimary: Colors.white,
        onSurface: Go2Colors.textPrimary,
      ),
      scaffoldBackgroundColor: Go2Colors.canvas,
      appBarTheme: AppBarTheme(
        backgroundColor: Go2Colors.canvas,
        foregroundColor: Go2Colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Go2Colors.textPrimary,
          letterSpacing: -0.3,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Go2Colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Go2Radius.md),
          side: const BorderSide(color: Color(0xFFEEEEEE), width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Go2Colors.primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Go2Radius.lg),
          ),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Go2Colors.primaryDark,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          minimumSize: const Size(0, 44),
          side: const BorderSide(color: Go2Colors.primaryDark, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Go2Radius.lg),
          ),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Go2Colors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 36),
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Go2Colors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Go2Colors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Go2Radius.lg),
          borderSide: const BorderSide(color: Go2Colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Go2Radius.lg),
          borderSide: const BorderSide(color: Go2Colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Go2Radius.lg),
          borderSide: const BorderSide(color: Go2Colors.primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(color: Go2Colors.textHint, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: Go2Colors.textSecondary, fontSize: 14),
      ),
      textTheme: TextTheme(
        displaySmall: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w600, color: Go2Colors.textPrimary, letterSpacing: -0.76),
        headlineMedium: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600, color: Go2Colors.textPrimary, letterSpacing: -0.22),
        titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Go2Colors.textPrimary, letterSpacing: -0.16),
        titleMedium: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: Go2Colors.textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, color: Go2Colors.textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: Go2Colors.textSecondary),
        bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: Go2Colors.textHint),
        labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Go2Colors.textHint, letterSpacing: 0.13),
      ),
      dividerTheme: const DividerThemeData(color: Go2Colors.divider, thickness: 0.5),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Go2Colors.surface,
        selectedItemColor: Go2Colors.primary,
        unselectedItemColor: Go2Colors.textHint,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Go2Radius.md)),
        backgroundColor: Go2Colors.primaryDark,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Go2Colors.primaryLight,
        secondary: Go2Colors.primaryLight,
        surface: Go2Colors.darkSurface,
        error: Go2Colors.error,
        onPrimary: Colors.white,
        onSurface: Go2Colors.darkText,
      ),
      scaffoldBackgroundColor: Go2Colors.darkBg,
      appBarTheme: AppBarTheme(
        backgroundColor: Go2Colors.darkBg,
        foregroundColor: Go2Colors.darkText,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Go2Colors.darkText, letterSpacing: -0.3),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: Go2Colors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Go2Radius.md),
          side: const BorderSide(color: Color(0xFF2D3348), width: 0.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Go2Colors.primaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Go2Radius.lg)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Go2Colors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Go2Radius.lg),
          borderSide: const BorderSide(color: Color(0xFF2D3348)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Go2Radius.lg),
          borderSide: const BorderSide(color: Color(0xFF2D3348)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Go2Radius.lg),
          borderSide: const BorderSide(color: Go2Colors.primaryLight, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(color: Go2Colors.darkTextSecondary, fontSize: 14),
      ),
      textTheme: TextTheme(
        displaySmall: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w600, color: Go2Colors.darkText, letterSpacing: -0.76),
        headlineMedium: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600, color: Go2Colors.darkText, letterSpacing: -0.22),
        titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Go2Colors.darkText, letterSpacing: -0.16),
        titleMedium: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: Go2Colors.darkText),
        bodyLarge: GoogleFonts.inter(fontSize: 15, color: Go2Colors.darkText),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: Go2Colors.darkTextSecondary),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: Go2Colors.darkTextSecondary),
        labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Go2Colors.darkTextSecondary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Go2Colors.darkSurface,
        selectedItemColor: Go2Colors.primaryLight,
        unselectedItemColor: Go2Colors.darkTextSecondary,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF2D3348), thickness: 0.5),
    );
  }
}
