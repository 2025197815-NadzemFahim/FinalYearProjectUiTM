// =============================================================================
// PROFILE SERVICE - IN-MEMORY VERSION (lost when the app closes)
//
// Holds the user's saved details (My details, Medical history, Lifestyle check)
// so the Quick Prediction and Deep-Check screens can pre-fill them.
//
// It also remembers WHOSE details they are ([uid]). When a different person
// logs in on the same device, startSession() forgets the previous user's
// details first, so nobody ever sees someone else's health answers.
//
// YOUR TASK U2 (docs/improvement_plan.md): replace the BODIES of load() and the
// save...() functions with Firestore reads/writes of users/{uid}, using the
// layout in docs/lifestyle_check_proposal.md section D. The screens only use
// these functions and [details], so no screen changes. The call sites are ready:
//  - load(uid) runs at every login (startSession, called by HomeShell)
//  - saveAccount runs while the new account is still signed in (register's
//    onCreated), which is when the rules let the app write users/{uid}
//  - the other save...() functions run while the user is signed in; use [uid]
// Remember to extend firebase/firestore.rules first: today it only allows 5
// fields on a user.
// =============================================================================
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/user_details.dart';

class ProfileService {
  /// [initial] + [ownerUid]: start with someone's details already loaded (tests).
  ProfileService({UserDetails? initial, String? ownerUid}) : _uid = ownerUid {
    if (initial != null) details.value = initial;
  }

  /// The screens listen to this and redraw when it changes (like HistoryService).
  final ValueNotifier<UserDetails> details = ValueNotifier(const UserDetails());

  String? _uid;

  /// The user these details belong to (null = nobody yet).
  String? get uid => _uid;

  /// Called at every login. A different person than last time? Forget the
  /// previous user's details FIRST (synchronously, before any screen draws),
  /// then load this user's.
  void startSession(String uid) {
    if (uid != _uid) {
      details.value = const UserDetails();
      _uid = uid;
    }
    unawaited(load(uid)); // "unawaited" = start it, don't wait (screens redraw when it lands)
  }

  /// Load the signed-in user's details. Firestore version: read users/{uid}.
  Future<void> load(String uid) async {}

  /// Called by Create Account (through register's onCreated): the only place date
  /// of birth, sex and contact are asked. Firestore version: write them to
  /// users/{uid}. A NEW account starts from empty details, so nothing from
  /// whoever used the device before (height, income...) is copied into it.
  Future<void> saveAccount({
    required String uid,
    required DateTime dateOfBirth,
    required String sex,
    required String contact,
  }) async {
    final base = uid == _uid ? details.value : const UserDetails();
    _uid = uid;
    final p = base.profile;
    details.value = base.copyWith(profile: UserProfile(
      dateOfBirth: dateOfBirth, sex: sex, contactNumber: contact,
      heightCm: p.heightCm, education: p.education, incomeMonthlyRm: p.incomeMonthlyRm,
      healthCoverage: p.healthCoverage, everMarried: p.everMarried, workType: p.workType,
      residence: p.residence,
    ));
  }

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
