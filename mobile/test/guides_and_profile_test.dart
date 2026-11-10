// Tests for the Health guides (task U5) and the Profile pages that had no
// mockup: My Activity, Settings, Privacy & Security.
//
// Run only these:  flutter test test/guides_and_profile_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:chronic_disease_app/models/disease.dart';
import 'package:chronic_disease_app/models/tutorial.dart';
import 'package:chronic_disease_app/screens/deep_check_input_screen.dart';
import 'package:chronic_disease_app/screens/deep_check_result_screen.dart';
import 'package:chronic_disease_app/services/app_services.dart';
import 'package:chronic_disease_app/services/prediction_service.dart';
import 'package:chronic_disease_app/services/profile_service.dart';
import 'package:chronic_disease_app/services/tutorial_service.dart';
import 'package:chronic_disease_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'api_payloads_test.dart' show sampleDetails;
import 'auth_flow_test.dart' show FakeAuthService, pumpApp, scrollAndTap, typeAndLogin;

/// Every guide id the app links to (models/tutorial.dart, class Guides).
const linkedGuides = [
  Guides.bloodPressure,
  Guides.weightBmi,
  Guides.cholesterol,
  Guides.bloodSugar,
  Guides.stressTest,
  Guides.chestPainEcg,
  Guides.readingResults,
  Guides.healthyHabits,
  Guides.strokeFast,
  Guides.infections,
];

/// Gives the app its files straight from disk, without waiting.
///
/// The app's normal reader (rootBundle) does real file work, and a widget
/// test's fake clock does not wait for that, so a tap on a (?) would seem to
/// do nothing. This reader answers at once. It reads the SAME
/// assets/tutorials.json, so the tests still check the real guides.
class DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(File(key).readAsBytesSync());
}

/// A TutorialService that reads through [DiskBundle].
TutorialService diskGuides() => TutorialService(bundle: DiskBundle());

/// Logs Ali in (complete details) and opens the Profile tab.
Future<FakeAuthService> openProfile(WidgetTester tester) async {
  final auth = await pumpApp(tester, details: sampleDetails(), tutorials: diskGuides());
  await typeAndLogin(tester, FakeAuthService.validEmail, FakeAuthService.validPassword);
  await tester.tap(find.text('Profile'));
  await tester.pumpAndSettle();
  return auth;
}

/// Shows ONE screen on its own (no login needed), with Ali's saved details.
Future<void> pumpScreen(WidgetTester tester, Widget Function(AppServices services) screen) async {
  tester.view.physicalSize = const Size(1800, 3000); // same size as pumpApp
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final services = AppServices(
    auth: FakeAuthService(),
    profile: ProfileService(initial: sampleDetails(), ownerUid: 'u1'),
    tutorials: diskGuides(),
  );
  await tester.pumpWidget(MaterialApp(home: screen(services)));
  await tester.pumpAndSettle();
}

/// The (?) button inside the box or drop-down with [key].
Finder helpIn(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byIcon(Icons.help_outline));

