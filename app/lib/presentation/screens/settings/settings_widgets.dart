import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';

/// Adaptive page padding: tighter on phones, breathable on tablets/desktop.
EdgeInsets settingsPagePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final horizontal = width < 480 ? AppSpacing.xs : AppSpacing.lg;
  return EdgeInsets.fromLTRB(
    horizontal,
    AppSpacing.md,
    horizontal,
    AppSpacing.lg + AppSpacing.md,
  );
}

/// Spacing between settings groups.
double settingsGroupGap(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width < 480 ? AppSpacing.lg : AppSpacing.lg + AppSpacing.xs;
}

/// A grouped, iOS-style settings section: optional caption + a single rounded
/// surface that holds one or more visually-related rows. Reduces "wall of cards"
/// density vs. one card per setting.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    this.title,
    this.caption,
    required this.children,
    this.padding,
    this.gap = 0,
  });

  final String? title;
  final String? caption;
  final List<Widget> children;
  final EdgeInsets? padding;

  /// Inner spacing between children. 0 = stacked rows with dividers,
  /// >0 = gap between blocks (use for free-form content).
  final double gap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context);
    final colorScheme = theme.colorScheme;

    Widget body;
    if (gap > 0) {
      final spaced = <Widget>[];
      for (var i = 0; i < children.length; i++) {
        spaced.add(children[i]);
        if (i != children.length - 1) {
          spaced.add(SizedBox(height: gap));
        }
      }
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: spaced,
      );
    } else {
      final stacked = <Widget>[];
      for (var i = 0; i < children.length; i++) {
        stacked.add(children[i]);
        if (i != children.length - 1) {
          stacked.add(Divider(
            height: AppStroke.hairline,
            thickness: 1,
            color: palette.borderSubtle,
          ));
        }
      }
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: stacked,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xxs,
              0,
              AppSpacing.xxs,
              AppSpacing.xs,
            ),
            child: Text(
              context.tr(title!).toUpperCase(),
              style: TextStyle(
                fontSize: AppText.xs - 1,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 1.4,
              ),
            ),
          ),
        Container(
          padding: padding ?? EdgeInsets.zero,
          decoration: BoxDecoration(
            color: palette.elevatedSurface,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: palette.borderSubtle),
          ),
          child: body,
        ),
        if (caption != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xxs,
              AppSpacing.xs,
              AppSpacing.xxs,
              0,
            ),
            child: Text(
              context.tr(caption!),
              style: TextStyle(
                fontSize: AppText.xs,
                color: colorScheme.onSurfaceVariant,
                height: AppLineHeight.body,
              ),
            ),
          ),
      ],
    );
  }
}

/// Minimum touch target on mobile (WCAG 2.5.8 AAA recommends 44).
const double _kMinTouch = AppSpacing.md * 3;
const double _kSettingsLeadingSize = AppSpacing.md + AppSpacing.md + AppSpacing.sm;
const double _kSettingsDiagnosticIconSize = 18.0;

/// A row in a [SettingsGroup]. Larger touch target on mobile, optional
/// trailing widget (chevron / status pill / switch).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.trailing,
    this.onTap,
    this.contentPadding,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets? contentPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = iconColor ?? colorScheme.primary;

    final tile = ListTile(
      contentPadding: contentPadding ??
          EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs + AppSpacing.xxs / 2,
          ),
      minVerticalPadding: AppSpacing.md - AppSpacing.xxs,
      minLeadingWidth: _kSettingsLeadingSize,
      leading: Container(
        width: _kSettingsLeadingSize,
        height: _kSettingsLeadingSize,
        decoration: BoxDecoration(
          color: color.withAlpha(AppAlpha.low25),
          borderRadius: BorderRadius.circular(AppRadii.md - 2),
        ),
        child: Icon(icon, color: color, size: AppSizes.iconXl),
      ),
      title: Text(
        context.tr(title),
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: AppText.base - 1,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: EdgeInsets.only(top: AppSpacing.xxs / 2),
              child: Text(
                context.tr(subtitle!),
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: AppText.xs,
                  height: AppLineHeight.compact,
                ),
              ),
            ),
      trailing: trailing ??
          (onTap != null
              ? Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant.withValues(
                    alpha: AppOpacity.strong,
                  ),
                )
              : null),
      onTap: onTap,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kMinTouch),
      child: tile,
    );
  }
}

/// Free-form block inside a [SettingsGroup]. Use when a row layout doesn't fit
/// (sliders, multi-line forms, etc.).
class SettingsBlock extends StatelessWidget {
  const SettingsBlock({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
    ),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: padding, child: child);
  }
}

/// Status pill (Connected / Offline / Pending). Compact, inline-safe.
class SettingsStatusPill extends StatelessWidget {
  const SettingsStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(AppAlpha.low28),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: AppSizes.iconTiny),
            SizedBox(width: AppSpacing.xxs),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: AppText.xs - 1,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Diagnostic row used inside error states: details + open/copy actions.
class SettingsErrorDiagnostic extends ConsumerWidget {
  const SettingsErrorDiagnostic({
    super.key,
    required this.details,
    required this.linkUrl,
    required this.linkLabel,
  });

  final String details;
  final String linkUrl;
  final String linkLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final clippedDetails = details.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          clippedDetails,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: AppText.xs,
            height: AppLineHeight.body,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            TextButton.icon(
              onPressed: () => openSettingsUrl(context, ref, linkUrl),
              icon: const Icon(Icons.open_in_new, size: _kSettingsDiagnosticIconSize),
              label: Text(linkLabel),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.infoColor,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
                minimumSize: const Size(0, _kMinTouch),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => copySettingsErrorText(context, clippedDetails),
              icon: const Icon(Icons.content_copy, size: _kSettingsDiagnosticIconSize),
              label: Text(context.tr('Copy')),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                minimumSize: const Size(0, _kMinTouch),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> openSettingsUrl(
  BuildContext context,
  WidgetRef ref,
  String url,
) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    showCopyableDiagnosticSnackBar(
      context,
      ref,
      message: context.tr('Cannot open URL: invalid format.'),
      scope: 'settings.open_url.invalid_format',
      contextData: {'url': url},
    );
    return;
  }

  final canOpen = await canLaunchUrl(uri);
  if (!canOpen) {
    if (!context.mounted) return;
    showCopyableDiagnosticSnackBar(
      context,
      ref,
      message: context.tr('Could not open link in browser.'),
      scope: 'settings.open_url.cannot_open',
      contextData: {'url': url},
    );
    return;
  }

  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> copySettingsErrorText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(context.tr('Error copied to clipboard.')),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    ),
  );
}
