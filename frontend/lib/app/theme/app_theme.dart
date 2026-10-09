import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF236B3B);
  static const Color primaryLight = Color(0xFF4F9A62);
  static const Color primaryDark = Color(0xFF17482A);

  static const Color sage = Color(0xFFB8D8C0);
  static const Color mint = Color(0xFFE6F2E8);
  static const Color earth = Color(0xFF9A6A3A);
  static const Color accentAmber = Color(0xFFF2A93B);
  static const Color accentTeal = Color(0xFF168A7A);

  static const Color errorRed = Color(0xFFD64545);
  static const Color successGreen = Color(0xFF2E8B57);
  static const Color warningOrange = Color(0xFFE47A2E);

  static const Color backgroundLight = Color(0xFFF5F7F3);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF17231B);
  static const Color textSecondaryLight = Color(0xFF66736A);
  static const Color borderLight = Color(0xFFDCE5DD);

  static const Color backgroundDark = Color(0xFF0D1510);
  static const Color surfaceDark = Color(0xFF162019);
  static const Color surfaceDarkAlt = Color(0xFF1C2A20);
  static const Color textPrimaryDark = Color(0xFFF2F7F3);
  static const Color textSecondaryDark = Color(0xFFA7B6AB);
  static const Color borderDark = Color(0xFF2A3A2F);
}

class AppTheme {
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final surface = dark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textPrimary = dark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondary = dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final border = dark ? AppColors.borderDark : AppColors.borderLight;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: dark ? AppColors.primaryLight : AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: dark ? const Color(0xFF214D30) : AppColors.mint,
      onPrimaryContainer: dark
          ? const Color(0xFFD4EAD8)
          : AppColors.primaryDark,
      secondary: AppColors.accentTeal,
      onSecondary: Colors.white,
      secondaryContainer: dark
          ? const Color(0xFF16463F)
          : const Color(0xFFDDF2ED),
      onSecondaryContainer: dark
          ? const Color(0xFFC8EEE7)
          : const Color(0xFF0E4E46),
      tertiary: AppColors.accentAmber,
      onTertiary: dark ? Colors.black : Colors.white,
      tertiaryContainer: dark
          ? const Color(0xFF4A381D)
          : const Color(0xFFFFF0D2),
      onTertiaryContainer: dark
          ? const Color(0xFFFFE1A8)
          : const Color(0xFF6E4A13),
      error: AppColors.errorRed,
      onError: Colors.white,
      errorContainer: dark ? const Color(0xFF512323) : const Color(0xFFFCE3E3),
      onErrorContainer: dark
          ? const Color(0xFFFFD9D9)
          : const Color(0xFF7B2020),
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: (dark
              ? AppColors.surfaceDarkAlt
              : const Color(0xFFEDF3EE))
          .withValues(alpha: dark ? 0.78 : 0.84),
      onSurfaceVariant: textSecondary,
      outline: dark ? const Color(0xFF607064) : const Color(0xFF89968C),
      outlineVariant: border,
      inverseSurface: dark ? const Color(0xFFEAF1EB) : const Color(0xFF26332A),
      onInverseSurface: dark ? const Color(0xFF1A241D) : Colors.white,
      inversePrimary: dark ? AppColors.primary : AppColors.primaryLight,
      scrim: Colors.black,
    );

    final baseText = GoogleFonts.interTextTheme(
      dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: baseText.copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.7,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 25,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        headlineSmall: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          color: textPrimary,
          height: 1.45,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13.5,
          color: textSecondary,
          height: 1.45,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface.withValues(alpha: dark ? 0.78 : 0.84),
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface.withValues(alpha: dark ? 0.82 : 0.84),
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        margin: EdgeInsets.zero,
        shadowColor: dark
            ? colorScheme.primary.withValues(alpha: 0.14)
            : Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: dark ? colorScheme.primary.withValues(alpha: 0.28) : border,
            width: 1,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface.withValues(alpha: dark ? 0.94 : 0.96),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: dark
                ? colorScheme.primary.withValues(alpha: 0.28)
                : border,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface.withValues(alpha: dark ? 0.94 : 0.96),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: (dark ? AppColors.surfaceDarkAlt : const Color(0xFFF9FBF9))
            .withValues(alpha: dark ? 0.86 : 0.9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.7),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.errorRed, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.errorRed, width: 1.8),
        ),
        labelStyle: GoogleFonts.inter(color: textSecondary),
        hintStyle: GoogleFonts.inter(
          color: textSecondary.withValues(alpha: 0.72),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: surface.withValues(alpha: dark ? 0.86 : 0.9),
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface.withValues(alpha: dark ? 0.82 : 0.9),
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: textSecondary),
        selectedLabelTextStyle: GoogleFonts.inter(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: GoogleFonts.inter(
          color: textSecondary,
          fontWeight: FontWeight.w600,
        ),
        indicatorColor: colorScheme.primaryContainer,
        groupAlignment: -0.65,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: dark
            ? AppColors.surfaceDarkAlt
            : const Color(0xFFF0F5F0),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        circularTrackColor: colorScheme.primaryContainer,
      ),
    );
  }
}
