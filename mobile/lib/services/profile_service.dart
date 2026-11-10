// =============================================================================
// PROFILE SERVICE: the user's saved details, kept in Firestore users/{uid}.
//
// What the screens use:
//   details     everything saved (My details, Medical history, Lifestyle check,
//               last weight). A ValueNotifier: screens redraw when it changes.
//   loading     true while the details are being read after login
//   loadError   a message when they could not be read (Main shows it + "Try again")
//   ready       a Future that completes when that read has finished
//   save...()   write one part; throws ProfileFailure if the database refuses
//
// Two modes:
//   ProfileService(db: FirebaseFirestore.instance)   the real app (main.dart)
//   ProfileService()                                  no database, memory only
//                                                     (the tests: fast, offline)
//
// Shared device: it remembers WHOSE details it holds ([uid]). When a different
// person logs in, startSession() forgets the previous user's details first, so
// nobody ever sees someone else's health answers.
//
// The field layout is in services/firestore_maps.dart; the rules that check
// every field are in firebase/firestore.rules.
// =============================================================================
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_details.dart';
import 'auth_service.dart';
import 'firestore_maps.dart';

/// A save the database refused. [message] is shown to the user as is.
class ProfileFailure implements Exception {
  const ProfileFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

class ProfileService {
  /// [initial] + [ownerUid]: start with someone's details already loaded (tests).
  ProfileService({FirebaseFirestore? db, UserDetails? initial, String? ownerUid})
      : _db = db,
        _uid = ownerUid {
    if (initial != null) details.value = initial;
  }

  /// How long a read or save may wait for the database before we stop waiting.
  static const timeout = Duration(seconds: 10);

  final FirebaseFirestore? _db; // null = no database (tests)

  final ValueNotifier<UserDetails> details = ValueNotifier(const UserDetails());
  final ValueNotifier<bool> loading = ValueNotifier(false);
  final ValueNotifier<String?> loadError = ValueNotifier(null);

  String? _uid; // whose details are in [details] (null = nobody yet)
  int _saves = 0; // counts saves, so a slow load never overwrites a newer save
  Future<void> _lastLoad = Future.value();

  /// The user these details belong to.
  String? get uid => _uid;

  /// Completes when the read started at login has finished. The checks wait for
  /// it, so they never ask for details that are simply still loading.
  Future<void> get ready => _lastLoad;

  // ------------------------------------------------------------------ loading

  /// Called at every login (HomeShell). A different person than last time?
  /// Forget the previous user's details FIRST (before any screen draws), then
  /// read this user's.
  void startSession(String uid) {
    if (uid != _uid) {
      details.value = const UserDetails();
      _uid = uid;
    }
    _lastLoad = load(uid);
  }

  /// "Try again" on Main, after a failed load.
  void reload() {
    final uid = _uid;
    if (uid != null) _lastLoad = load(uid);
  }

  /// Read users/{uid} into [details]. Never throws: a problem goes to [loadError].
  Future<void> load(String uid) async {
    final db = _db;
    if (db == null) return; // no database: keep what is in memory

    final savesBefore = _saves;
    loading.value = true;
    loadError.value = null;

    try {
      final snapshot = await db.collection('users').doc(uid).get().timeout(timeout);

      // While we waited, did someone else log in, or did the user save something?
      // Then this answer is out of date: drop it.
      if (uid != _uid || _saves != savesBefore) return;

      final doc = snapshot.data();
      details.value = doc == null ? const UserDetails() : FirestoreMaps.fromUserDoc(doc);
    } catch (e) {
      if (uid == _uid) loadError.value = 'Your saved details could not be loaded. ${_reason(e)}';
    } finally {
      if (uid == _uid) loading.value = false;
    }
  }

  // ------------------------------------------------------------------- saving

  /// Create Account: the ONLY place date of birth, sex and contact are asked.
  /// register() runs this while the new account is still signed in (its
  /// onCreated), which is when the rules let the app create users/{uid}.
  ///
  /// A new account starts from empty details, so nothing from whoever used the
  /// device before (height, income...) is copied into it.
  Future<void> saveAccount({
    required AppUser user,
    required DateTime dateOfBirth,
    required String sex,
    required String contact,
  }) async {
    final fields = FirestoreMaps.toNewAccount(
      name: user.displayName ?? '',
      email: user.email ?? '',
      dateOfBirth: dateOfBirth,
      sex: sex,
      contact: contact,
    );
    await _write(user.uid, fields, create: true);

    _uid = user.uid;
    _changed(UserDetails(
      profile: UserProfile(dateOfBirth: dateOfBirth, sex: sex, contactNumber: contact),
    ));
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _write(_uid, {'profile': FirestoreMaps.toMyDetails(profile)});
    _changed(details.value.copyWith(profile: profile));
  }

  Future<void> saveHistory(MedicalHistory history) async {
    await _write(_uid, {'history': FirestoreMaps.toMedicalHistory(history)});
    _changed(details.value.copyWith(history: history));
  }

  Future<void> saveLifestyle(LifestyleAnswers lifestyle) async {
    await _write(_uid, {'lifestyle': FirestoreMaps.toLifestyle(lifestyle)});
    _changed(details.value.copyWith(lifestyle: lifestyle));
  }

  /// Weight changes, so it is asked at every check; the last value pre-fills the
  /// next one. It must never slow down or stop a check, so it is written in the
  /// background and a failure is only logged.
  Future<void> saveLastWeight(double kg) async {
    _changed(details.value.copyWith(lastWeightKg: kg));
    unawaited(
      _write(_uid, {'lastWeightKg': kg})
          .catchError((Object e) => debugPrint('Last weight not saved: $e')),
    );
  }

  // ------------------------------------------------------------------ helpers

  void _changed(UserDetails next) {
    _saves++;
    details.value = next;
  }

  /// Send [fields] to users/{uid}.
  ///   create: true  -> make the document (Create Account)
  ///   create: false -> replace only these fields, keep the others
  ///
  /// No answer within [timeout]? Firestore keeps the change on the device and
  /// sends it when the connection is back, so for edits we carry on. Not for
  /// Create Account: the user is signed out straight after, and a change sent
  /// later without a signed-in user would be refused.
  Future<void> _write(String? uid, Map<String, Object> fields, {bool create = false}) async {
    final db = _db;
    if (db == null) return; // no database (tests): memory only
    if (uid == null) throw const ProfileFailure('You are not signed in.');

    final doc = db.collection('users').doc(uid);
    try {
      await (create ? doc.set(fields) : doc.update(fields)).timeout(timeout);
    } on TimeoutException catch (e) {
      if (create) throw ProfileFailure(_reason(e));
      debugPrint('No answer from the database yet; Firestore will send the change later.');
    } on FirebaseException catch (e) {
      throw ProfileFailure(_reason(e));
    }
  }

  /// Database errors -> a sentence the user can act on.
  static String _reason(Object error) {
    if (error is TimeoutException) {
      return 'No answer from the database. Check your internet connection '
          '(or that the Firebase emulator is running), then try again.';
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'The database refused this change (permission denied).';
        case 'not-found':
          return 'Your account record was not found in the database.';
        case 'unavailable':
          return 'No connection to the database. Check your internet connection '
              '(or that the Firebase emulator is running).';
      }
      return 'Database error: ${error.code}.';
    }
    return '$error';
  }
}
