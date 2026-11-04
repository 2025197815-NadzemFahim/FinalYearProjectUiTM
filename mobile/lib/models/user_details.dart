// =============================================================================
// The user's saved details: asked ONCE, then used to pre-fill every check.
// Approved in docs/input_readings.md (CHECKPOINT 5) and
// docs/lifestyle_check_proposal.md (CHECKPOINT 6):
//   UserProfile     readings 1-9   (My details: stable facts)
//   MedicalHistory  readings 10-14 ("Has a doctor ever told you...")
//   LifestyleAnswers readings 15-19 (the retakeable Lifestyle check)
//
// Only the user's RAW answers are stored here ("SPM", "1-2 times a week").
// They are turned into model codes at prediction time in api_payloads.dart,
// so changing a mapping never leaves stale codes in the database.
// =============================================================================

/// Highest education completed (Malaysian wording). The BRFSS code it maps to
/// is in api_payloads.dart (table E of the proposal).
enum Education {
  none('No formal schooling'),
  primary('Primary school only (Standard 1-6)'),
  someSecondary('Some secondary school, did not complete SPM'),
  spm('SPM (completed Form 5)'),
  postSecondary('STPM, Matriculation, Diploma, certificate or some university'),
  degree("Bachelor's degree or higher");

  const Education(this.label);
  final String label;
}

/// Main type of work over the user's working life (proposal W1).
enum WorkType {
  private('Private sector employee'),
  selfEmployed('Self-employed, business owner or gig worker'),
  government('Government / public servant (incl. teachers, police, armed forces)'),
  neverWorked('Never had a paid job');

  const WorkType(this.label);
  final String label;
}

enum Residence {
  urban('Urban (town or city)'),
  rural('Rural (village or countryside)');

  const Residence(this.label);
  final String label;
}

/// Readings 1-9. Null = not answered yet.
class UserProfile {
  const UserProfile({
    this.dateOfBirth,
    this.sex,
    this.heightCm,
    this.education,
    this.incomeMonthlyRm,
    this.healthCoverage,
    this.everMarried,
    this.workType,
    this.residence,
  });

  final DateTime? dateOfBirth;
  final String? sex;              // 'male' or 'female' (the API's spelling)
  final double? heightCm;
  final Education? education;
  final double? incomeMonthlyRm;  // monthly HOUSEHOLD income in ringgit
  final bool? healthCoverage;     // option (i): citizen, insurance/takaful or panel clinic
  final bool? everMarried;        // divorced / widowed count as yes
  final WorkType? workType;
  final Residence? residence;

  bool get isComplete => dateOfBirth != null && sex != null && heightCm != null &&
      education != null && incomeMonthlyRm != null && healthCoverage != null &&
      everMarried != null && workType != null && residence != null;

  /// Age in whole years on [day]: recalculated every check, so it never goes stale.
  int? ageOn(DateTime day) {
    final dob = dateOfBirth;
    if (dob == null) return null;
    var age = day.year - dob.year;
    if (day.month < dob.month || (day.month == dob.month && day.day < dob.day)) age--;
    return age;
  }
}

/// Readings 10-14: "Has a doctor, nurse or other health professional ever told you...".
class MedicalHistory {
  const MedicalHistory({
    this.highBloodPressure,
    this.highCholesterol,
    this.cholesterolChecked5y,
    this.heartDisease,
    this.difficultyWalking,
    this.updatedAt,
  });

  final bool? highBloodPressure;    // feeds Quick, Stroke AND Diabetes
  final bool? highCholesterol;
  final bool? cholesterolChecked5y;
  final bool? heartDisease;         // Stroke + Diabetes
  final bool? difficultyWalking;
  final DateTime? updatedAt;

  bool get isComplete => highBloodPressure != null && highCholesterol != null &&
      cholesterolChecked5y != null && heartDisease != null && difficultyWalking != null;
}

