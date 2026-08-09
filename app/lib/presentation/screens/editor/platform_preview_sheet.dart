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
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(context.tr('Platform Previews'),
                style: theme.textTheme.titleMedium),
          ),
          _PlacementReadinessSummary(state: placementState),
          const SizedBox(height: AppThemeTokens.spacing3),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
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
              CircleAvatar(radius: 18, backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.person, size: 20)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('Your Name'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(
                    '@yourhandle',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(body, style: const TextStyle(fontSize: 14, height: 1.5)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '$charCount/280',
                style: TextStyle(
                  fontSize: 12,
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
              CircleAvatar(radius: 22, backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.person, size: 24)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('Your Name'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(context.tr('Your Headline'),
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      )),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(body, style: const TextStyle(fontSize: 14, height: 1.6), maxLines: 8, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
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
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
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
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                Icons.image,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 10),
          RichText(
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface,
                height: 1.5,
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
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.3)),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(fontSize: 13, height: 1.7, color: Theme.of(context).colorScheme.onSurface),
              maxLines: 10, overflow: TextOverflow.ellipsis),
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
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                Icons.play_arrow,
                size: 40,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), maxLines: 2),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
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
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('@${context.tr('yourhandle')}',
                style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 4),
            Text(caption, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 12), maxLines: 3, overflow: TextOverflow.ellipsis),
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
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Platform header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: color.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(platform, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
          // Content
          Container(
            padding: const EdgeInsets.all(16),
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
