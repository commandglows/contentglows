import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const themePath = resolve(root, 'tools/design-tokens/contentglows_theme.json');
const outputPath = resolve(
  root,
  'app/lib/presentation/theme/app_theme_tokens.dart',
);

const theme = JSON.parse(readFileSync(themePath, 'utf8'));
const { colors, text, surfaces, typography, spacing, radius, appSizes, opacity, effects, stroke, shadow, motion, components, breakpoints } =
  theme;

function requireSection(value, path) {
  if (!value || typeof value !== 'object') {
    throw new Error(`Expected object for ${path} in ${themePath}`);
  }
  return value;
}

function ensureKeys(value, path, required) {
  for (const key of required) {
    if (value[key] == null) {
      throw new Error(
        `Missing token "${path}.${key}" in ${themePath}.`,
      );
    }
  }
}

function dartDouble(token) {
  const numeric = toNumber(token);
  const fixed = `${numeric.toFixed(3)}`
    .replace(/\.0+$/, '.0')
    .replace(/(\.\d*[1-9])0+$/, '$1')
    .replace(/\.?0*$/, '');
  return `${Number.isInteger(numeric) ? `${numeric}.0` : fixed}`;
}

function toNumber(value) {
  if (typeof value === 'number') {
    return value;
  }
  if (typeof value !== 'string' || value.trim() === '') {
    throw new Error(`Expected numeric token, got ${value}`);
  }
  const trimmed = value.trim();
  if (trimmed.endsWith('px')) {
    return parseFloat(trimmed.replace('px', ''));
  }
  if (trimmed.endsWith('rem')) {
    return parseFloat(trimmed.replace('rem', '')) * 16;
  }
  const parsed = parseFloat(trimmed);
  if (Number.isNaN(parsed)) {
    throw new Error(`Expected numeric token, got ${value}`);
  }
  return parsed;
}

function parseDuration(value) {
  if (typeof value === 'number') {
    return Math.round(value * 1000);
  }
  if (typeof value !== 'string' || value.trim() === '') {
    throw new Error(`Expected duration token, got ${value}`);
  }
  const trimmed = value.trim();
  if (trimmed.endsWith('ms')) {
    return Math.round(parseFloat(trimmed.replace('ms', '')));
  }
  if (trimmed.endsWith('s')) {
    return Math.round(parseFloat(trimmed.replace('s', '')) * 1000);
  }
  const parsed = parseFloat(trimmed);
  if (Number.isNaN(parsed)) {
    throw new Error(`Expected duration token, got ${value}`);
  }
  return Math.round(parsed);
}

function dartColor(hex) {
  if (typeof hex !== 'string') {
    throw new Error(`Expected color token string, got ${hex}`);
  }
  const rgba = hex
    .trim()
    .match(/^rgba\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(0|1|0?\.\d+)\s*\)$/i);
  if (rgba) {
    const [, r, g, b, opacity] = rgba;
    for (const channel of [r, g, b]) {
      const value = Number(channel);
      if (value < 0 || value > 255) {
        throw new Error(`Expected rgba channel 0-255, got ${hex}`);
      }
    }
    return `Color.fromRGBO(${Number(r)}, ${Number(g)}, ${Number(b)}, ${Number(opacity)})`;
  }
  const clean = hex.replace('#', '').toUpperCase();
  if (!/^[0-9A-F]{6}$/.test(clean)) {
    throw new Error(`Expected 6-digit hex color, got ${hex}`);
  }
  return `Color(0xFF${clean})`;
}

requireSection(colors, 'colors');
requireSection(text, 'text');
requireSection(surfaces, 'surfaces');
requireSection(typography, 'typography');
requireSection(spacing, 'spacing');
requireSection(radius, 'radius');
requireSection(appSizes, 'appSizes');
requireSection(opacity, 'opacity');
requireSection(effects, 'effects');
requireSection(stroke, 'stroke');
requireSection(shadow, 'shadow');
requireSection(motion, 'motion');
requireSection(components, 'components');
requireSection(breakpoints, 'breakpoints');