void main() {
  setUp(() => AppFonts.useGoogleFonts = false);

  // ----------------------------------------------------- the guides file
  group('assets/tutorials.json', () {
    // Read straight from the file: a broken guide fails here, not in the app.
    final json = jsonDecode(File('assets/tutorials.json').readAsStringSync());
    final topics = [
      for (final t in json['topics'] as List) TutorialTopic.fromJson(t as Map<String, dynamic>),
    ];

    test('every guide the app links to exists', () {
      final ids = topics.map((t) => t.id).toSet();
      for (final id in linkedGuides) {
        expect(ids, contains(id), reason: 'no guide with id "$id"');
      }
      expect(ids.length, topics.length, reason: 'two guides share an id');
    });

    test('every guide has a known icon, a summary and some text', () {
      for (final raw in json['topics'] as List) {
        expect(TutorialTopic.icons.keys, contains(raw['icon']), reason: '${raw['id']}: icon');
      }
      for (final t in topics) {
        expect(t.summary, isNotEmpty, reason: '${t.id}: summary');
        expect(t.sections, isNotEmpty, reason: '${t.id}: sections');
      }
    });
  });

  // ------------------------------------------------------ opening guides
  testWidgets('Profile -> Health guides -> one guide, with its video placeholder',
      (tester) async {
    await openProfile(tester);
    await scrollAndTap(tester, find.byKey(const Key('menuGuides')));
    expect(find.text('Health guides'), findsOneWidget);

    await scrollAndTap(tester, find.byKey(const Key('guide-blood-pressure')));
    expect(find.text('Measuring your blood pressure'), findsOneWidget);
    expect(find.byKey(const Key('videoPlaceholder')), findsOneWidget);
  });

  testWidgets('a banner on Main opens its guide', (tester) async {
    await pumpApp(tester, details: sampleDetails(), tutorials: diskGuides());
    await typeAndLogin(tester, FakeAuthService.validEmail, FakeAuthService.validPassword);

    await scrollAndTap(tester, find.byKey(const Key('banner-healthy-habits')));
    expect(find.text('Healthy habits for your heart'), findsOneWidget);
  });

  testWidgets('the (?) next to a reading opens the guide for it', (tester) async {
    await pumpScreen(tester, (s) => DeepCheckInputScreen(services: s, disease: Disease.diabetes));

    await tester.tap(helpIn('hba1c_level'));
    await tester.pumpAndSettle();
    expect(find.text('Blood sugar and HbA1c'), findsOneWidget);

    // Back to the form: the weight box links to the weight & BMI guide.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(helpIn('weight_kg'));
    await tester.pumpAndSettle();
    expect(find.text('Weight, height and BMI'), findsOneWidget);
  });

  testWidgets('heart: "What is a stress test?" opens the stress test guide', (tester) async {
    await pumpScreen(tester, (s) => DeepCheckInputScreen(services: s, disease: Disease.heart));

    await tester.tap(find.byKey(const Key('stressTestGuide')));
    await tester.pumpAndSettle();
    expect(find.text('The exercise stress test'), findsOneWidget);
  });

  testWidgets('a result links to "Understanding your results"', (tester) async {
    await pumpScreen(
      tester,
      (s) => DeepCheckResultScreen(
        services: s,
        result: const RiskResult(disease: Disease.stroke, percent: 35),
      ),
    );

    await scrollAndTap(tester, find.byKey(const Key('resultGuide')));
    expect(find.text('Understanding your results'), findsOneWidget);
  });

  // ------------------------------------------------------------- Profile
  testWidgets('Profile shows the initials of the name in the photo ring', (tester) async {
    await openProfile(tester);
    expect(
      find.descendant(of: find.byKey(const Key('profileInitials')), matching: find.text('AA')),
      findsOneWidget, // Ali Ahmad
    );
  });

  testWidgets('My Activity: the latest result and count per disease, and the details',
      (tester) async {
    await openProfile(tester);
    await scrollAndTap(tester, find.byKey(const Key('menuActivity')));

    // No database in tests: the 7 sample results (3 heart, 2 diabetes, 2 stroke).
    Finder inRow(String key, String text) =>
        find.descendant(of: find.byKey(Key(key)), matching: find.text(text));
    expect(inRow('activity-heart', '80%'), findsOneWidget);
    expect(inRow('activity-heart', '3 checks · latest: Today'), findsOneWidget);
    expect(inRow('activity-diabetes', '62%'), findsOneWidget);
    expect(inRow('activity-stroke', '35%'), findsOneWidget);

    // Ali's details are complete.
    expect(inRow('activityMyDetails', 'Complete'), findsOneWidget);
    expect(inRow('activityHistory', 'Complete'), findsOneWidget);
  });

  testWidgets('Settings: Change password emails a link to the signed-in address',
      (tester) async {
    final auth = await openProfile(tester);
    await scrollAndTap(tester, find.byKey(const Key('menuSettings')));

    // Cancel sends nothing.
    await tester.tap(find.byKey(const Key('settingsPassword')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(auth.resetEmails, isEmpty);

    // Send link.
    await tester.tap(find.byKey(const Key('settingsPassword')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmPasswordLink')));
    await tester.pumpAndSettle();
    expect(auth.resetEmails, [FakeAuthService.validEmail]);
    expect(find.textContaining('Link sent to'), findsOneWidget);
  });

  testWidgets('Settings: About shows the version and the disclaimer', (tester) async {
    await openProfile(tester);
    await scrollAndTap(tester, find.byKey(const Key('menuSettings')));

    await tester.tap(find.byKey(const Key('settingsAbout')));
    await tester.pumpAndSettle();
    expect(find.text('Chronic Disease Early Prediction'), findsOneWidget);
    expect(find.text(PredictionService.disclaimer), findsOneWidget);
  });

  testWidgets('Privacy & Security says what is and is not saved', (tester) async {
    await openProfile(tester);
    await scrollAndTap(tester, find.byKey(const Key('menuPrivacy')));

    expect(find.text('What is saved'), findsOneWidget);
    expect(find.text('What is not saved'), findsOneWidget);
    expect(find.textContaining('Quick predictions'), findsOneWidget);
  });
}
