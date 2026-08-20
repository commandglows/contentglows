import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/content_item.dart';
import '../../../data/models/social_placement.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_tokens.dart';

class PlatformPreviewSheet extends ConsumerWidget {
  const PlatformPreviewSheet({
    super.key,
    required this.contentId,
    required this.title,
    required this.body,
    required this.channels,
    required this.type,
  });

  final String contentId;
  final String title;
  final String body;
  final List<PublishingChannel> channels;
  final ContentType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final previews = _buildPreviews(context);
    final placementState = ref.watch(socialPlacementProvider(contentId));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.xs,
            ),
            child: Container(
              width: AppSizes.handle,
              height: AppSpacing.xxs,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(AppRadii.xxs),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(context.tr('Platform Previews'),
                style: theme.textTheme.titleMedium),
          ),
          _PlacementReadinessSummary(state: placementState),
          const SizedBox(height: AppThemeTokens.spacing3),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.wide,
              ),
              itemCount: previews.length,
              itemBuilder: (context, index) => previews[index],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPreviews(BuildContext context) {
    final previews = <Widget>[];
    final plainBody = _stripMarkdown(body);
    final truncated = plainBody.length > 280
        ? '${plainBody.substring(0, 277)}...'
        : plainBody;

    for (final channel in channels) {
      switch (channel) {
        case PublishingChannel.twitter:
          previews.add(_TwitterPreview(
            body: truncated,
            charCount: truncated.length,
          ));
        case PublishingChannel.linkedin:
          previews.add(_LinkedInPreview(
            title: title,
            body: plainBody.length > 700
                ? '${plainBody.substring(0, 697)}...'
                : plainBody,
          ));
        case PublishingChannel.instagram:
          previews.add(_InstagramPreview(
            body: plainBody.length > 2200
                ? '${plainBody.substring(0, 2197)}...'
                : plainBody,
          ));
        case PublishingChannel.ghost || PublishingChannel.wordpress:
          previews.add(_BlogPreview(
            title: title,
            body: body,
            platform: channel.name,
          ));
        case PublishingChannel.youtube:
          previews.add(_YouTubePreview(title: title, description: truncated));
        case PublishingChannel.tiktok:
          previews.add(_TikTokPreview(caption: truncated));
      }
    }

    if (previews.isEmpty) {
      // Default previews if no channels
      previews.add(_TwitterPreview(body: truncated, charCount: truncated.length));
      previews.add(_LinkedInPreview(title: title, body: truncated));
    }

    return previews;
  }

  String _stripMarkdown(String md) {
    return md
        .replaceAll(RegExp(r'#{1,6}\s'), '')
        .replaceAll(RegExp(r'\*{1,2}'), '')
        .replaceAll(RegExp(r'_{1,2}'), '')
        .replaceAll(RegExp(r'`{1,3}'), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        .replaceAll(RegExp(r'^\s*[-*+]\s', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*\d+\.\s', multiLine: true), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}

class _PlacementReadinessSummary extends StatelessWidget {
  const _PlacementReadinessSummary({required this.state});

  final SocialPlacementState state;

  @override
  Widget build(BuildContext context) {
    if (state.isBusy) {
      return const Padding(
        padding: EdgeInsets.only(top: AppThemeTokens.spacing3),
        child: LinearProgressIndicator(),
      );
    }
    final platforms = state.displayPlatforms;
    if (platforms.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppThemeTokens.spacing4,
        AppThemeTokens.spacing3,
        AppThemeTokens.spacing4,
        AppThemeTokens.spacing1,
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppThemeTokens.spacing3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Asset readiness'),
                style: theme.textTheme.titleSmall,
              ),
              for (final platform in platforms)
                Padding(
                  padding: const EdgeInsets.only(top: AppThemeTokens.spacing2),
                  child: _PlacementPlatformRow(platform: platform),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlacementPlatformRow extends StatelessWidget {
  const _PlacementPlatformRow({required this.platform});

  final PlatformPlacementPlan platform;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocked = !platform.canPublish;
    final color = blocked ? theme.colorScheme.error : AppTheme.approveColor;
    final attached = platform.slots.where((slot) => slot.isAttached).length;
    return Row(
      children: [
        Icon(
          blocked ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
          color: color,
          size: AppThemeTokens.textLg,
        ),
        const SizedBox(width: AppThemeTokens.spacing2),
        Expanded(
          child: Text(
            '${platform.label} · $attached/${platform.slots.length}',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Text(
          blocked ? context.tr('Blocked') : context.tr('Ready'),
          style: theme.textTheme.labelMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

// ─── Twitter ────────────────────────────────────────────────

class _TwitterPreview extends StatelessWidget {
  const _TwitterPreview({required this.body, required this.charCount});
  final String body;
  final int charCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overLimit = charCount > 280;
    return _PreviewCard(
      platform: context.tr('Twitter / X'),
      icon: Icons.alternate_email,
      color: AppTheme.infoColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: AppRadii.avatar,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.person, size: AppSizes.iconXl),
              ),
              const SizedBox(width: AppSpacing.compact),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('Your Name'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: AppText.sm,
                      )),
                  Text(
                    '@yourhandle',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: AppText.xs,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.compact),
          Text(
            body,
            style: TextStyle(
              fontSize: AppText.sm,
              height: AppLineHeight.relaxed,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '$charCount/280',
                style: TextStyle(
                  fontSize: AppText.xs,
                  color: overLimit
                      ? AppTheme.rejectColor
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: overLimit ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── LinkedIn ───────────────────────────────────────────────

class _LinkedInPreview extends StatelessWidget {
  const _LinkedInPreview({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PreviewCard(
      platform: context.tr('LinkedIn'),
      icon: Icons.work_outline,
      color: AppTheme.editColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: AppRadii.avatarLarge,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.person, size: AppSizes.iconXxl),
              ),
              const SizedBox(width: AppSpacing.compact),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('Your Name'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: AppText.sm,
                      )),
                  Text(context.tr('Your Headline'),
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: AppText.xs,
                      )),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: TextStyle(
              fontSize: AppText.sm,
              height: AppLineHeight.comfortable,
            ),
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _LinkedInAction(icon: Icons.thumb_up_outlined, label: context.tr('Like')),
              _LinkedInAction(icon: Icons.comment_outlined, label: context.tr('Comment')),
              _LinkedInAction(icon: Icons.repeat, label: context.tr('Repost')),
              _LinkedInAction(icon: Icons.send_outlined, label: context.tr('Send')),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinkedInAction extends StatelessWidget {
  const _LinkedInAction({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: AppSizes.iconLarge,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: AppSpacing.xxsHalf),
        Text(
          label,
          style: TextStyle(
            fontSize: AppText.xxs,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─── Instagram ──────────────────────────────────────────────

class _InstagramPreview extends StatelessWidget {
  const _InstagramPreview({required this.body});
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PreviewCard(
      platform: context.tr('Instagram'),
      icon: Icons.camera_alt_outlined,
      color: AppTheme.colorForContentType('Reel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Center(
              child: Icon(
                Icons.image,
                size: AppSizes.handle,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.compact),
          RichText(
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(
                fontSize: AppText.compact,
                color: theme.colorScheme.onSurface,
                height: AppLineHeight.relaxed,
              ),
              children: [
                TextSpan(text: '${context.tr('yourhandle')} ', style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Blog ───────────────────────────────────────────────────

class _BlogPreview extends StatelessWidget {
  const _BlogPreview({required this.title, required this.body, required this.platform});
  final String title;
  final String body;
  final String platform;

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      platform: platform == 'ghost' ? context.tr('Ghost') : context.tr('WordPress'),
      icon: platform == 'ghost' ? Icons.edit_note : Icons.language,
      color: platform == 'ghost' ? Theme.of(context).colorScheme.onSurface : AppTheme.infoColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: AppText.xxl,
              fontWeight: FontWeight.w800,
              height: AppLineHeight.snug,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: TextStyle(
              fontSize: AppText.compact,
              height: AppLineHeight.spacious,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 10,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── YouTube ────────────────────────────────────────────────

class _YouTubePreview extends StatelessWidget {
  const _YouTubePreview({required this.title, required this.description});
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PreviewCard(
      platform: context.tr('YouTube'),
      icon: Icons.play_circle_outline,
      color: AppTheme.rejectColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Center(
              child: Icon(
                Icons.play_arrow,
                size: AppSizes.handle,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.compact),
          Text(
            title,
            style: TextStyle(
              fontSize: AppText.medium,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            description,
            style: TextStyle(
              fontSize: AppText.xs,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── TikTok ─────────────────────────────────────────────────

class _TikTokPreview extends StatelessWidget {
  const _TikTokPreview({required this.caption});
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PreviewCard(
      platform: context.tr('TikTok'),
      icon: Icons.music_note,
      color: theme.colorScheme.onSurface,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('@${context.tr('yourhandle')}',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: AppText.sm,
                )),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              caption,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: AppText.xs,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared Card ────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.platform,
    required this.icon,
    required this.color,
    required this.child,
  });

  final String platform;
  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Platform header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.contentInset,
              vertical: AppSpacing.xs,
            ),
            color: color.withValues(alpha: AppOpacity.subtle),
            child: Row(
              children: [
                Icon(icon, size: AppSizes.iconLarge, color: color),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  platform,
                  style: TextStyle(
                    fontSize: AppText.compact,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: palette.elevatedSurface,
            child: DefaultTextStyle(
              style: TextStyle(color: theme.colorScheme.onSurface),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
