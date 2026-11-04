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

/// Returns true when everything is complete (now or already), false if the user
/// stopped part-way (pressed back or "Not now").
Future<bool> ensureDetailsComplete(BuildContext context, AppServices services) async {
  final profile = services.profile;
  if (profile.details.value.isComplete) return true;

  // Age and sex are asked ONLY at Create Account (decision 2026-11-04), so the
  // app can't ask for them here. Until profile saving is connected to Firestore
  // (task U2) they are only kept in memory: accounts created in an earlier run of
  // the app, or the seeded demo accounts, won't have them yet.
  if (!profile.details.value.profile.accountComplete) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Account details missing'),
        content: const Text('Your age and sex are entered when you create your account, '
            'but they could not be found for this account.'),
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
