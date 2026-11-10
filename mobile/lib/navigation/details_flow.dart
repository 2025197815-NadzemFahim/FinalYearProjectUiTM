// "Complete your details" flow: My details -> Medical history -> Lifestyle check,
// showing only the parts that are still missing.
//
// Registration sends the user back to Login (use case Table 3.12), so this runs
// the first time a signed-in user starts a check (or taps the banner on Main):
// in practice it is the sign-up questions, asked once.
import 'package:flutter/material.dart';

import '../screens/lifestyle_check_screen.dart';
import '../screens/medical_history_screen.dart';
import '../screens/my_details_screen.dart';
import '../services/app_services.dart';
import '../widgets/error_dialog.dart';

/// Returns true when everything is complete (now or already), false if the user
/// stopped part-way (pressed back or "Not now").
Future<bool> ensureDetailsComplete(BuildContext context, AppServices services) async {
  final profile = services.profile;

  // Right after login the saved details may still be on their way from the
  // database. Wait for them, so we never ask for answers the user already gave.
  await profile.ready;
  if (!context.mounted) return false;

  // Could not read them (e.g. offline)? Don't ask everything again: say why.
  final loadError = profile.loadError.value;
  if (loadError != null) {
    await showErrorDialog(context, 'Saved details not loaded', loadError);
    return false;
  }

  if (profile.details.value.isComplete) return true;

  // Age and sex are asked ONLY at Create Account (decision 2026-11-04), so the
  // app can't ask for them here. Accounts made before details were saved to the
  // database (or by an old seed) don't have them: create a new account.
  if (!profile.details.value.profile.accountComplete) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Account details missing'),
        content: const Text('Your date of birth and sex are entered when you create your '
            'account, but they could not be found for this account. Please create a new '
            'account to use the checks.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
    return false;
  }

  final start = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Complete your details'),
      content: const Text('About 2 minutes. We ask these once and reuse them in every check, '
          'so each check only asks what changes.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Not now')),
        FilledButton(
          key: const Key('startDetails'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Start'),
        ),
      ],
    ),
  );
  if (start != true || !context.mounted) return false;

  // Each step opens only if that part is missing; stop if the user backs out.
  final steps = <(bool Function(), Widget Function())>[
    (() => profile.details.value.profile.detailsComplete, () => MyDetailsScreen(services: services)),
    (() => profile.details.value.history.isComplete, () => MedicalHistoryScreen(services: services)),
    (() => profile.details.value.lifestyle.isComplete, () => LifestyleCheckScreen(services: services)),
  ];
  for (final (isDone, screen) in steps) {
    if (isDone()) continue;
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => screen()));
    if (saved != true || !context.mounted) return false;
  }
  return profile.details.value.isComplete;
}
