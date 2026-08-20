import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_diagnostics.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../theme/app_theme.dart';

Future<void> copyDiagnosticsToClipboard(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String scope,
  String? currentError,
  Object? error,
  StackTrace? stackTrace,
  Map<String, Object?> contextData = const <String, Object?>{},
  List<String> extraLines = const <String>[],
  String successMessage = 'Diagnostics copied to clipboard.',
}) async {
  final diagnostics = ref.read(appDiagnosticsProvider);
  final authSession = ref.read(authSessionProvider);
  final accessState = ref.read(appAccessStateProvider).value;
  final report = diagnostics.buildReport(
    title: title,
    authSession: authSession,
    accessState: accessState,
    scope: scope,
    currentError: currentError,
    error: error,
    stackTrace: stackTrace,
    context: contextData,
    extraLines: extraLines,
  );

  await Clipboard.setData(ClipboardData(text: report));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(context.tr(successMessage)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void showDiagnosticSnackBar(
  BuildContext context,
  WidgetRef ref, {
  required String message,
  required String scope,
  Object? error,
  StackTrace? stackTrace,
  Map<String, Object?> contextData = const <String, Object?>{},
  Color? backgroundColor,
  SnackBarBehavior behavior = SnackBarBehavior.floating,
  ShapeBorder? shape,
  String copyLabel = 'Copy error',
}) {
  ref
      .read(appDiagnosticsProvider)
      .error(
        scope: scope,
        message: message,
        error: error,
        stackTrace: stackTrace,
        context: contextData,
      );

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor,
      behavior: behavior,
      shape: shape,
      action: SnackBarAction(
        label: context.tr(copyLabel),
        onPressed: () {
          unawaited(
            copyDiagnosticsToClipboard(
              context,
              ref,
              title: 'ContentGlows error diagnostics',
              scope: scope,
              currentError: message,
              error: error,
              stackTrace: stackTrace,
              contextData: contextData,
              successMessage: 'Error copied to clipboard.',
            ),
          );
        },
      ),
    ),
  );
}

void showCopyableDiagnosticSnackBar(
  BuildContext context,
  WidgetRef ref, {
  required String message,
  required String scope,
  Object? error,
  StackTrace? stackTrace,
  Map<String, Object?> contextData = const <String, Object?>{},
  Color? backgroundColor,
  SnackBarBehavior behavior = SnackBarBehavior.floating,
  ShapeBorder? shape,
  String copyLabel = 'Copy error',
}) {
  final resolvedBackgroundColor =
      backgroundColor ??
      Theme.of(
        context,
      ).colorScheme.error.withValues(alpha: AppOpacity.nearOpaqueStrong);
  final resolvedShape =
      shape ??
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md));

  showDiagnosticSnackBar(
    context,
    ref,
    message: message,
    scope: scope,
    error: error,
    stackTrace: stackTrace,
    contextData: contextData,
    backgroundColor: resolvedBackgroundColor,
    behavior: behavior,
    shape: resolvedShape,
    copyLabel: copyLabel,
  );
}

class AppErrorView extends ConsumerWidget {
  const AppErrorView({
    super.key,
    required this.scope,
    this.title = 'Something went wrong',
    this.message,
    this.error,
    this.stackTrace,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.copyLabel = 'Copy error',
    this.contextData = const <String, Object?>{},
    this.helperText,
    this.showIcon = true,
    this.compact = false,
  });

  final String scope;
  final String title;
  final String? message;
  final Object? error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;
  final String retryLabel;
  final String copyLabel;
  final Map<String, Object?> contextData;
  final String? helperText;
  final bool showIcon;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedMessage = _resolvedMessage();
    final localizedTitle = context.tr(title);
    final localizedCopyLabel = context.tr(copyLabel);
    final localizedRetryLabel = context.tr(retryLabel);
    final localizedHelperText = helperText == null
        ? null
        : context.tr(helperText!);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(
            alpha: compact ? 0.4 : 0.6,
          ),
          borderRadius: BorderRadius.circular(AppRadii.preview),
          border: Border.all(
            color: colorScheme.error.withValues(alpha: AppOpacity.emphasis),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: compact
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            if (showIcon) ...[
              Icon(
                Icons.error_outline_rounded,
                size: compact ? AppSizes.iconHero : AppSizes.handle,
                color: colorScheme.error,
              ),
              SizedBox(
                height: compact
                    ? AppSpacing.compact
                    : AppSpacing.contentInset,
              ),
            ],
            Text(
              localizedTitle,
              textAlign: compact ? TextAlign.left : TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SelectableText(
              resolvedMessage,
              textAlign: compact ? TextAlign.left : TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer.withValues(
                  alpha: AppOpacity.nearOpaque,
                ),
                height: AppLineHeight.readable,
              ),
            ),
            if (localizedHelperText != null &&
                localizedHelperText.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                localizedHelperText,
                textAlign: compact ? TextAlign.left : TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onErrorContainer.withValues(
                    alpha: AppOpacity.threeQuarter,
                  ),
                  height: AppLineHeight.body,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.contentInset),
            Wrap(
              spacing: AppSpacing.compact,
              runSpacing: AppSpacing.compact,
              alignment: compact ? WrapAlignment.start : WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    unawaited(
                      copyDiagnosticsToClipboard(
                        context,
                        ref,
                        title: 'ContentGlows error diagnostics',
                        scope: scope,
                        currentError: resolvedMessage,
                        error: error,
                        stackTrace: stackTrace,
                        contextData: contextData,
                        successMessage: 'Error copied to clipboard.',
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: AppSizes.iconLarge,
                  ),
                  label: Text(localizedCopyLabel),
                ),
                if (onRetry != null)
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: AppSizes.iconLarge,
                    ),
                    label: Text(localizedRetryLabel),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _resolvedMessage() {
    final trimmed = message?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return AppDiagnostics.formatError(error);
  }
}