ensureKeys(colors, 'colors', ['primary', 'primaryDark', 'secondary', 'accent', 'dark', 'gray', 'lightGray', 'lightBlue', 'white', 'transparent', 'mediaScrim', 'onMedia', 'codeText', 'badgeBg', 'badgeText', 'success', 'warning', 'orange', 'attentionStrong', 'green', 'error', 'appPrimary', 'appSecondary', 'appEdit', 'appWarning', 'appError', 'appHeroTint', 'purpleStrong', 'cyanStrong']);
ensureKeys(text, 'text', ['light', 'dark', 'onPrimary']);
ensureKeys(text.light, 'text.light', ['muted']);
ensureKeys(text.dark, 'text.dark', ['muted']);
ensureKeys(surfaces, 'surfaces', ['light', 'dark']);
ensureKeys(surfaces.light, 'surfaces.light', ['surface', 'mutedSurface', 'inputFill', 'elevatedSurface', 'surfaceTint', 'borderSubtle', 'borderLight']);
ensureKeys(surfaces.dark, 'surfaces.dark', ['surface', 'mutedSurface', 'elevatedSurface', 'surfaceTint', 'borderSubtle', 'borderLight']);
ensureKeys(typography, 'typography', ['fontSans', 'textXs', 'textSm', 'textBase', 'textLg']);
ensureKeys(typography.appLeading, 'typography.appLeading', ['display', 'dense', 'tight', 'quarter', 'balanced', 'snug', 'compact', 'body', 'readable', 'relaxed', 'comfortable', 'spacious']);
ensureKeys(typography.app, 'typography.app', ['xxs', 'xs11', 'body', 'compact', 'medium', 'tall', 'title', 'xxl', 'heading', 'xxxl', 'metric']);
ensureKeys(spacing, 'spacing', ['0', '1', '2', '3', '4', '5', '6']);
ensureKeys(spacing.app, 'spacing.app', ['hairline', 'xxs', 'micro', 'xs', 'fine', 'compactStack', 'controlGap', 'sm', 'controlInset', 'compact', 'md', 'contentInset', 'lg', 'dense', 'xl', 'mid', 'xxl', 'section', 'wide', 'hero']);
ensureKeys(radius, 'radius', ['sm', 'md', 'lg', 'xl', '2xl', 'pill', 'tiny', 'progress', 'compactControl', 'narrow', 'badge', 'preview', 'avatarLarge', 'sheet']);
ensureKeys(appSizes, 'appSizes', ['iconTiny', 'iconCompact', 'iconSm', 'icon', 'iconMedium', 'iconLarge', 'iconXl', 'iconHeading', 'iconXxl', 'iconHero', 'avatar', 'control', 'playback', 'handle', 'emptyState', 'iconDisplay', 'touchTarget', 'particleRadius', 'placeholderHeight', 'loadingPanelHeight', 'playButton', 'hero']);
ensureKeys(opacity, 'opacity', ['zero', 'faint', 'faintStrong', 'subtle', 'soft', 'low', 'selection', 'medium', 'mediumHigh', 'border', 'light', 'softStrong', 'tint', 'quarter', 'emphasis', 'highlight', 'scrim', 'overlay', 'half', 'divider', 'muted', 'overlayStrong', 'balanced', 'surface', 'strong', 'strong72', 'threeQuarter', 'strong76', 'prominent', 'readable', 'high', 'nearOpaque', 'nearOpaqueStrong', 'alpha']);
ensureKeys(opacity.alpha, 'opacity.alpha', ['faint', 'low12', 'low15', 'low16', 'low18', 'subtle', 'low22', 'low24', 'low25', 'low28', 'glow', 'tint', 'mid45', 'mid55', 'soft', 'mid70', 'border', 'strong100', 'strong120', 'muted', 'warning', 'icon', 'text', 'high210', 'high220']);
ensureKeys(effects, 'effects', ['blurCard', 'blurStrong']);
ensureKeys(stroke, 'stroke', ['hairline', 'emphasis', 'medium', 'loading', 'accent', 'strong']);
ensureKeys(shadow, 'shadow', ['sm', 'card', 'cardHover', 'cardLg']);
ensureKeys(motion, 'motion', ['instant', 'fast', 'base', 'slow', 'notification', 'shimmer', 'standard', 'out']);
ensureKeys(components, 'components', ['input']);
ensureKeys(components.input, 'components.input', ['compactWidth']);
ensureKeys(breakpoints, 'breakpoints', ['mobile', 'tablet', 'desktop']);

