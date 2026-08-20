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
  static Color get mediaScrimColor => AppThemeTokens.mediaScrim;
  static Color get onMediaColor => AppThemeTokens.onMedia;
  static Color get transparentColor => AppThemeTokens.transparent;
  static Color get attentionStrongColor => AppThemeTokens.attentionStrong;

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
        backgroundColor: AppThemeTokens.transparent,
        surfaceTintColor: AppThemeTokens.transparent,
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
        indicatorColor: scheme.primary.withValues(alpha: AppOpacity.selection),
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
        surfaceTintColor: AppThemeTokens.transparent,
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
        color: scheme.outlineVariant.withValues(alpha: AppOpacity.divider),
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
          borderSide: BorderSide(
            color: scheme.primary,
            width: AppStroke.emphasis,
          ),
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
        selectedColor: scheme.primary.withValues(alpha: AppOpacity.soft),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: AppOpacity.strong),
        ),
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
  static const double xs2 = AppThemeTokens.spacing2;
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
  static const double fine = AppThemeTokens.spacing5px;
  static const double controlGap = AppThemeTokens.spacing7;
  static const double controlInset = AppThemeTokens.spacing9;
  static const double contentInset = AppThemeTokens.spacing14;
  static const double section = AppThemeTokens.spacing28;
  static const double hero = AppThemeTokens.spacing40;

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
  static const double badge = AppThemeTokens.radiusBadge;
  static const double compactControl = AppThemeTokens.radiusCompactControl;
  static const double preview = AppThemeTokens.radiusPreview;
  static const double progress = AppThemeTokens.radiusProgress;
  static const double sheet = AppThemeTokens.radiusSheet;
  static const double avatar = AppThemeTokens.radiusPreview;
  static const double avatarLarge = AppThemeTokens.radiusAvatarLarge;
  static const double pill = AppThemeTokens.radiusPill;
}

class AppText {
  static const double xs = AppThemeTokens.textXs;
  static const double sm = AppThemeTokens.textSm;
  static const double base = AppThemeTokens.textBase;
  static const double lg = AppThemeTokens.textLg;
  static const double xxs = AppThemeTokens.text10;
  static const double xs11 = AppThemeTokens.text11;
  static const double tight = AppThemeTokens.text11;
  static const double compact = AppThemeTokens.text13;
  static const double medium = AppThemeTokens.text15;
  static const double tall = AppThemeTokens.text17;
  static const double title = AppThemeTokens.text18;
  static const double body = AppThemeTokens.text12Half;
  static const double xxl = AppThemeTokens.text20;
  static const double xxxl = AppThemeTokens.text24;
  static const double heading = AppThemeTokens.text22;
  static const double metric = AppThemeTokens.text28;

  @Deprecated('Use compact')
  static const double sm1 = compact;
  @Deprecated('Use medium')
  static const double sm2 = medium;
  @Deprecated('Use body')
  static const double md5 = body;
  static double compactWithScale(BuildContext context, double value) {
    return value * AppSpacing.scale(context);
  }
}

class AppSizes {
  static const double iconTiny = AppThemeTokens.iconTiny;
  static const double iconCompact = AppThemeTokens.iconCompact;
  static const double iconSm = AppThemeTokens.iconSm;
  static const double icon = AppThemeTokens.icon;
  static const double iconMedium = AppThemeTokens.iconMedium;
  static const double iconLarge = AppThemeTokens.iconLarge;
  static const double iconXl = AppThemeTokens.iconXl;
  static const double iconHeading = AppThemeTokens.iconHeading;
  static const double iconXxl = AppThemeTokens.iconXxl;
  static const double iconHero = AppThemeTokens.iconHero;
  static const double avatar = AppThemeTokens.avatarSize;
  static const double control = AppThemeTokens.controlSize;
  static const double playbackIcon = AppThemeTokens.playbackIcon;
  static const double handle = AppThemeTokens.handleSize;
  static const double emptyStateIcon = AppThemeTokens.emptyStateIcon;
  static const double iconDisplay = AppThemeTokens.iconDisplay;
  static const double touchTarget = AppThemeTokens.touchTarget;
  static const double particleRadius = AppThemeTokens.particleRadius;
  static const double placeholderHeight = AppThemeTokens.placeholderHeight;
  static const double loadingPanelHeight = AppThemeTokens.loadingPanelHeight;
  static const double playButton = AppThemeTokens.playButtonSize;
  static const double heroIcon = AppThemeTokens.heroIcon;
}

