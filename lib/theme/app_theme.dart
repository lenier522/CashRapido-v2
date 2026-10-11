import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  // ===========================================================================
  // LIGHT THEME
  // ===========================================================================

  static ThemeData get light {
    final ColorScheme colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,

      secondary: AppColors.secondary,
      onSecondary: Colors.white,

      surface: AppColors.surfaceLight,
      onSurface: AppColors.textPrimary,

      surfaceContainerHighest: AppColors.surfaceVariantLight,

      error: AppColors.error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,

      brightness: Brightness.light,

      colorScheme: colorScheme,

      fontFamily: AppTypography.fontFamily,

      textTheme: AppTypography.light,

      scaffoldBackgroundColor: AppColors.backgroundLight,

      canvasColor: AppColors.backgroundLight,

      cardColor: AppColors.surfaceLight,

      dividerColor: AppColors.dividerLight,

      // -----------------------------------------------------------------------
      // APP BAR
      // -----------------------------------------------------------------------
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,

        titleTextStyle: AppTypography.light.titleLarge?.copyWith(
          color: AppColors.textPrimary,
        ),

        iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 24),
      ),

      // -----------------------------------------------------------------------
      // CARD
      // -----------------------------------------------------------------------
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
      ),

      // -----------------------------------------------------------------------
      // INPUTS
      // -----------------------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariantLight,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 16,
        ),

        border: OutlineInputBorder(
          borderRadius: AppRadius.radiusLg,
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusLg,
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusLg,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusLg,
          borderSide: const BorderSide(color: AppColors.error),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusLg,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),

        labelStyle: AppTypography.light.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),

        floatingLabelStyle: AppTypography.light.bodyMedium?.copyWith(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w600,
        ),

        hintStyle: AppTypography.light.bodyMedium?.copyWith(
          color: AppColors.textTertiary,
        ),

        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
      ),

      // -----------------------------------------------------------------------
      // ELEVATED BUTTON
      // -----------------------------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,

          minimumSize: const Size(double.infinity, 52),

          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.lg,
          ),

          shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),

          textStyle: AppTypography.light.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // FILLED BUTTON
      // -----------------------------------------------------------------------
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,

          minimumSize: const Size(double.infinity, 52),

          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.lg,
          ),

          shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),

          textStyle: AppTypography.light.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // OUTLINED BUTTON
      // -----------------------------------------------------------------------
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,

          minimumSize: const Size(double.infinity, 52),

          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.lg,
          ),

          shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),

          side: const BorderSide(color: AppColors.primary, width: 1.2),

          textStyle: AppTypography.light.labelLarge?.copyWith(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // TEXT BUTTON
      // -----------------------------------------------------------------------
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDark,

          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),

          shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),

          textStyle: AppTypography.light.labelLarge?.copyWith(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // ICON BUTTON
      // -----------------------------------------------------------------------
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimary,

          shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
        ),
      ),

      // -----------------------------------------------------------------------
      // FLOATING ACTION BUTTON
      // -----------------------------------------------------------------------
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,

        elevation: 4,
        focusElevation: 6,
        hoverElevation: 6,
        highlightElevation: 8,

        shape: const CircleBorder(),

        extendedTextStyle: AppTypography.light.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),

      // -----------------------------------------------------------------------
      // CHIP
      // -----------------------------------------------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariantLight,
        selectedColor: AppColors.primaryLight,

        disabledColor: AppColors.surfaceVariantLight,

        side: BorderSide.none,

        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),

        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),

        labelStyle: AppTypography.light.labelMedium?.copyWith(
          color: AppColors.textSecondary,
        ),

        secondaryLabelStyle: AppTypography.light.labelMedium?.copyWith(
          color: AppColors.primaryDark,
        ),
      ),

      // -----------------------------------------------------------------------
      // DIALOG
      // -----------------------------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,

        surfaceTintColor: Colors.transparent,

        elevation: 8,

        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXxl),

        titleTextStyle: AppTypography.light.headlineSmall,

        contentTextStyle: AppTypography.light.bodyMedium,
      ),

      // -----------------------------------------------------------------------
      // BOTTOM SHEET
      // -----------------------------------------------------------------------
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight,
        modalBackgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,

        elevation: 12,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxxl),
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // SNACKBAR
      // -----------------------------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppTypography.light.bodyMedium?.copyWith(
          color: Colors.white,
        ),

        behavior: SnackBarBehavior.floating,

        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),

        elevation: 6,

        insetPadding: const EdgeInsets.all(AppSpacing.lg),
      ),

      // -----------------------------------------------------------------------
      // SWITCH
      // -----------------------------------------------------------------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }

          return AppColors.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }

          return AppColors.borderLight;
        }),
      ),

      // -----------------------------------------------------------------------
      // PROGRESS INDICATOR
      // -----------------------------------------------------------------------
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primaryLight,
      ),

      // -----------------------------------------------------------------------
      // DIVIDER
      // -----------------------------------------------------------------------
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
        thickness: 1,
        space: 1,
      ),

      // -----------------------------------------------------------------------
      // NAVIGATION BAR
      // -----------------------------------------------------------------------
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,

        elevation: 0,

        height: 72,

        indicatorColor: AppColors.primaryLight,

        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          final bool selected = states.contains(WidgetState.selected);

          return AppTypography.light.labelSmall?.copyWith(
            color: selected ? AppColors.primaryDark : AppColors.textTertiary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),

        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
          final bool selected = states.contains(WidgetState.selected);

          return IconThemeData(
            color: selected ? AppColors.primaryDark : AppColors.textTertiary,
            size: 24,
          );
        }),
      ),

      // -----------------------------------------------------------------------
      // LIST TILE
      // -----------------------------------------------------------------------
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,

        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),

        titleTextStyle: AppTypography.light.titleMedium,

        subtitleTextStyle: AppTypography.light.bodySmall,
      ),

      // -----------------------------------------------------------------------
      // PAGE TRANSITIONS
      // -----------------------------------------------------------------------
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ===========================================================================
  // DARK THEME
  // ===========================================================================

  static ThemeData get dark {
    final ColorScheme colorScheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.backgroundDark,

      secondary: AppColors.secondary,
      onSecondary: AppColors.backgroundDark,

      surface: AppColors.surfaceDark,
      onSurface: AppColors.textPrimaryDark,

      surfaceContainerHighest: AppColors.surfaceDark3,

      error: AppColors.error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,

      brightness: Brightness.dark,

      colorScheme: colorScheme,

      fontFamily: AppTypography.fontFamily,

      textTheme: AppTypography.dark,

      scaffoldBackgroundColor: AppColors.backgroundDark,

      canvasColor: AppColors.backgroundDark,

      cardColor: AppColors.surfaceDark,

      dividerColor: AppColors.dividerDark,

      // -----------------------------------------------------------------------
      // APP BAR
      // -----------------------------------------------------------------------
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textPrimaryDark,

        elevation: 0,
        scrolledUnderElevation: 0,

        centerTitle: false,

        titleTextStyle: AppTypography.dark.titleLarge?.copyWith(
          color: AppColors.textPrimaryDark,
        ),

        iconTheme: const IconThemeData(
          color: AppColors.textPrimaryDark,
          size: 24,
        ),
      ),

      // -----------------------------------------------------------------------
      // CARD
      // -----------------------------------------------------------------------
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,

        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
      ),

      // -----------------------------------------------------------------------
      // INPUTS
      // -----------------------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark2,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 16,
        ),

        border: OutlineInputBorder(
          borderRadius: AppRadius.radiusLg,
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusLg,
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusLg,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusLg,
          borderSide: const BorderSide(color: AppColors.error),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusLg,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),

        labelStyle: AppTypography.dark.bodyMedium?.copyWith(
          color: AppColors.textSecondaryDark,
        ),

        floatingLabelStyle: AppTypography.dark.bodyMedium?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),

        hintStyle: AppTypography.dark.bodyMedium?.copyWith(
          color: AppColors.textTertiaryDark,
        ),

        prefixIconColor: AppColors.textSecondaryDark,
        suffixIconColor: AppColors.textSecondaryDark,
      ),

      // -----------------------------------------------------------------------
      // BUTTONS
      // -----------------------------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,

          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.backgroundDark,

          minimumSize: const Size(double.infinity, 52),

          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.lg,
          ),

          shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),

          textStyle: AppTypography.dark.labelLarge?.copyWith(
            color: AppColors.backgroundDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,

          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.backgroundDark,

          minimumSize: const Size(double.infinity, 52),

          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.lg,
          ),

          shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),

          textStyle: AppTypography.dark.labelLarge?.copyWith(
            color: AppColors.backgroundDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,

          minimumSize: const Size(double.infinity, 52),

          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.lg,
          ),

          shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),

          side: const BorderSide(color: AppColors.primary, width: 1.2),

          textStyle: AppTypography.dark.labelLarge?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,

          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),

          shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),

          textStyle: AppTypography.dark.labelLarge?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // ICON BUTTON
      // -----------------------------------------------------------------------
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimaryDark,

          shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
        ),
      ),

      // -----------------------------------------------------------------------
      // FAB
      // -----------------------------------------------------------------------
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.backgroundDark,

        elevation: 4,
        focusElevation: 6,
        hoverElevation: 6,
        highlightElevation: 8,

        shape: const CircleBorder(),

        extendedTextStyle: AppTypography.dark.labelLarge?.copyWith(
          color: AppColors.backgroundDark,
          fontWeight: FontWeight.w700,
        ),
      ),

      // -----------------------------------------------------------------------
      // CHIP
      // -----------------------------------------------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceDark2,
        selectedColor: const Color(0xFF164E32),

        disabledColor: AppColors.surfaceDark2,

        side: BorderSide.none,

        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),

        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),

        labelStyle: AppTypography.dark.labelMedium?.copyWith(
          color: AppColors.textSecondaryDark,
        ),

        secondaryLabelStyle: AppTypography.dark.labelMedium?.copyWith(
          color: AppColors.primary,
        ),
      ),

      // -----------------------------------------------------------------------
      // DIALOG
      // -----------------------------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,

        surfaceTintColor: Colors.transparent,

        elevation: 8,

        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXxl),

        titleTextStyle: AppTypography.dark.headlineSmall,

        contentTextStyle: AppTypography.dark.bodyMedium,
      ),

      // -----------------------------------------------------------------------
      // BOTTOM SHEET
      // -----------------------------------------------------------------------
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        modalBackgroundColor: AppColors.surfaceDark,

        surfaceTintColor: Colors.transparent,

        elevation: 12,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxxl),
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // SNACKBAR
      // -----------------------------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceDark3,

        contentTextStyle: AppTypography.dark.bodyMedium?.copyWith(
          color: AppColors.textPrimaryDark,
        ),

        behavior: SnackBarBehavior.floating,

        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),

        elevation: 6,

        insetPadding: const EdgeInsets.all(AppSpacing.lg),
      ),

      // -----------------------------------------------------------------------
      // SWITCH
      // -----------------------------------------------------------------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.backgroundDark;
          }

          return AppColors.textTertiaryDark;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }

          return AppColors.surfaceDark3;
        }),
      ),

      // -----------------------------------------------------------------------
      // PROGRESS
      // -----------------------------------------------------------------------
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceDark3,
      ),

      // -----------------------------------------------------------------------
      // DIVIDER
      // -----------------------------------------------------------------------
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        thickness: 1,
        space: 1,
      ),

      // -----------------------------------------------------------------------
      // NAVIGATION BAR
      // -----------------------------------------------------------------------
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,

        elevation: 0,

        height: 72,

        indicatorColor: const Color(0xFF164E32),

        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          final bool selected = states.contains(WidgetState.selected);

          return AppTypography.dark.labelSmall?.copyWith(
            color: selected ? AppColors.primary : AppColors.textTertiaryDark,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),

        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
          final bool selected = states.contains(WidgetState.selected);

          return IconThemeData(
            color: selected ? AppColors.primary : AppColors.textTertiaryDark,
            size: 24,
          );
        }),
      ),

      // -----------------------------------------------------------------------
      // LIST TILE
      // -----------------------------------------------------------------------
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,

        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),

        titleTextStyle: AppTypography.dark.titleMedium,

        subtitleTextStyle: AppTypography.dark.bodySmall,
      ),

      // -----------------------------------------------------------------------
      // PAGE TRANSITIONS
      // -----------------------------------------------------------------------
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
