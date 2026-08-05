import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

Future<bool> showAppExitConfirmationDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.tr('Close ContentGlows?')),
      content: Text(
        context.tr("Are you sure you want to close the application?"),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(context.tr('Stay')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(context.tr('Close app')),
        ),
      ],
    ),
  );

  return confirmed == true;
}

Future<void> confirmAndExitApp(BuildContext context) async {
  final shouldExit = await showAppExitConfirmationDialog(context);
  if (!context.mounted || !shouldExit) {
    return;
  }

  await SystemNavigator.pop();
}
