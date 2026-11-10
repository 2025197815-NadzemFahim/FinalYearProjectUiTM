// =============================================================================
// HISTORY SERVICE: the user's past deep-check results (FR-10, Figure 3.23).
//
// Where they come from: the backend saves every signed-in deep check to
// Firestore users/{uid}/deepCheckResults. Only the backend may write there (so
// nobody can fake a risk %); this service READS them, newest first.
//
// What the History tab uses:
//   entries   the cards (a ValueNotifier: the screen redraws when it changes)
//   loading   true while reading
//   error     a message when the read failed (shown with a "Try again" button)
//   refresh() read again (pull down on History, or "Try again")
//
// Two modes:
//   HistoryService(db: FirebaseFirestore.instance)  the real app: the user's results
//   HistoryService()                                 no database: the 7 sample cards
//                                                    of Figure 3.23 (the tests)
// =============================================================================
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/disease.dart';
import '../models/history_entry.dart';
import 'firestore_maps.dart';
import 'prediction_service.dart';

class HistoryService {
  HistoryService({FirebaseFirestore? db}) : _db = db {
    if (db == null) entries.value = _sampleEntries();
  }

  /// The History tab shows at most this many results (the newest ones).
  static const maxResults = 100;

  final FirebaseFirestore? _db; // null = no database (tests)

  final ValueNotifier<List<HistoryEntry>> entries = ValueNotifier(const []);
  final ValueNotifier<bool> loading = ValueNotifier(false);
  final ValueNotifier<String?> error = ValueNotifier(null);

  String? _uid; // whose results are in [entries] (null = nobody yet)

  /// Called at every login (HomeShell). A different person than last time never
  /// sees the previous user's results: the list is emptied first, then read.
  void startSession(String uid) {
    if (uid != _uid) {
      entries.value = _db == null ? _sampleEntries() : const [];
      error.value = null;
      _uid = uid;
    }
    unawaited(refresh()); // "unawaited" = start it, don't wait (the screen redraws when it lands)
  }

  /// Read the signed-in user's results from Firestore, newest first.
  /// Never throws: a problem goes to [error].
  Future<void> refresh() async {
    final db = _db, uid = _uid;
    if (db == null || uid == null) return; // no database: keep the samples

    loading.value = true;
    error.value = null;

    try {
      final snapshot = await db
          .collection('users')
          .doc(uid)
          .collection('deepCheckResults')
          .orderBy('created_at', descending: true) // newest first
          .limit(maxResults)
          .get()
          .timeout(const Duration(seconds: 10));

      if (uid != _uid) return; // someone else logged in while we waited

      // Number the cards like the mockup: the oldest is "Diagnosis 1".
      final docs = snapshot.docs;
      final list = <HistoryEntry>[];
      for (var i = 0; i < docs.length; i++) {
        final entry = FirestoreMaps.fromResultDoc(docs[i].data(), title: 'Diagnosis ${docs.length - i}');
        if (entry != null) list.add(entry);
      }
      entries.value = list;
    } on TimeoutException {
      if (uid == _uid) {
        error.value = 'No answer from the database. Check your internet connection '
            '(or that the Firebase emulator is running).';
      }
    } catch (e) {
      if (uid == _uid) error.value = 'Your history could not be loaded ($e).';
    } finally {
      if (uid == _uid) loading.value = false;
    }
  }

  /// A new deep-check result, shown at once (flowchart: "Save the prediction
  /// result in Database"). The backend has already saved it to Firestore, so the
  /// next refresh() reads the same result back.
  void add(RiskResult result) {
    final next = HistoryEntry(
      title: 'Diagnosis ${entries.value.length + 1}',
      result: result,
      // the API's own notes + disclaimer when there are some
      explanation: result.explanation ?? PredictionService.deepExplanation(result),
      date: DateTime.now(),
    );
    // Make a NEW list (newest first) instead of changing the old one, so the
    // notifier sees a different value and tells the screen to rebuild.
    entries.value = [next, ...entries.value];
  }

  /// The sample cards of Figure 3.23 (Diagnosis 1-7 on four dates), used when
  /// there is no database.
  static List<HistoryEntry> _sampleEntries() {
    final now = DateTime.now();

    // (days ago, disease, percent) for Diagnosis 7 down to Diagnosis 1
    final samples = <(int, Disease, double)>[
      (0, Disease.heart, 80),
      (40, Disease.diabetes, 62),
      (40, Disease.stroke, 35),
      (68, Disease.heart, 55),
      (68, Disease.diabetes, 28),
      (68, Disease.stroke, 18),
      (101, Disease.heart, 47),
    ];

    return [
      for (var i = 0; i < samples.length; i++)
        HistoryEntry(
          title: 'Diagnosis ${samples.length - i}',
          result: RiskResult(disease: samples[i].$2, percent: samples[i].$3),
          explanation: PredictionService.deepExplanation(
              RiskResult(disease: samples[i].$2, percent: samples[i].$3)),
          date: now.subtract(Duration(days: samples[i].$1)),
        ),
    ];
  }
}