/// Answers to "In the past 30 days, not counting your job, how often did you exercise?"
enum ActivityAnswer {
  threePlusWeekly('3 or more times a week', 'Active'),
  oneTwoWeekly('1-2 times a week', 'Semi-active'),
  fewTimesMonth('A few times this month (less than weekly)', 'Semi-active'),
  none('Not at all', 'Inactive');

  const ActivityAnswer(this.label, this.level);
  final String label;
  final String level; // what the user sees; the model only gets yes/no
}

/// Answers to "How often do you eat fruit / vegetables?"
enum FoodFrequency {
  twoPlusDaily('2 or more times a day'),
  onceDaily('Once a day'),
  fewTimesWeek('A few times a week'),
  rarely('Rarely or never');

  const FoodFrequency(this.label);
  final String label;

  /// The model's cut-off is fixed by BRFSS: at least once a day.
  bool get daily => this == twoPlusDaily || this == onceDaily;
}

/// Readings 15-19: the Lifestyle check.
class LifestyleAnswers {
  const LifestyleAnswers({
    this.smoked100,
    this.smokesNow,
    this.activity,
    this.fruit,
    this.vegetables,
    this.drinksAlcohol,
    this.drinksPerWeek,
    this.updatedAt,
  });

  final bool? smoked100;      // "at least 100 cigarettes (about 5 packs) in your whole life?"
  final bool? smokesNow;      // "smoke cigarettes now, every day or on some days?"
  final ActivityAnswer? activity;
  final FoodFrequency? fruit;
  final FoodFrequency? vegetables;
  final bool? drinksAlcohol;
  final int? drinksPerWeek;   // only asked when drinksAlcohol == true
  final DateTime? updatedAt;

  /// Retake reminder after 90 days (CHECKPOINT 6 decision 7).
  static const retakeAfter = Duration(days: 90);

  bool get isComplete => smoked100 != null && smokesNow != null && activity != null &&
      fruit != null && vegetables != null && drinksAlcohol != null &&
      (drinksAlcohol == false || drinksPerWeek != null);

  bool needsRetake(DateTime now) =>
      updatedAt == null || now.difference(updatedAt!) > retakeAfter;

  /// 0 when the user doesn't drink.
  int get weeklyDrinks => drinksAlcohol == true ? (drinksPerWeek ?? 0) : 0;

  /// The four smoking rows of the proposal.
  String? get smokingLevel {
    if (smoked100 == null || smokesNow == null) return null;
    if (smokesNow!) return smoked100! ? 'Current smoker' : 'New / light smoker';
    return smoked100! ? 'Former smoker' : 'Never smoked';
  }

  /// None / Moderate / Heavy. Heavy = more than 14 drinks a week (men), 7 (women),
  /// the same rule the API applies (backend/app/conversion.py heavy_drinker).
  String alcoholLevel(String? sex) {
    final n = weeklyDrinks;
    if (n == 0) return 'None';
    return n > (sex == 'male' ? 14 : 7) ? 'Heavy' : 'Moderate';
  }
}

/// Everything saved for one user, plus the last weight typed (pre-fills the next check).
class UserDetails {
  const UserDetails({
    this.profile = const UserProfile(),
    this.history = const MedicalHistory(),
    this.lifestyle = const LifestyleAnswers(),
    this.lastWeightKg,
  });

  final UserProfile profile;
  final MedicalHistory history;
  final LifestyleAnswers lifestyle;
  final double? lastWeightKg;

  bool get isComplete => profile.isComplete && history.isComplete && lifestyle.isComplete;

  UserDetails copyWith({UserProfile? profile, MedicalHistory? history,
      LifestyleAnswers? lifestyle, double? lastWeightKg}) => UserDetails(
        profile: profile ?? this.profile,
        history: history ?? this.history,
        lifestyle: lifestyle ?? this.lifestyle,
        lastWeightKg: lastWeightKg ?? this.lastWeightKg,
      );
}