class AppOpacity {
  static const double zero = AppThemeTokens.opacityZero;
  static const double faint = AppThemeTokens.opacityFaint;
  static const double faintStrong = AppThemeTokens.opacityFaintStrong;
  static const double subtle = AppThemeTokens.opacitySubtle;
  static const double soft = AppThemeTokens.opacitySoft;
  static const double low = AppThemeTokens.opacityLow;
  static const double selection = AppThemeTokens.opacitySelection;
  static const double medium = AppThemeTokens.opacityMedium;
  static const double mediumHigh = AppThemeTokens.opacityMediumHigh;
  static const double border = AppThemeTokens.opacityBorder;
  static const double light = AppThemeTokens.opacityLight;
  static const double softStrong = AppThemeTokens.opacitySoftStrong;
  static const double tint = AppThemeTokens.opacityTint;
  static const double quarter = AppThemeTokens.opacityQuarter;
  static const double emphasis = AppThemeTokens.opacityEmphasis;
  static const double highlight = AppThemeTokens.opacityHighlight;
  static const double scrim = AppThemeTokens.opacityScrim;
  static const double overlay = AppThemeTokens.opacityOverlay;
  static const double half = AppThemeTokens.opacityHalf;
  static const double divider = AppThemeTokens.opacityDivider;
  static const double muted = AppThemeTokens.opacityMuted;
  static const double overlayStrong = AppThemeTokens.opacityOverlayStrong;
  static const double balanced = AppThemeTokens.opacityBalanced;
  static const double surface = AppThemeTokens.opacitySurface;
  static const double strong = AppThemeTokens.opacityStrong;
  static const double strong72 = AppThemeTokens.opacityStrong72;
  static const double threeQuarter = AppThemeTokens.opacityThreeQuarter;
  static const double strong76 = AppThemeTokens.opacityStrong76;
  static const double prominent = AppThemeTokens.opacityProminent;
  static const double readable = AppThemeTokens.opacityReadable;
  static const double high = AppThemeTokens.opacityHigh;
  static const double nearOpaque = AppThemeTokens.opacityNearOpaque;
  static const double nearOpaqueStrong = AppThemeTokens.opacityNearOpaqueStrong;
}

class AppAlpha {
  static const int faint = AppThemeTokens.alphaFaint;
  static const int low12 = AppThemeTokens.alphaLow12;
  static const int low15 = AppThemeTokens.alphaLow15;
  static const int low16 = AppThemeTokens.alphaLow16;
  static const int low18 = AppThemeTokens.alphaLow18;
  static const int subtle = AppThemeTokens.alphaSubtle;
  static const int low22 = AppThemeTokens.alphaLow22;
  static const int low24 = AppThemeTokens.alphaLow24;
  static const int low25 = AppThemeTokens.alphaLow25;
  static const int low28 = AppThemeTokens.alphaLow28;
  static const int glow = AppThemeTokens.alphaGlow;
  static const int tint = AppThemeTokens.alphaTint;
  static const int mid45 = AppThemeTokens.alphaMid45;
  static const int mid55 = AppThemeTokens.alphaMid55;
  static const int soft = AppThemeTokens.alphaSoft;
  static const int mid70 = AppThemeTokens.alphaMid70;
  static const int border = AppThemeTokens.alphaBorder;
  static const int strong100 = AppThemeTokens.alphaStrong100;
  static const int strong120 = AppThemeTokens.alphaStrong120;
  static const int muted = AppThemeTokens.alphaMuted;
  static const int warning = AppThemeTokens.alphaWarning;
  static const int icon = AppThemeTokens.alphaIcon;
  static const int text = AppThemeTokens.alphaText;
  static const int high210 = AppThemeTokens.alphaHigh210;
  static const int high220 = AppThemeTokens.alphaHigh220;
}

class AppEffects {
  static const double blurCard = AppThemeTokens.blurCard;
  static const double blurStrong = AppThemeTokens.blurStrong;
}

class AppStroke {
  static const double hairline = AppThemeTokens.strokeHairline;
  static const double emphasis = AppThemeTokens.strokeEmphasis;
  static const double medium = AppThemeTokens.strokeMedium;
  static const double loading = AppThemeTokens.strokeLoading;
  static const double accent = AppThemeTokens.strokeAccent;
  static const double strong = AppThemeTokens.strokeStrong;
}

class AppLineHeight {
  static const double display = AppThemeTokens.leadingDisplay;
  static const double dense = AppThemeTokens.leadingDense;
  static const double tight = AppThemeTokens.leadingTight;
  static const double quarter = AppThemeTokens.leadingQuarter;
  static const double balanced = AppThemeTokens.leadingBalanced;
  static const double snug = AppThemeTokens.leadingSnug;
  static const double compact = AppThemeTokens.leadingCompact;
  static const double body = AppThemeTokens.leadingBody;
  static const double readable = AppThemeTokens.leadingReadable;
  static const double relaxed = AppThemeTokens.leadingRelaxed;
  static const double comfortable = AppThemeTokens.leadingComfortable;
  static const double spacious = AppThemeTokens.leadingSpacious;
}

class AppMotion {
  static const Duration instant = AppThemeTokens.durationInstant;
  static const Duration fast = AppThemeTokens.durationFast;
  static const Duration base = AppThemeTokens.durationBase;
  static const Duration slow = AppThemeTokens.durationSlow;
  static const Duration notification = AppThemeTokens.durationNotification;
  static const Duration shimmer = AppThemeTokens.durationShimmer;
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