const spacingMap = {
  0: toNumber(spacing['0']),
  1: toNumber(spacing[1]),
  2: toNumber(spacing[2]),
  3: toNumber(spacing[3]),
  4: toNumber(spacing[4]),
  5: toNumber(spacing[5]),
  6: toNumber(spacing[6]),
};

const radiusMap = {
  sm: toNumber(radius.sm),
  md: toNumber(radius.md),
  lg: toNumber(radius.lg),
  xl: toNumber(radius.xl),
  xxl: toNumber(radius['2xl']),
  pill: toNumber(radius.pill),
};

const compactRadius = toNumber(radius.lg) - 4;
const inputCompactWidth = toNumber(components.input.compactWidth);

const source = `import 'package:flutter/material.dart';

// Generated from ../../../../tools/design-tokens/contentglows_theme.json.
// Keep project-wide visual changes in that shared token file.
class AppThemeTokens {
  const AppThemeTokens._();

  static const primary = ${dartColor(colors.primary)};
  static const primaryDark = ${dartColor(colors.primaryDark)};
  static const secondary = ${dartColor(colors.secondary)};
  static const accent = ${dartColor(colors.accent)};
  static const dark = ${dartColor(colors.dark)};
  static const gray = ${dartColor(colors.gray)};
  static const lightGray = ${dartColor(colors.lightGray)};
  static const lightBlue = ${dartColor(colors.lightBlue)};
  static const white = ${dartColor(colors.white)};
  static const transparent = ${dartColor(colors.transparent)};
  static const mediaScrim = ${dartColor(colors.mediaScrim)};
  static const onMedia = ${dartColor(colors.onMedia)};
  static const codeText = ${dartColor(colors.codeText)};
  static const badgeBg = ${dartColor(colors.badgeBg)};
  static const badgeText = ${dartColor(colors.badgeText)};
  static const success = ${dartColor(colors.success)};
  static const warning = ${dartColor(colors.warning)};
  static const orange = ${dartColor(colors.orange)};
  static const attentionStrong = ${dartColor(colors.attentionStrong)};
  static const green = ${dartColor(colors.green)};
  static const error = ${dartColor(colors.error)};
  static const appPrimary = ${dartColor(colors.appPrimary)};
  static const appSecondary = ${dartColor(colors.appSecondary)};
  static const appEdit = ${dartColor(colors.appEdit)};
  static const appWarning = ${dartColor(colors.appWarning)};
  static const appError = ${dartColor(colors.appError)};
  static const appHeroTint = ${dartColor(colors.appHeroTint)};
  static const purpleStrong = ${dartColor(colors.purpleStrong)};
  static const cyanStrong = ${dartColor(colors.cyanStrong)};
  static const onPrimary = ${dartColor(text.onPrimary)};
  static const lightTextMuted = ${dartColor(text.light.muted)};
  static const darkTextMuted = ${dartColor(text.dark.muted)};

  static const spacing0 = ${dartDouble(spacingMap[0])};
  static const spacing1 = ${dartDouble(spacingMap[1])};
  static const spacing2 = ${dartDouble(spacingMap[2])};
  static const spacing3 = ${dartDouble(spacingMap[3])};
  static const spacing4 = ${dartDouble(spacingMap[4])};
  static const spacing5 = ${dartDouble(spacingMap[5])};
  static const spacing6 = ${dartDouble(spacingMap[6])};
  static const spacing3Half = ${dartDouble(spacing.app.micro)};
  static const spacingHalf = ${dartDouble(spacing.app.hairline)};
  static const spacing0b = ${dartDouble(spacing.app.xxs)};
  static const spacing1Half = ${dartDouble(spacing.app.compactStack)};
  static const spacing5px = ${dartDouble(spacing.app.fine)};
  static const spacing7 = ${dartDouble(spacing.app.controlGap)};
  static const spacing9 = ${dartDouble(spacing.app.controlInset)};
  static const spacing14 = ${dartDouble(spacing.app.contentInset)};
  static const spacing18 = ${dartDouble(spacing.app.dense)};
  static const spacing22 = ${dartDouble(spacing.app.mid)};
  static const spacing32 = ${dartDouble(spacing.app.wide)};
  static const spacing28 = ${dartDouble(spacing.app.section)};
  static const spacing40 = ${dartDouble(spacing.app.hero)};
  static const spacing10 = ${dartDouble(spacing.app.compact)};
  static const text10 = ${dartDouble(typography.app.xxs)};
  static const text11 = ${dartDouble(typography.app.xs11)};
  static const text13 = ${dartDouble(typography.app.compact)};
  static const text15 = ${dartDouble(typography.app.medium)};
  static const text12Half = ${dartDouble(typography.app.body)};
  static const text17 = ${dartDouble(typography.app.tall)};
  static const text18 = ${dartDouble(typography.app.title)};
  static const text24 = ${dartDouble(typography.app.xxxl)};
  static const text20 = ${dartDouble(typography.app.xxl)};
  static const text22 = ${dartDouble(typography.app.heading)};
  static const text28 = ${dartDouble(typography.app.metric)};
  static const radiusTiny = ${dartDouble(radius.tiny)};
  static const radiusProgress = ${dartDouble(radius.progress)};
  static const radiusCompactControl = ${dartDouble(radius.compactControl)};
  static const radiusNarrow = ${dartDouble(radius.narrow)};
  static const radiusBadge = ${dartDouble(radius.badge)};
  static const radiusPreview = ${dartDouble(radius.preview)};
  static const radiusAvatarLarge = ${dartDouble(radius.avatarLarge)};
  static const radiusSheet = ${dartDouble(radius.sheet)};
  static const durationLong = Duration(seconds: 2);
  static const durationSettle = Duration(milliseconds: 180);

  static const radiusSm = ${dartDouble(radiusMap.sm)};
  static const radiusMd = ${dartDouble(radiusMap.md)};
  static const radiusLg = ${dartDouble(radiusMap.lg)};
  static const radiusXl = ${dartDouble(radiusMap.xl)};
  static const radius2xl = ${dartDouble(radiusMap.xxl)};
  static const radiusPill = ${dartDouble(radiusMap.pill)};
  static const radiusCompact = ${dartDouble(compactRadius)};
  static const inputCompactWidth = ${dartDouble(inputCompactWidth)};

  static const iconTiny = ${dartDouble(appSizes.iconTiny)};
  static const iconCompact = ${dartDouble(appSizes.iconCompact)};
  static const iconSm = ${dartDouble(appSizes.iconSm)};
  static const icon = ${dartDouble(appSizes.icon)};
  static const iconMedium = ${dartDouble(appSizes.iconMedium)};
  static const iconLarge = ${dartDouble(appSizes.iconLarge)};
  static const iconXl = ${dartDouble(appSizes.iconXl)};
  static const iconHeading = ${dartDouble(appSizes.iconHeading)};
  static const iconXxl = ${dartDouble(appSizes.iconXxl)};
  static const iconHero = ${dartDouble(appSizes.iconHero)};
  static const avatarSize = ${dartDouble(appSizes.avatar)};
  static const controlSize = ${dartDouble(appSizes.control)};
  static const playbackIcon = ${dartDouble(appSizes.playback)};
  static const handleSize = ${dartDouble(appSizes.handle)};
  static const emptyStateIcon = ${dartDouble(appSizes.emptyState)};
  static const iconDisplay = ${dartDouble(appSizes.iconDisplay)};
  static const touchTarget = ${dartDouble(appSizes.touchTarget)};
  static const particleRadius = ${dartDouble(appSizes.particleRadius)};
  static const placeholderHeight = ${dartDouble(appSizes.placeholderHeight)};
  static const loadingPanelHeight = ${dartDouble(appSizes.loadingPanelHeight)};
  static const playButtonSize = ${dartDouble(appSizes.playButton)};
  static const heroIcon = ${dartDouble(appSizes.hero)};

  static const opacityZero = ${dartDouble(opacity.zero)};
  static const opacityFaint = ${dartDouble(opacity.faint)};
  static const opacityFaintStrong = ${dartDouble(opacity.faintStrong)};
  static const opacitySubtle = ${dartDouble(opacity.subtle)};
  static const opacitySoft = ${dartDouble(opacity.soft)};
  static const opacityLow = ${dartDouble(opacity.low)};
  static const opacitySelection = ${dartDouble(opacity.selection)};
  static const opacityMedium = ${dartDouble(opacity.medium)};
  static const opacityMediumHigh = ${dartDouble(opacity.mediumHigh)};
  static const opacityBorder = ${dartDouble(opacity.border)};
  static const opacityLight = ${dartDouble(opacity.light)};
  static const opacitySoftStrong = ${dartDouble(opacity.softStrong)};
  static const opacityTint = ${dartDouble(opacity.tint)};
  static const opacityQuarter = ${dartDouble(opacity.quarter)};
  static const opacityEmphasis = ${dartDouble(opacity.emphasis)};
  static const opacityHighlight = ${dartDouble(opacity.highlight)};
  static const opacityScrim = ${dartDouble(opacity.scrim)};
  static const opacityOverlay = ${dartDouble(opacity.overlay)};
  static const opacityHalf = ${dartDouble(opacity.half)};
  static const opacityDivider = ${dartDouble(opacity.divider)};
  static const opacityMuted = ${dartDouble(opacity.muted)};
  static const opacityOverlayStrong = ${dartDouble(opacity.overlayStrong)};
  static const opacityBalanced = ${dartDouble(opacity.balanced)};
  static const opacitySurface = ${dartDouble(opacity.surface)};
  static const opacityStrong = ${dartDouble(opacity.strong)};
  static const opacityStrong72 = ${dartDouble(opacity.strong72)};
  static const opacityThreeQuarter = ${dartDouble(opacity.threeQuarter)};
  static const opacityStrong76 = ${dartDouble(opacity.strong76)};
  static const opacityProminent = ${dartDouble(opacity.prominent)};
  static const opacityReadable = ${dartDouble(opacity.readable)};
  static const opacityHigh = ${dartDouble(opacity.high)};
  static const opacityNearOpaque = ${dartDouble(opacity.nearOpaque)};
  static const opacityNearOpaqueStrong = ${dartDouble(opacity.nearOpaqueStrong)};
  static const alphaFaint = ${opacity.alpha.faint};
  static const alphaLow12 = ${opacity.alpha.low12};
  static const alphaLow15 = ${opacity.alpha.low15};
  static const alphaLow16 = ${opacity.alpha.low16};
  static const alphaLow18 = ${opacity.alpha.low18};
  static const alphaSubtle = ${opacity.alpha.subtle};
  static const alphaLow22 = ${opacity.alpha.low22};
  static const alphaLow24 = ${opacity.alpha.low24};
  static const alphaLow25 = ${opacity.alpha.low25};
  static const alphaLow28 = ${opacity.alpha.low28};
  static const alphaGlow = ${opacity.alpha.glow};
  static const alphaTint = ${opacity.alpha.tint};
  static const alphaMid45 = ${opacity.alpha.mid45};
  static const alphaMid55 = ${opacity.alpha.mid55};
  static const alphaSoft = ${opacity.alpha.soft};
  static const alphaMid70 = ${opacity.alpha.mid70};
  static const alphaBorder = ${opacity.alpha.border};
  static const alphaStrong100 = ${opacity.alpha.strong100};
  static const alphaStrong120 = ${opacity.alpha.strong120};
  static const alphaMuted = ${opacity.alpha.muted};
  static const alphaWarning = ${opacity.alpha.warning};
  static const alphaIcon = ${opacity.alpha.icon};
  static const alphaText = ${opacity.alpha.text};
  static const alphaHigh210 = ${opacity.alpha.high210};
  static const alphaHigh220 = ${opacity.alpha.high220};
  static const blurCard = ${dartDouble(effects.blurCard)};
  static const blurStrong = ${dartDouble(effects.blurStrong)};
  static const strokeHairline = ${dartDouble(stroke.hairline)};
  static const strokeEmphasis = ${dartDouble(stroke.emphasis)};
  static const strokeMedium = ${dartDouble(stroke.medium)};
  static const strokeLoading = ${dartDouble(stroke.loading)};
  static const strokeAccent = ${dartDouble(stroke.accent)};
  static const strokeStrong = ${dartDouble(stroke.strong)};

  static const leadingDisplay = ${dartDouble(typography.appLeading.display)};
  static const leadingDense = ${dartDouble(typography.appLeading.dense)};
  static const leadingTight = ${dartDouble(typography.appLeading.tight)};
  static const leadingQuarter = ${dartDouble(typography.appLeading.quarter)};
  static const leadingBalanced = ${dartDouble(typography.appLeading.balanced)};
  static const leadingSnug = ${dartDouble(typography.appLeading.snug)};
  static const leadingCompact = ${dartDouble(typography.appLeading.compact)};
  static const leadingBody = ${dartDouble(typography.appLeading.body)};
  static const leadingReadable = ${dartDouble(typography.appLeading.readable)};
  static const leadingRelaxed = ${dartDouble(typography.appLeading.relaxed)};
  static const leadingComfortable = ${dartDouble(typography.appLeading.comfortable)};
  static const leadingSpacious = ${dartDouble(typography.appLeading.spacious)};

  static const textXs = ${dartDouble(toNumber(typography.textXs))};
  static const textSm = ${dartDouble(toNumber(typography.textSm))};
  static const textBase = ${dartDouble(toNumber(typography.textBase))};
  static const textLg = ${dartDouble(toNumber(typography.textLg))};
  static const textXl = 24.0;
  static const textXxl = 20.0;

  static const darkElevatedSurface = ${dartColor(surfaces.dark.elevatedSurface)};
  static const darkMutedSurface = ${dartColor(surfaces.dark.mutedSurface)};
  static const darkSurfaceTint = ${dartColor(surfaces.dark.surfaceTint)};
  static const lightInputFill = ${dartColor(surfaces.light.inputFill)};
  static const lightMutedSurface = ${dartColor(surfaces.light.mutedSurface)};
  static const lightBorderSubtle = ${dartColor(surfaces.light.borderSubtle)};
  static const lightBorderLight = ${dartColor(surfaces.light.borderLight)};
  static const darkBorderSubtle = ${dartColor(surfaces.dark.borderSubtle)};
  static const darkBorderLight = ${dartColor(surfaces.dark.borderLight)};

  static const durationInstant = Duration(milliseconds: ${parseDuration(motion.instant)});
  static const durationFast = Duration(milliseconds: ${parseDuration(motion.fast)});
  static const durationBase = Duration(milliseconds: ${parseDuration(motion.base)});
  static const durationSlow = Duration(milliseconds: ${parseDuration(motion.slow)});
  static const durationNotification = Duration(milliseconds: ${parseDuration(motion.notification)});
  static const durationShimmer = Duration(milliseconds: ${parseDuration(motion.shimmer)});
  static const standardMotion = '${motion.standard}';
  static const outMotion = '${motion.out}';
  static const springMotion = '${motion.spring}';

  static const mobileBreakpoint = ${breakpoints.mobile};
  static const desktopBreakpoint = ${breakpoints.desktop};
  static const tabletBreakpoint = ${breakpoints.tablet};
  static const mobileDensityScale = ${dartDouble(toNumber(spacing.densityScale?.mobile ?? 0.9))};
}
`;

writeFileSync(outputPath, source);
