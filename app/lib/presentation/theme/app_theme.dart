import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme_tokens.dart';

class AppTheme {
  static const _primaryColor = AppThemeTokens.primary;
  static const _primaryDarkColor = AppThemeTokens.primaryDark;
  static const _secondaryColor = AppThemeTokens.secondary;
  static const _accentColor = AppThemeTokens.accent;
  static const _errorColor = AppThemeTokens.error;
  static const _approveColor = AppThemeTokens.success;
  static const _rejectColor = AppThemeTokens.error;
  static const _editColor = AppThemeTokens.primary;
  static const _warningColor = AppThemeTokens.warning;
  static const _infoColor = AppThemeTokens.primaryDark;

  static Color get approveColor => _approveColor;
  static Color get rejectColor => _rejectColor;
  static Color get editColor => _editColor;
  static Color get warningColor => _warningColor;
  static Color get infoColor => _infoColor;

  static const double entryScreenMaxWidth = 560.0;
  static const double authScreenMaxWidth = 520.0;

  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData get appTheme => _buildTheme(
    Brightness.light,
    primary: AppThemeTokens.appPrimary,
    primaryDark: AppThemeTokens.appPrimary,
    secondary: AppThemeTokens.appSecondary,
    accent: AppThemeTokens.appEdit,
    error: AppThemeTokens.appError,
    paletteVariant: AppThemePaletteVariant.app,
  );

  static AppThemePalette paletteOf(BuildContext context) {
    final theme = Theme.of(context);
    final extension = theme.extension<AppThemePalette>();
    return extension ?? AppThemePalette.fallback(theme.colorScheme);
  }

  static ThemeData _buildTheme(
    Brightness brightness, {
    Color primary = _primaryColor,
    Color primaryDark = _primaryDarkColor,
    Color secondary = _secondaryColor,
    Color accent = _accentColor,
    Color error = _errorColor,
    AppThemePaletteVariant paletteVariant = AppThemePaletteVariant.site,
  }) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          secondary: secondary,
          tertiary: accent,
          error: error,
          surface: isDark ? AppThemeTokens.dark : AppThemeTokens.white,
          surfaceContainerHighest: isDark
              ? AppThemeTokens.darkMutedSurface
              : AppThemeTokens.lightGray,
          onSurface: isDark ? AppThemeTokens.white : AppThemeTokens.dark,
          onSurfaceVariant: isDark
              ? AppThemeTokens.darkTextMuted
              : AppThemeTokens.gray,
          outline: isDark
              ? AppThemeTokens.darkBorderLight
              : AppThemeTokens.lightBorderLight,
          outlineVariant: isDark
              ? AppThemeTokens.darkBorderSubtle
              : AppThemeTokens.lightBorderSubtle,
        );
    final textTheme = GoogleFonts.interTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    final palette = isDark
        ? AppThemePalette.dark(scheme)
        : paletteVariant == AppThemePaletteVariant.app
        ? AppThemePalette.app(scheme)
        : AppThemePalette.light(scheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.canvas,
      textTheme: textTheme,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: AppThemeTokens.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.elevatedSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.55),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputFill,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: AppThemeTokens.onPrimary,
          backgroundColor: scheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.mutedSurface,
        selectedColor: scheme.primary.withValues(alpha: 0.12),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        labelStyle: textTheme.bodySmall?.copyWith(color: scheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.badge),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }

  static Color colorForContentType(String type) {
    return switch (type) {
      'Article' => _primaryColor,
      'Social' => _accentColor,
      'Newsletter' => _secondaryColor,
      'Video' => _primaryDarkColor,
      'Reel' => AppThemeTokens.purpleStrong,
      'Short' => AppThemeTokens.orange,
      _ => _primaryColor,
    };
  }
}

class AppSpacing {
  static const double xxs = AppThemeTokens.spacing1;
  static const double xs2 = AppThemeTokens.spacing1b;
  static const double xs = AppThemeTokens.spacing2;
  static const double sm = AppThemeTokens.spacing3;
  static const double md = AppThemeTokens.spacing4;
  static const double lg = AppThemeTokens.spacing5;
  static const double xl = AppThemeTokens.spacing6;
  static const double xxl = AppThemeTokens.spacing0b;
  static const double xxs2 = AppThemeTokens.spacing1Half;
  static const double compact = AppThemeTokens.spacing10;
  static const double xxsHalf = AppThemeTokens.spacing0b;
  static const double micro = AppThemeTokens.spacing3Half;
  static const double thin = AppThemeTokens.spacingHalf;
  static const double dense = AppThemeTokens.spacing18;
  static const double mid = AppThemeTokens.spacing22;
  static const double wide = AppThemeTokens.spacing32;
  static const double compactStack = AppThemeTokens.spacing1Half;

  static double scale(BuildContext context) {
    return MediaQuery.sizeOf(context).width < AppThemeTokens.mobileBreakpoint
        ? AppThemeTokens.mobileDensityScale
        : 1.0;
  }

  static double scaled(BuildContext context, double value) {
    return value * scale(context);
  }

  static EdgeInsets page(BuildContext context) {
    final compact = scale(context);
    return EdgeInsets.symmetric(
      horizontal: AppThemeTokens.spacing5 * compact,
      vertical: AppThemeTokens.spacing4 * compact,
    );
  }

  static EdgeInsets card(BuildContext context) {
    final compact = scale(context);
    return EdgeInsets.all(AppSpacing.md * compact);
  }
}

