// "Change password" for a signed-in user (Settings, Privacy & Security).
//
//   1. ask first:   "We will email a link to you@example.com."
//   2. Firebase emails the link (the same one Forgot password sends)
//   3. the user picks the new password on Firebase's page from that link
//
// So the app never sees or stores any password.
import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../widgets/error_dialog.dart';

Future<void> sendPasswordChangeLink(
  BuildContext context,
  AppServices services,
  String? email,
) async {
  if (email == null || email.isEmpty) {
    _tell(context, 'This account has no email address.');
    return;
  }

  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Change password?'),
      content: Text('We will email a link to $email. Open it to choose a new password.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
        FilledButton(
          key: const Key('confirmPasswordLink'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Send link'),
        ),
      ],
    ),
  );
  if (yes != true || !context.mounted) return;

  try {
    await services.auth.sendPasswordReset(email);
  } on AuthFailure catch (e) {
    if (context.mounted) await showErrorDialog(context, 'Could not send email', e.message);
    return;
  }

  if (context.mounted) _tell(context, 'Link sent to $email. Check your inbox.');
}

/// The small message that slides up from the bottom.
void _tell(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
