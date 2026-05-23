import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Main palette - dark gaming UI with vibrant accents
  static const primary = Color(0xFF7C4DFF);      // Vibrant violet
  static const secondary = Color(0xFFB388FF);    // Light violet
  static const accent = Color(0xFFFF4081);       // Vibrant pink
  static const warning = Color(0xFFFFD740);      // Bright amber

  // Section colors
  static const algorithm = Color(0xFFB388FF);    // Light violet
  static const mental = Color(0xFF7C4DFF);       // Violet
  static const sumoGame = Color(0xFFFF4081);     // Pink

  // Decomposition colors
  static const thousands = Color(0xFF7C4DFF);    // Violet
  static const hundreds = Color(0xFFFF9100);     // Orange
  static const tens = Color(0xFF00E676);         // Green neon
  static const units = Color(0xFFE040FB);         // Pink-magenta

  // Neutrals - dark purple theme
  static const background = Color(0xFF0A0714);
  static const surface = Color(0xFF120E1E);
  static const surfaceLight = Color(0xFF1E1830);
  static const textPrimary = Color(0xFFF0F0F0);
  static const textSecondary = Color(0xFF8B95A8);
  static const textLight = Color(0xFF4A5568);

  // Feedback
  static const correct = Color(0xFF00E676);
  static const incorrect = Color(0xFFFF4081);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.orbitronTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.orbitron(
          fontSize: 48,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        displayMedium: GoogleFonts.orbitron(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        headlineLarge: GoogleFonts.orbitron(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        headlineMedium: GoogleFonts.orbitron(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.orbitron(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.orbitron(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        labelLarge: GoogleFonts.orbitron(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: AppColors.surface,
      ),
    );
  }
}
