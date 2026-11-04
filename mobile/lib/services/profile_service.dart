// =============================================================================
// PROFILE SERVICE - IN-MEMORY VERSION (lost when the app closes)
//
// Holds the user's saved details (My details, Medical history, Lifestyle check)
// so the Quick Prediction and Deep-Check screens can pre-fill them.
//
// YOUR TASK U2 (docs/improvement_plan.md): replace the BODIES of load() and the
// three save...() functions with Firestore reads/writes of users/{uid}, using the
// layout in docs/lifestyle_check_proposal.md section D. The screens only use
// these functions and [details], so no screen changes. Remember to extend
// firebase/firestore.rules first: today it only allows 5 fields on a user.
// =============================================================================
import 'package:flutter/foundation.dart';

import '../models/user_details.dart';

class ProfileService {
  ProfileService({UserDetails? initial}) {
    if (initial != null) details.value = initial;
  }

  /// The screens listen to this and redraw when it changes (like HistoryService).
  final ValueNotifier<UserDetails> details = ValueNotifier(const UserDetails());

  /// Load the signed-in user's details. Firestore version: read users/{uid}.
  Future<void> load(String uid) async {}

  Future<void> saveProfile(UserProfile profile) async {
    details.value = details.value.copyWith(profile: profile);
  }

  Future<void> saveHistory(MedicalHistory history) async {
    details.value = details.value.copyWith(history: history);
  }

  Future<void> saveLifestyle(LifestyleAnswers lifestyle) async {
    details.value = details.value.copyWith(lifestyle: lifestyle);
  }

  /// Weight changes, so it is asked every check; the last value pre-fills the next.
  Future<void> saveLastWeight(double kg) async {
    details.value = details.value.copyWith(lastWeightKg: kg);
  }
}
