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
const { colors, text, surfaces, typography, spacing, radius, shadow, motion, components, breakpoints } =
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
requireSection(shadow, 'shadow');
requireSection(motion, 'motion');
requireSection(components, 'components');
requireSection(breakpoints, 'breakpoints');

ensureKeys(colors, 'colors', ['primary', 'primaryDark', 'secondary', 'accent', 'dark', 'gray', 'lightGray', 'lightBlue', 'white', 'codeText', 'badgeBg', 'badgeText', 'success', 'warning', 'orange', 'green', 'error', 'appPrimary', 'appSecondary', 'appEdit', 'appWarning', 'appError', 'appHeroTint', 'purpleStrong', 'cyanStrong']);
ensureKeys(text, 'text', ['light', 'dark', 'onPrimary']);
ensureKeys(text.light, 'text.light', ['muted']);
ensureKeys(text.dark, 'text.dark', ['muted']);
ensureKeys(surfaces, 'surfaces', ['light', 'dark']);
ensureKeys(surfaces.light, 'surfaces.light', ['surface', 'mutedSurface', 'inputFill', 'elevatedSurface', 'surfaceTint', 'borderSubtle', 'borderLight']);
ensureKeys(surfaces.dark, 'surfaces.dark', ['surface', 'mutedSurface', 'elevatedSurface', 'surfaceTint', 'borderSubtle', 'borderLight']);
ensureKeys(typography, 'typography', ['fontSans', 'textXs', 'textSm', 'textBase', 'textLg']);
ensureKeys(spacing, 'spacing', ['0', '1', '2', '3', '4', '5', '6']);
ensureKeys(radius, 'radius', ['sm', 'md', 'lg', 'xl', '2xl']);
ensureKeys(shadow, 'shadow', ['sm', 'card', 'cardHover', 'cardLg']);
ensureKeys(motion, 'motion', ['instant', 'fast', 'base', 'slow', 'standard', 'out']);
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
  static const codeText = ${dartColor(colors.codeText)};
  static const badgeBg = ${dartColor(colors.badgeBg)};
  static const badgeText = ${dartColor(colors.badgeText)};
  static const success = ${dartColor(colors.success)};
  static const warning = ${dartColor(colors.warning)};
  static const orange = ${dartColor(colors.orange)};
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
  static const spacing3Half = 3.0;
  static const spacingHalf = 1.5;
  static const spacing0b = 2.0;
  static const spacing1Half = 6.0;
  static const spacing18 = 18.0;
  static const spacing22 = 22.0;
  static const spacing32 = 32.0;
  static const spacing10 = 10.0;
  static const text10 = 10.0;
  static const text11 = 11.0;
  static const text13 = 13.0;
  static const text15 = 15.0;
  static const text12Half = 12.5;
  static const text17 = 17.0;
  static const text24 = 24.0;
  static const text20 = 20.0;
  static const radiusTiny = 2.0;
  static const radiusNarrow = 10.0;
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