class AppRadii {
  static const double sm = AppThemeTokens.radiusSm;
  static const double xxs = AppThemeTokens.radiusTiny;
  static const double md = AppThemeTokens.radiusMd;
  static const double lg = AppThemeTokens.radiusLg;
  static const double xl = AppThemeTokens.radiusXl;
  static const double xxl = AppThemeTokens.radius2xl;
  static const double narrow = AppThemeTokens.radiusNarrow;
  static const double card = AppThemeTokens.radius2xl;
  static const double button = AppThemeTokens.radiusLg;
  static const double input = AppThemeTokens.radiusMd;
  static const double badge = AppThemeTokens.radiusMd;
  static const double pill = AppThemeTokens.radiusCompact;
}

class AppText {
  static double get xs => AppThemeTokens.textXs;
  static double get sm => AppThemeTokens.textSm;
  static double get base => AppThemeTokens.textBase;
  static double get lg => AppThemeTokens.textLg;
  static double get xxs => AppThemeTokens.text10;
  static double get xs11 => AppThemeTokens.text11;
  static double get tight => AppThemeTokens.text11;
  static double get compact => AppThemeTokens.text13;
  static double get medium => AppThemeTokens.text15;
  static double get tall => AppThemeTokens.text17;
  static double get body => AppThemeTokens.text12Half;
  static double get xxl => AppThemeTokens.text20;
  static double get xxxl => AppThemeTokens.text24;

  @Deprecated('Use tight')
  static double get xs11 => tight;
  @Deprecated('Use compact')
  static double get sm1 => compact;
  @Deprecated('Use medium')
  static double get sm2 => medium;
  @Deprecated('Use body')
  static double get md5 => body;
  static double compact(BuildContext context, double value) {
    return value * AppSpacing.scale(context);
  }
}

class AppMotion {
  static const Duration instant = AppThemeTokens.durationInstant;
  static const Duration fast = AppThemeTokens.durationFast;
  static const Duration base = AppThemeTokens.durationBase;
  static const Duration slow = AppThemeTokens.durationSlow;
  static const Duration long = AppThemeTokens.durationLong;
  static const Duration settle = AppThemeTokens.durationSettle;
  static const String standard = AppThemeTokens.standardMotion;
  static const String out = AppThemeTokens.outMotion;
  static const String spring = AppThemeTokens.springMotion;
}

enum AppThemePaletteVariant { site, app }

class AppThemePalette extends ThemeExtension<AppThemePalette> {
  const AppThemePalette({
    required this.canvas,
    required this.surface,
    required this.elevatedSurface,
    required this.mutedSurface,
    required this.inputFill,
    required this.borderSubtle,
    required this.heroGradient,
  });

  final Color canvas;
  final Color surface;
  final Color elevatedSurface;
  final Color mutedSurface;
  final Color inputFill;
  final Color borderSubtle;
  final List<Color> heroGradient;

  factory AppThemePalette.dark(ColorScheme scheme) {
    return AppThemePalette(
      canvas: AppThemeTokens.dark,
      surface: scheme.surface,
      elevatedSurface: AppThemeTokens.darkElevatedSurface,
      mutedSurface: AppThemeTokens.darkMutedSurface,
      inputFill: AppThemeTokens.darkElevatedSurface,
      borderSubtle: AppThemeTokens.darkBorderSubtle,
      heroGradient: const [
        AppThemeTokens.dark,
        AppThemeTokens.darkElevatedSurface,
        AppThemeTokens.darkSurfaceTint,
      ],
    );
  }

  factory AppThemePalette.light(ColorScheme scheme) {
    return AppThemePalette(
      canvas: AppThemeTokens.white,
      surface: scheme.surface,
      elevatedSurface: AppThemeTokens.white,
      mutedSurface: AppThemeTokens.lightGray,
      inputFill: AppThemeTokens.lightInputFill,
      borderSubtle: AppThemeTokens.lightBorderSubtle,
      heroGradient: const [
        AppThemeTokens.white,
        AppThemeTokens.lightGray,
        AppThemeTokens.lightBlue,
      ],
    );
  }

  factory AppThemePalette.app(ColorScheme scheme) {
    return AppThemePalette(
      canvas: AppThemeTokens.white,
      surface: scheme.surface,
      elevatedSurface: AppThemeTokens.white,
      mutedSurface: AppThemeTokens.lightGray,
      inputFill: AppThemeTokens.lightInputFill,
      borderSubtle: AppThemeTokens.lightBorderSubtle,
      heroGradient: const [
        AppThemeTokens.white,
        AppThemeTokens.lightGray,
        AppThemeTokens.appHeroTint,
      ],
    );
  }

  factory AppThemePalette.fallback(ColorScheme scheme) {
    return scheme.brightness == Brightness.dark
        ? AppThemePalette.dark(scheme)
        : AppThemePalette.light(scheme);
  }

  @override
  ThemeExtension<AppThemePalette> copyWith({
    Color? canvas,
    Color? surface,
    Color? elevatedSurface,
    Color? mutedSurface,
    Color? inputFill,
    Color? borderSubtle,
    List<Color>? heroGradient,
  }) {
    return AppThemePalette(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      mutedSurface: mutedSurface ?? this.mutedSurface,
      inputFill: inputFill ?? this.inputFill,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      heroGradient: heroGradient ?? this.heroGradient,
    );
  }

  @override
  ThemeExtension<AppThemePalette> lerp(
    covariant ThemeExtension<AppThemePalette>? other,
    double t,
  ) {
    if (other is! AppThemePalette) return this;
    return AppThemePalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      mutedSurface: Color.lerp(mutedSurface, other.mutedSurface, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      heroGradient: List<Color>.generate(
        heroGradient.length,
        (index) =>
            Color.lerp(heroGradient[index], other.heroGradient[index], t)!,
      ),
    );
  }
}
