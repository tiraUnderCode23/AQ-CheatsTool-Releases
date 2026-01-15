import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AQ///bimmer Application Theme
/// Professional BMW diagnostic tool theming with glass morphism effects
class AppTheme {
  // Brand Colors
  static const Color primaryBlue = Color(0xFF3b82f6);
  static const Color secondaryRed = Color(0xFFef4444);
  static const Color accentCyan = Color(0xFF00ffd0);
  static const Color accentOrange = Color(0xFFFF6B35);

  // Background Colors
  static const Color darkBackground = Color(0xFF1a1a2e);
  static const Color cardBackground = Color(0xFF16213e);
  static const Color surfaceColor = Color(0xFF0f3460);
  static const Color dialogBackground = Color(0xFF2b3e50);

  // Glass Effect Colors
  static const Color glassBackground = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textMuted = Color(0xFF6B7280);

  // Status Colors
  static const Color successGreen = Color(0xFF22c55e);
  static const Color warningOrange = Color(0xFFf97316);
  static const Color errorRed = Color(0xFFef4444);
  static const Color infoBlue = Color(0xFF3b82f6);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryBlue, Color(0xFF1d4ed8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentCyan, primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [darkBackground, cardBackground],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x1AFFFFFF), Color(0x0DFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Box Shadows
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ];

  static List<BoxShadow> get glowShadow => [
        BoxShadow(
          color: primaryBlue.withOpacity(0.3),
          blurRadius: 20,
          spreadRadius: 2,
        ),
      ];

  // Border Radius
  static BorderRadius get cardRadius => BorderRadius.circular(16);
  static BorderRadius get buttonRadius => BorderRadius.circular(12);
  static BorderRadius get chipRadius => BorderRadius.circular(8);

  // Glass Decoration
  static BoxDecoration get glassDecoration => BoxDecoration(
        gradient: glassGradient,
        borderRadius: cardRadius,
        border: Border.all(color: glassBorder, width: 1),
        boxShadow: cardShadow,
      );

  // Dark Theme
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: primaryBlue,
        scaffoldBackgroundColor: darkBackground,

        // Color Scheme
        colorScheme: const ColorScheme.dark(
          primary: primaryBlue,
          secondary: accentCyan,
          error: errorRed,
          surface: cardBackground,
          onPrimary: textPrimary,
          onSecondary: textPrimary,
          onSurface: textPrimary,
        ),

        // App Bar Theme
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
          iconTheme: const IconThemeData(color: textPrimary),
        ),

        // Card Theme
        cardTheme: CardThemeData(
          color: cardBackground,
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: cardRadius),
        ),

        // Elevated Button Theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: textPrimary,
            elevation: 4,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: buttonRadius),
            textStyle: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Outlined Button Theme
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryBlue,
            side: const BorderSide(color: primaryBlue, width: 2),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: buttonRadius),
            textStyle: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Text Button Theme
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: accentCyan,
            textStyle: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // Input Decoration Theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: buttonRadius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: buttonRadius,
            borderSide: const BorderSide(color: glassBorder, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: buttonRadius,
            borderSide: const BorderSide(color: primaryBlue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: buttonRadius,
            borderSide: const BorderSide(color: errorRed, width: 1),
          ),
          hintStyle: GoogleFonts.cairo(color: textMuted),
          labelStyle: GoogleFonts.cairo(color: textSecondary),
        ),

        // Tab Bar Theme
        tabBarTheme: TabBarThemeData(
          labelColor: accentCyan,
          unselectedLabelColor: textSecondary,
          indicator: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: accentCyan, width: 3),
            ),
          ),
          labelStyle: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),

        // Dialog Theme
        dialogTheme: DialogThemeData(
          backgroundColor: dialogBackground,
          elevation: 16,
          shape: RoundedRectangleBorder(borderRadius: cardRadius),
          titleTextStyle: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
          contentTextStyle: GoogleFonts.cairo(
            fontSize: 14,
            color: textSecondary,
          ),
        ),

        // Snackbar Theme
        snackBarTheme: SnackBarThemeData(
          backgroundColor: cardBackground,
          contentTextStyle: GoogleFonts.cairo(color: textPrimary),
          shape: RoundedRectangleBorder(borderRadius: chipRadius),
          behavior: SnackBarBehavior.floating,
        ),

        // Floating Action Button Theme
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryBlue,
          foregroundColor: textPrimary,
          elevation: 8,
        ),

        // Progress Indicator Theme
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: accentCyan,
          linearTrackColor: surfaceColor,
        ),

        // Switch Theme
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accentCyan;
            return textMuted;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return accentCyan.withOpacity(0.3);
            }
            return surfaceColor;
          }),
        ),

        // Text Theme
        textTheme: TextTheme(
          displayLarge: GoogleFonts.cairo(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
          displayMedium: GoogleFonts.cairo(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
          displaySmall: GoogleFonts.cairo(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
          headlineLarge: GoogleFonts.cairo(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          headlineMedium: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          headlineSmall: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          titleLarge: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          titleMedium: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
          titleSmall: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textSecondary,
          ),
          bodyLarge: GoogleFonts.cairo(
            fontSize: 16,
            color: textPrimary,
          ),
          bodyMedium: GoogleFonts.cairo(
            fontSize: 14,
            color: textSecondary,
          ),
          bodySmall: GoogleFonts.cairo(
            fontSize: 12,
            color: textMuted,
          ),
          labelLarge: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          labelMedium: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textSecondary,
          ),
          labelSmall: GoogleFonts.cairo(
            fontSize: 10,
            color: textMuted,
          ),
        ),
      );
}

/// AQ Brand Colors helper class for easy access
class AQColors {
  AQColors._();

  // Primary Colors
  static const Color primary = AppTheme.primaryBlue;
  static const Color secondary = AppTheme.secondaryRed;
  static const Color accent = AppTheme.accentCyan;
  static const Color orange = AppTheme.accentOrange;

  // Background Colors
  static const Color background = AppTheme.darkBackground;
  static const Color card = AppTheme.cardBackground;
  static const Color surface = AppTheme.surfaceColor;
  static const Color dialog = AppTheme.dialogBackground;

  // Glass Effect
  static const Color glass = AppTheme.glassBackground;
  static const Color glassBorder = AppTheme.glassBorder;

  // Text Colors
  static const Color textPrimary = AppTheme.textPrimary;
  static const Color textSecondary = AppTheme.textSecondary;
  static const Color textMuted = AppTheme.textMuted;

  // Status Colors
  static const Color success = AppTheme.successGreen;
  static const Color warning = AppTheme.warningOrange;
  static const Color error = AppTheme.errorRed;
  static const Color info = AppTheme.infoBlue;

  // Gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1a1a2e),
      Color(0xFF16213e),
      Color(0xFF0f3460),
    ],
  );

  static const LinearGradient primaryGradient = AppTheme.primaryGradient;
  static const LinearGradient accentGradient = AppTheme.accentGradient;
  static const LinearGradient glassGradient = AppTheme.glassGradient;
}
