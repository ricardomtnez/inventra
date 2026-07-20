import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  // ── RADIOS ────────────────────────────────────────────────────────────────
  static const double radiusXs = 6.0;
  static const double radiusSm = 10.0;
  static const double radiusMd = 14.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 28.0;

  // ── INPUT DECORATION ──────────────────────────────────────────────────────
  static InputDecorationTheme _inputDecorationTheme(bool isDark) {
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.bgDarkTertiary : AppColors.bgLightTertiary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(
        fontFamily: 'Inter',
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      hintStyle: TextStyle(
        fontFamily: 'Inter',
        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
        fontSize: 14,
      ),
      prefixIconColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      suffixIconColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(
          color: isDark ? AppColors.bgDarkBorder : AppColors.bgLightBorder,
          width: 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(
          color: isDark ? AppColors.accentTeal : AppColors.accentTealLight,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: AppColors.accentRed, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: AppColors.accentRed, width: 1.5),
      ),
      errorStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        color: AppColors.accentRed,
      ),
    );
  }

  // ── ELEVATED BUTTON ───────────────────────────────────────────────────────
  static ElevatedButtonThemeData _elevatedButtonTheme(bool isDark) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: isDark ? AppColors.accentTeal : AppColors.accentTealLight,
        foregroundColor: const Color(0xFF001F1A),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle: AppTextStyles.buttonLg,
      ),
    );
  }

  // ── OUTLINED BUTTON ───────────────────────────────────────────────────────
  static OutlinedButtonThemeData _outlinedButtonTheme(bool isDark) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        side: BorderSide(
          color: isDark ? AppColors.bgDarkBorder : AppColors.bgLightBorder,
          width: 1.0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle: AppTextStyles.buttonMd,
      ),
    );
  }

  // ── TEXT BUTTON ───────────────────────────────────────────────────────────
  static TextButtonThemeData _textButtonTheme(bool isDark) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: isDark ? AppColors.accentTeal : AppColors.accentTealLight,
        textStyle: AppTextStyles.labelLg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
    );
  }

  // ── FAB ──────────────────────────────────────────────────────────────────
  static FloatingActionButtonThemeData _fabTheme(bool isDark) {
    return FloatingActionButtonThemeData(
      backgroundColor: isDark ? AppColors.accentTeal : AppColors.accentTealLight,
      foregroundColor: const Color(0xFF001F1A),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
    );
  }

  // ── CARD ──────────────────────────────────────────────────────────────────
  static CardThemeData _cardTheme(bool isDark) {
    return CardThemeData(
      color: isDark ? AppColors.bgDarkSecondary : AppColors.bgLightSecondary,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusLg)),
        side: BorderSide(
          color: isDark ? AppColors.bgDarkBorder : AppColors.bgLightBorder,
          width: 1.0,
        ),
      ),
    );
  }

  // ── APP BAR ───────────────────────────────────────────────────────────────
  static AppBarTheme _appBarTheme(bool isDark) {
    return AppBarTheme(
      backgroundColor: isDark ? AppColors.bgDarkSecondary : AppColors.bgLightSecondary,
      foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: AppTextStyles.headlineMd.copyWith(
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
      iconTheme: IconThemeData(
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        size: 22,
      ),
      actionsIconTheme: IconThemeData(
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        size: 22,
      ),
    );
  }

  // ── SNACKBAR ──────────────────────────────────────────────────────────────
  static SnackBarThemeData _snackBarTheme(bool isDark) {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? const Color(0xFF1E3040) : const Color(0xFF0A1A24),
      contentTextStyle: AppTextStyles.bodyMd.copyWith(
        color: AppColors.textPrimaryDark,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        side: const BorderSide(color: AppColors.bgDarkBorder, width: 1),
      ),
      actionTextColor: AppColors.accentTeal,
    );
  }

  // ── CHIP ──────────────────────────────────────────────────────────────────
  static ChipThemeData _chipTheme(bool isDark) {
    return ChipThemeData(
      backgroundColor: isDark ? AppColors.bgDarkTertiary : AppColors.bgLightTertiary,
      selectedColor: isDark ? AppColors.accentTealDim : const Color(0xFFB2DFDB),
      labelStyle: AppTextStyles.labelMd.copyWith(
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      ),
      side: BorderSide(
        color: isDark ? AppColors.bgDarkBorder : AppColors.bgLightBorder,
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }

  // ── DIALOG ────────────────────────────────────────────────────────────────
  static DialogThemeData _dialogTheme(bool isDark) {
    return DialogThemeData(
      backgroundColor: isDark ? AppColors.bgDarkSecondary : AppColors.bgLightSecondary,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusXl),
        side: BorderSide(
          color: isDark ? AppColors.bgDarkBorder : AppColors.bgLightBorder,
          width: 1,
        ),
      ),
      titleTextStyle: AppTextStyles.headlineMd.copyWith(
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
      contentTextStyle: AppTextStyles.bodyMd.copyWith(
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      ),
    );
  }

  // ── DIVIDER ───────────────────────────────────────────────────────────────
  static DividerThemeData _dividerTheme(bool isDark) {
    return DividerThemeData(
      color: isDark ? AppColors.bgDarkBorder : AppColors.bgLightBorder,
      thickness: 1,
      space: 1,
    );
  }

  // ── LIST TILE ─────────────────────────────────────────────────────────────
  static ListTileThemeData _listTileTheme(bool isDark) {
    return ListTileThemeData(
      tileColor: Colors.transparent,
      titleTextStyle: AppTextStyles.titleMd.copyWith(
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
      subtitleTextStyle: AppTextStyles.bodySm.copyWith(
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      ),
      iconColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
    );
  }

  // ── BOTTOM SHEET ──────────────────────────────────────────────────────────
  static BottomSheetThemeData _bottomSheetTheme(bool isDark) {
    return BottomSheetThemeData(
      backgroundColor: isDark ? AppColors.bgDarkSecondary : AppColors.bgLightSecondary,
      modalBackgroundColor: isDark ? AppColors.bgDarkSecondary : AppColors.bgLightSecondary,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    );
  }

  // ── POPUP MENU ────────────────────────────────────────────────────────────
  static PopupMenuThemeData _popupMenuTheme(bool isDark) {
    return PopupMenuThemeData(
      color: isDark ? AppColors.bgDarkSecondary : AppColors.bgLightSecondary,
      elevation: 4,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        side: BorderSide(
          color: isDark ? AppColors.bgDarkBorder : AppColors.bgLightBorder,
          width: 1,
        ),
      ),
      textStyle: AppTextStyles.bodyMd.copyWith(
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
    );
  }

  // ── PROGRESS INDICATOR ────────────────────────────────────────────────────
  static ProgressIndicatorThemeData _progressIndicatorTheme(bool isDark) {
    return const ProgressIndicatorThemeData(
      color: AppColors.accentTeal,
      linearTrackColor: AppColors.bgDarkBorder,
    );
  }

  // ── CHECKBOX ─────────────────────────────────────────────────────────────
  static CheckboxThemeData _checkboxTheme(bool isDark) {
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return isDark ? AppColors.accentTeal : AppColors.accentTealLight;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(const Color(0xFF001F1A)),
      side: BorderSide(
        color: isDark ? AppColors.bgDarkBorder : AppColors.bgLightBorder,
        width: 1.5,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
  }

  // ── SWITCH ────────────────────────────────────────────────────────────────
  static SwitchThemeData _switchTheme(bool isDark) {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return isDark ? AppColors.accentTeal : AppColors.accentTealLight;
        }
        return isDark ? AppColors.bgDarkBorder : AppColors.bgLightBorder;
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );
  }

  // ── ICON BUTTON ───────────────────────────────────────────────────────────
  static IconButtonThemeData _iconButtonTheme(bool isDark) {
    return IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
      ),
    );
  }

  // ── FULL DARK THEME ───────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    const brightness = Brightness.dark;
    const isDark = true;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.dark(
        brightness: brightness,
        primary: AppColors.accentTeal,
        onPrimary: Color(0xFF001F1A),
        primaryContainer: AppColors.accentTealDim,
        onPrimaryContainer: AppColors.accentTeal,
        secondary: AppColors.accentAmber,
        onSecondary: Color(0xFF1A0F00),
        secondaryContainer: AppColors.accentAmberDim,
        onSecondaryContainer: AppColors.accentAmber,
        error: AppColors.accentRed,
        onError: Colors.white,
        surface: AppColors.bgDarkSecondary,
        onSurface: AppColors.textPrimaryDark,
        onSurfaceVariant: AppColors.textSecondaryDark,
        outline: AppColors.bgDarkBorder,
        outlineVariant: AppColors.bgDarkBorder,
        shadow: Colors.black,
        scrim: Colors.black87,
        inverseSurface: AppColors.textPrimaryDark,
        onInverseSurface: AppColors.bgDark,
        inversePrimary: AppColors.accentTealLight,
      ),
      scaffoldBackgroundColor: AppColors.bgDark,
      textTheme: _buildTextTheme(isDark),
      cardTheme: _cardTheme(isDark),
      appBarTheme: _appBarTheme(isDark),
      inputDecorationTheme: _inputDecorationTheme(isDark),
      elevatedButtonTheme: _elevatedButtonTheme(isDark),
      outlinedButtonTheme: _outlinedButtonTheme(isDark),
      textButtonTheme: _textButtonTheme(isDark),
      floatingActionButtonTheme: _fabTheme(isDark),
      snackBarTheme: _snackBarTheme(isDark),
      chipTheme: _chipTheme(isDark),
      dialogTheme: _dialogTheme(isDark),
      dividerTheme: _dividerTheme(isDark),
      listTileTheme: _listTileTheme(isDark),
      bottomSheetTheme: _bottomSheetTheme(isDark),
      popupMenuTheme: _popupMenuTheme(isDark),
      progressIndicatorTheme: _progressIndicatorTheme(isDark),
      checkboxTheme: _checkboxTheme(isDark),
      switchTheme: _switchTheme(isDark),
      iconButtonTheme: _iconButtonTheme(isDark),
      splashColor: AppColors.accentTealGlow,
      highlightColor: AppColors.accentTealGlow,
      iconTheme: const IconThemeData(color: AppColors.textSecondaryDark, size: 22),
    );
  }

  // ── FULL LIGHT THEME ──────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    const brightness = Brightness.light;
    const isDark = false;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.light(
        brightness: brightness,
        primary: AppColors.accentTealLight,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFB2DFDB),
        onPrimaryContainer: Color(0xFF00352D),
        secondary: Color(0xFFE65100),
        onSecondary: Colors.white,
        error: AppColors.accentRedLight,
        onError: Colors.white,
        surface: AppColors.bgLightSecondary,
        onSurface: AppColors.textPrimaryLight,
        onSurfaceVariant: AppColors.textSecondaryLight,
        outline: AppColors.bgLightBorder,
      ),
      scaffoldBackgroundColor: AppColors.bgLight,
      textTheme: _buildTextTheme(isDark),
      cardTheme: _cardTheme(isDark),
      appBarTheme: _appBarTheme(isDark),
      inputDecorationTheme: _inputDecorationTheme(isDark),
      elevatedButtonTheme: _elevatedButtonTheme(isDark),
      outlinedButtonTheme: _outlinedButtonTheme(isDark),
      textButtonTheme: _textButtonTheme(isDark),
      floatingActionButtonTheme: _fabTheme(isDark),
      snackBarTheme: _snackBarTheme(isDark),
      chipTheme: _chipTheme(isDark),
      dialogTheme: _dialogTheme(isDark),
      dividerTheme: _dividerTheme(isDark),
      listTileTheme: _listTileTheme(isDark),
      bottomSheetTheme: _bottomSheetTheme(isDark),
      popupMenuTheme: _popupMenuTheme(isDark),
      progressIndicatorTheme: _progressIndicatorTheme(isDark),
      checkboxTheme: _checkboxTheme(isDark),
      switchTheme: _switchTheme(isDark),
      iconButtonTheme: _iconButtonTheme(isDark),
      splashColor: const Color(0x1500897B),
      highlightColor: const Color(0x0D00897B),
      iconTheme: const IconThemeData(color: AppColors.textSecondaryLight, size: 22),
    );
  }

  // ── TEXT THEME ────────────────────────────────────────────────────────────
  static TextTheme _buildTextTheme(bool isDark) {
    final primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return TextTheme(
      displayLarge: AppTextStyles.display.copyWith(color: primary),
      displayMedium: AppTextStyles.displaySm.copyWith(color: primary),
      displaySmall: AppTextStyles.headlineLg.copyWith(color: primary),
      headlineLarge: AppTextStyles.headlineLg.copyWith(color: primary),
      headlineMedium: AppTextStyles.headlineMd.copyWith(color: primary),
      headlineSmall: AppTextStyles.headlineSm.copyWith(color: primary),
      titleLarge: AppTextStyles.titleLg.copyWith(color: primary),
      titleMedium: AppTextStyles.titleMd.copyWith(color: primary),
      titleSmall: AppTextStyles.labelLg.copyWith(color: secondary),
      bodyLarge: AppTextStyles.bodyLg.copyWith(color: primary),
      bodyMedium: AppTextStyles.bodyMd.copyWith(color: primary),
      bodySmall: AppTextStyles.bodySm.copyWith(color: secondary),
      labelLarge: AppTextStyles.labelLg.copyWith(color: primary),
      labelMedium: AppTextStyles.labelMd.copyWith(color: secondary),
      labelSmall: AppTextStyles.caption.copyWith(color: secondary),
    );
  }
}
