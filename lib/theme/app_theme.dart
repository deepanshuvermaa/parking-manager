import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Go2-Parking — Meadow Green Professional Theme
/// Fresh, approachable, tier 2/3 India friendly

class Go2Colors {
  // Brand - Meadow Green
  static const Color primary = Color(0xFF2E7D32);       // Forest green
  static const Color primaryLight = Color(0xFF4CAF50);  // Bright green
  static const Color primaryDark = Color(0xFF1B5E20);   // Deep green
  
  // Accent - Warm amber
  static const Color accent = Color(0xFFF9A825);        // Golden yellow
  static const Color accentLight = Color(0xFFFDD835);
  static const Color accentDark = Color(0xFFF57F17);

  // Semantic
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFFA726);
  static const Color warningLight = Color(0xFFFFF8E1);
  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF1E88E5);
  static const Color infoLight = Color(0xFFE3F2FD);

  // Surfaces
  static const Color background = Color(0xFFF5F9F5);    // Very light green tint
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color disabled = Color(0xFFBDBDBD);

  // Text
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF616161);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFF212121);
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
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 18;
  static const double xxl = 22;
  static const double full = 999;
}

class Go2Theme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Go2Colors.primary,
        primary: Go2Colors.primary,
        secondary: Go2Colors.accent,
        surface: Go2Colors.surface,
        error: Go2Colors.error,
      ),
      scaffoldBackgroundColor: Go2Colors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: Go2Colors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: Go2Colors.card,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Go2Radius.md),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Go2Colors.primary,
          foregroundColor: Colors.white,
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          minimumSize: const Size(0, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Go2Radius.sm),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Go2Colors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          minimumSize: const Size(0, 42),
          side: const BorderSide(color: Go2Colors.primary, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Go2Radius.sm),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Go2Colors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 36),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Go2Colors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Go2Radius.sm),
          borderSide: const BorderSide(color: Go2Colors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Go2Radius.sm),
          borderSide: const BorderSide(color: Go2Colors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Go2Radius.sm),
          borderSide: const BorderSide(color: Go2Colors.primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(color: Go2Colors.textHint, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: Go2Colors.textSecondary, fontSize: 14),
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displaySmall: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: Go2Colors.textPrimary),
        headlineMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Go2Colors.textPrimary),
        titleLarge: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: Go2Colors.textPrimary),
        titleMedium: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Go2Colors.textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 15, color: Go2Colors.textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 13, color: Go2Colors.textSecondary),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: Go2Colors.textHint),
        labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Go2Colors.textHint),
      ),
      dividerTheme: const DividerThemeData(color: Go2Colors.divider, thickness: 0.8),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Go2Colors.primary,
        unselectedItemColor: Go2Colors.textHint,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Go2Radius.sm)),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Go2Colors.primaryLight,
        brightness: Brightness.dark,
        primary: Go2Colors.primaryLight,
        secondary: Go2Colors.accent,
      ),
      scaffoldBackgroundColor: const Color(0xFF1A1A1A),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF222222),
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF2A2A2A),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Go2Radius.md)),
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
    );
  }
}
