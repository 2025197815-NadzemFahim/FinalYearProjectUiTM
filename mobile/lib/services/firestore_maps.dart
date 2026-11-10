// =============================================================================
// FIRESTORE MAPS: how the app's data is written to, and read from, the database.
//
// Firestore stores every document as a map (key -> value), so each data class
// needs two directions:
//   to...()    Dart object  -> map  (saving)
//   from...()  map          -> Dart object (loading)
//
// users/{uid}                                        docs/DATABASE.md section 4
//   userName, userEmail, userSex, userCreate_at      from Create Account
//   dateOfBirth, contactNumber                       from Create Account
//   profile   { heightCm, education, incomeMonthlyRm, healthCoverage,
//               everMarried, workType, residence }            My details
//   history   { highBloodPressure, highCholesterol, cholesterolChecked5y,
//               heartDisease, difficultyWalking, updatedAt }  Medical history
//   lifestyle { smoked100, smokesNow, activity, fruit, vegetables,
//               drinksAlcohol, drinksPerWeek, updatedAt }     Lifestyle check
//   lastWeightKg                                     pre-fills the next check
//
// users/{uid}/deepCheckResults/{resultID}            written ONLY by the backend
//
// Choices are stored by their enum NAME ("spm", "oneTwoWeekly"): readable in the
// Emulator UI, and still correct if the options are ever reordered in the code.
//
// firebase/firestore.rules checks every field below. Add a field here -> add it
// to the rules too, or the database will refuse the save.
// =============================================================================
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/disease.dart';
import '../models/history_entry.dart';
import '../models/user_details.dart';
import 'prediction_service.dart';

class FirestoreMaps {
  // ------------------------------------------------------------ saving (to...)

  /// The first version of users/{uid}, written once by Create Account.
  static Map<String, Object> toNewAccount({
    required String name,
    required String email,
    required DateTime dateOfBirth,
    required String sex,
    required String contact,
  }) {
    return {
      'userName': name,
      'userEmail': email,
      'userSex': sex,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'contactNumber': contact,
      // The server's clock, not the phone's: the rules require it.
      'userCreate_at': FieldValue.serverTimestamp(),
    };
  }

  /// My details. Only called after the form checked that every answer is there,
  /// so the "!" (= "this is not null") is safe.
  static Map<String, Object> toMyDetails(UserProfile p) {
    return {
      'heightCm': p.heightCm!,
      'education': p.education!.name,
      'incomeMonthlyRm': p.incomeMonthlyRm!,
      'healthCoverage': p.healthCoverage!,
      'everMarried': p.everMarried!,
      'workType': p.workType!.name,
      'residence': p.residence!.name,
    };
  }

  static Map<String, Object> toMedicalHistory(MedicalHistory h) {
    return {
      'highBloodPressure': h.highBloodPressure!,
      'highCholesterol': h.highCholesterol!,
      'cholesterolChecked5y': h.cholesterolChecked5y!,
      'heartDisease': h.heartDisease!,
      'difficultyWalking': h.difficultyWalking!,
      'updatedAt': Timestamp.fromDate(h.updatedAt ?? DateTime.now()),
    };
  }

  static Map<String, Object> toLifestyle(LifestyleAnswers l) {
    return {
      'smoked100': l.smoked100!,
      'smokesNow': l.smokesNow!,
      'activity': l.activity!.name,
      'fruit': l.fruit!.name,
      'vegetables': l.vegetables!.name,
      'drinksAlcohol': l.drinksAlcohol!,
      // Only asked when the user drinks; left out (not stored as null) otherwise.
      if (l.drinksAlcohol == true) 'drinksPerWeek': l.drinksPerWeek!,
      'updatedAt': Timestamp.fromDate(l.updatedAt ?? DateTime.now()),
    };
  }

  // ---------------------------------------------------------- loading (from...)

  /// users/{uid} -> everything the screens pre-fill. A missing or unreadable
  /// field becomes null, which the app treats as "not answered yet".
  static UserDetails fromUserDoc(Map<String, dynamic> doc) {
    final profile = _map(doc['profile']);
    final history = _map(doc['history']);
    final lifestyle = _map(doc['lifestyle']);

    return UserDetails(
      profile: UserProfile(
        // from Create Account (top-level fields)
        dateOfBirth: _date(doc['dateOfBirth']),
        sex: _string(doc['userSex']),
        contactNumber: _string(doc['contactNumber']),
        // from My details (the "profile" map)
        heightCm: _double(profile['heightCm']),
        education: _choice(Education.values, profile['education']),
        incomeMonthlyRm: _double(profile['incomeMonthlyRm']),
        healthCoverage: _bool(profile['healthCoverage']),
        everMarried: _bool(profile['everMarried']),
        workType: _choice(WorkType.values, profile['workType']),
        residence: _choice(Residence.values, profile['residence']),
      ),
      history: MedicalHistory(
        highBloodPressure: _bool(history['highBloodPressure']),
        highCholesterol: _bool(history['highCholesterol']),
        cholesterolChecked5y: _bool(history['cholesterolChecked5y']),
        heartDisease: _bool(history['heartDisease']),
        difficultyWalking: _bool(history['difficultyWalking']),
        updatedAt: _date(history['updatedAt']),
      ),
      lifestyle: LifestyleAnswers(
        smoked100: _bool(lifestyle['smoked100']),
        smokesNow: _bool(lifestyle['smokesNow']),
        activity: _choice(ActivityAnswer.values, lifestyle['activity']),
        fruit: _choice(FoodFrequency.values, lifestyle['fruit']),
        vegetables: _choice(FoodFrequency.values, lifestyle['vegetables']),
        drinksAlcohol: _bool(lifestyle['drinksAlcohol']),
        drinksPerWeek: _int(lifestyle['drinksPerWeek']),
        updatedAt: _date(lifestyle['updatedAt']),
      ),
      lastWeightKg: _double(doc['lastWeightKg']),
    );
  }

  /// One users/{uid}/deepCheckResults document -> one History card.
  /// Returns null for a document the app can't show (e.g. an unknown disease).
  static HistoryEntry? fromResultDoc(Map<String, dynamic> doc, {required String title}) {
    final disease = _choice(Disease.values, doc['diseaseType']); // 'heart' / 'stroke' / 'diabetes'
    final percent = _double(doc['risk_percentage']);
    if (disease == null || percent == null) return null;

    final result = RiskResult(disease: disease, percent: percent);
    final notes = [for (final note in doc['explanation_text'] as List? ?? const []) '$note'];

    return HistoryEntry(
      title: title,
      result: result,
      explanation: PredictionService.explainWithNotes(result, notes),
      date: _date(doc['created_at']) ?? DateTime.now(),
    );
  }

  // ----------------------------------------------------------------- helpers
  // Each one returns null instead of crashing when a value is missing or has
  // the wrong type (e.g. a document edited by hand in the Emulator UI).

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  static String? _string(Object? value) => value is String ? value : null;

  static bool? _bool(Object? value) => value is bool ? value : null;

  /// Firestore gives back 170 (int) or 170.5 (double); both become a double.
  static double? _double(Object? value) => value is num ? value.toDouble() : null;

  static int? _int(Object? value) => value is num ? value.toInt() : null;

  /// Firestore dates come back as a Timestamp; the app uses DateTime.
  static DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : null;

  /// "spm" -> Education.spm. An unknown name gives null.
  static T? _choice<T extends Enum>(List<T> options, Object? name) => options.asNameMap()[name];
}
