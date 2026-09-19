import 'package:flutter/material.dart';

/// Pastel, iOS-inspired design system for Gestión Salón.
///
/// Palette rationale: mint reads as "money in", coral as "money out",
/// lavender as the neutral brand accent. All tones stay pastel so the
/// app feels soft and friendly, like a modern iOS finance app.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFF7F5FA);
  static const Color card = Colors.white;

  static const Color income = Color(0xFF8FDBC4); // pastel mint
  static const Color incomeDeep = Color(0xFF2F9E7D);

  static const Color expense = Color(0xFFFFB4BC); // pastel coral
  static const Color expenseDeep = Color(0xFFE2636E);

  static const Color accent = Color(0xFFC4B5E8); // pastel lavender
  static const Color accentDeep = Color(0xFF8B7BD8);

  static const Color goal = Color(0xFFF6D186); // pastel yellow
  static const Color info = Color(0xFFA8D8F0); // pastel blue

  static const Color textPrimary = Color(0xFF3A3740);
  static const Color textSecondary = Color(0xFF8E8A99);

  /// Rotation used for "expenses by category" pie sections.
  static const List<Color> categoryPalette = [
    Color(0xFFFFB4BC),
    Color(0xFF8FDBC4),
    Color(0xFFC4B5E8),
    Color(0xFFF6D186),
    Color(0xFFA8D8F0),
    Color(0xFFFFC9A3),
    Color(0xFFE3B7D9),
    Color(0xFFB5E8C3),
    Color(0xFFF4B8C8),
    Color(0xFFC9C2F0),
  ];

  static Color categoryColor(int index) =>
      categoryPalette[index % categoryPalette.length];
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        primary: AppColors.accentDeep,
        secondary: AppColors.incomeDeep,
        surface: AppColors.card,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0EDF7),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accentDeep, width: 1.4),
        ),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentDeep,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.accentDeep,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentDeep,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0xFFF0EDF7),
        selectedColor: AppColors.accent,
        labelStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      textTheme: base.textTheme
          .apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          )
          .copyWith(
            headlineSmall: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.textPrimary,
            ),
            titleLarge: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: AppColors.textPrimary,
            ),
            titleMedium: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: AppColors.textPrimary,
            ),
          ),
    );
  }
}
