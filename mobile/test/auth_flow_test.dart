// Widget tests for every screen flow. Run:  flutter test
//
// They use FakeAuthService instead of Firebase, so they need no emulator and
// no internet. This is why the screens take an AuthService instead of
// calling FirebaseAuth directly. Google Fonts are switched off for the same reason.
import 'dart:async';

import 'package:chronic_disease_app/app.dart';
import 'package:chronic_disease_app/models/user_details.dart';
import 'package:chronic_disease_app/navigation/app_tabs.dart';
import 'package:chronic_disease_app/services/auth_service.dart';
import 'package:chronic_disease_app/services/profile_service.dart';
import 'package:chronic_disease_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'api_payloads_test.dart' show sampleDetails;

/// Pretends to be Firebase: one valid account, and a stream like authStateChanges().
class FakeAuthService implements AuthService {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;
  int signInCalls = 0;
  int signOutCalls = 0;
  int registerCalls = 0;
  final resetEmails = <String>[];

  static const validEmail = 'ali@demo.com';
  static const validPassword = 'password123';

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _user;                 // current state first, like Firebase does
    yield* _controller.stream;   // then every change
  }

  @override
  AppUser? get currentUser => _user;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    if (email.trim() != validEmail || password != validPassword) {
      throw const AuthFailure('Incorrect email or password.');
    }
    _user = const AppUser(uid: 'u1', email: validEmail, displayName: 'Ali Ahmad');
    _controller.add(_user);
  }

  @override
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    registerCalls++;
    if (email.trim() == validEmail) {
      throw const AuthFailure('An account already exists for that email.');
    }
    // Like the real service: the user is NOT left signed in.
  }

  @override
  Future<void> sendPasswordReset(String email) async => resetEmails.add(email.trim());

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _user = null;
    _controller.add(null);
  }

  @override
  Future<String?> idToken() async => _user == null ? null : 'fake-token';
}

/// [details]: the user's saved details at the start (null = a brand-new user who
/// still has to complete them).
Future<FakeAuthService> pumpApp(WidgetTester tester, {UserDetails? details}) async {
  // 600 x 1000 logical pixels. Wider than a phone because the test font draws
  // every letter as a full square (much wider than Poppins).
  tester.view.physicalSize = const Size(1800, 3000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final auth = FakeAuthService();
  await tester.pumpWidget(App(auth: auth, profile: ProfileService(initial: details)));
  await tester.pumpAndSettle();
  return auth;
}

Future<void> typeAndLogin(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.byKey(const Key('email')), email);
  await tester.enterText(find.byKey(const Key('password')), password);
  await tester.tap(find.byKey(const Key('login')));
  await tester.pumpAndSettle();
}

/// Scrolls the current page down until the widget with [key] has been built and is on screen.
Future<void> scrollTo(WidgetTester tester, String key) =>
    tester.scrollUntilVisible(find.byKey(Key(key)), 150, scrollable: find.byType(Scrollable).first);

/// Picks [answer] inside the question with [key] (a ChoiceQuestionField).
Future<void> answer(WidgetTester tester, String key, String answer) async {
  await scrollTo(tester, key);
  await tester.tap(find.descendant(of: find.byKey(Key(key)), matching: find.text(answer)));
  await tester.pumpAndSettle();
}

/// Types [text] into the number box with [key].
Future<void> typeNumber(WidgetTester tester, String key, String text) async {
  await scrollTo(tester, key);
  await tester.enterText(
      find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText)), text);
  await tester.pumpAndSettle();
}

/// Scrolls until [finder] is on screen, then taps it. Long pages build their
/// bottom items lazily, so first scroll down until the widget exists at all.
Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 150, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppFonts.useGoogleFonts = false);

  // ------------------------------------------------------------- Login
  testWidgets('signed out -> Login screen is shown', (tester) async {
    await pumpApp(tester);
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('LOG IN'), findsOneWidget);
  });

  testWidgets('empty form shows validation errors and does not call Firebase', (tester) async {
    final auth = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('login')));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your email.'), findsOneWidget);
    expect(find.text('Please enter your password.'), findsOneWidget);
    expect(auth.signInCalls, 0);
  });

  testWidgets('badly formatted email is rejected before sign-in', (tester) async {
    final auth = await pumpApp(tester);
    await typeAndLogin(tester, 'not-an-email', 'whatever');
    expect(find.text('Please enter a valid email.'), findsOneWidget);
    expect(auth.signInCalls, 0);
  });

  testWidgets('wrong password -> error popup, stays on Login', (tester) async {
    final auth = await pumpApp(tester);
    await typeAndLogin(tester, FakeAuthService.validEmail, 'wrong');
    expect(auth.signInCalls, 1);
    expect(find.text('Login failed'), findsOneWidget);
    expect(find.text('Incorrect email or password.'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('password visibility toggle', (tester) async {
    await pumpApp(tester);
    TextField pw() => tester.widget<TextField>(
        find.descendant(of: find.byKey(const Key('password')), matching: find.byType(TextField)));
    expect(pw().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(pw().obscureText, isFalse);
  });

  // ---------------------------------------------------- Create account
  testWidgets('create account -> back to Login with a message', (tester) async {
    final auth = await pumpApp(tester);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsOneWidget);

    // Submitting empty shows errors and does not register.
    await scrollAndTap(tester, find.byKey(const Key('createAccount')));
    expect(find.text('Enter your first name.'), findsOneWidget);
    expect(auth.registerCalls, 0);

    await tester.enterText(find.byKey(const Key('firstName')), 'Siti');
    await tester.enterText(find.byKey(const Key('lastName')), 'Aminah');
    await tester.enterText(find.byKey(const Key('regEmail')), 'siti@demo.com');
    await tester.enterText(find.byKey(const Key('regPassword')), 'secret1');
    await tester.enterText(find.byKey(const Key('contact')), '0123456789');
    await tester.enterText(find.byKey(const Key('age')), '30');
    await tester.tap(find.text('Female'));
    await scrollAndTap(tester, find.byKey(const Key('createAccount')));

    expect(auth.registerCalls, 1);
    expect(find.text('Hello'), findsOneWidget); // back on Login
    expect(find.text('Account created. Please log in.'), findsOneWidget);
  });

  // --------------------------------------------------- Forgot password
  testWidgets('forgot password sends the reset email', (tester) async {
    final auth = await pumpApp(tester);
    await tester.tap(find.text('Forgot your password?'));
    await tester.pumpAndSettle();
    expect(find.text('Forgot Password?'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('resetEmail')), 'siti@demo.com');
    await tester.tap(find.byKey(const Key('resetPassword')));
    await tester.pumpAndSettle();
    expect(auth.resetEmails, ['siti@demo.com']);
    expect(find.text('Reset instructions sent to siti@demo.com.'), findsOneWidget);
  });

  // ---------------------------------------------------- Main + Logout
  testWidgets('login -> Main; Profile tab; logout (confirmed) -> Login', (tester) async {
    final auth = await pumpApp(tester);
    await typeAndLogin(tester, '  ${FakeAuthService.validEmail}  ', FakeAuthService.validPassword);

    // AuthGate switched to the Home tab on its own
    expect(find.text('Welcome back,\nAli!'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(AppTabs.current.value, AppTabs.profile);
    expect(find.text('Ali Ahmad'), findsOneWidget);
    expect(find.text(FakeAuthService.validEmail), findsOneWidget);

    // Cancel keeps you signed in
    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 0);
    expect(find.text('Ali Ahmad'), findsOneWidget);

    // Confirm signs out and returns to Login
    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-logout')));
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 1);
    expect(find.text('Hello'), findsOneWidget);
  });

  // ------------------------------------- Quick -> Deep -> History flow
  testWidgets('quick prediction -> deep check -> result saved in History', (tester) async {
    await pumpApp(tester, details: sampleDetails());
    await typeAndLogin(tester, FakeAuthService.validEmail, FakeAuthService.validPassword);

    // Details complete -> straight to Quick Prediction, which only asks what changes
    expect(find.byKey(const Key('detailsBanner')), findsNothing);
    await tester.tap(find.byKey(const Key('predictCard')));
    await tester.pumpAndSettle();
    expect(find.text('Using your saved details'), findsOneWidget);
    expect(find.text('41.5'), findsOneWidget); // BMI: last weight 120 kg + saved height 170 cm
    expect(find.text('Age'), findsNothing);    // age, sex, height... come from the profile

    // Check -> Quick Result, highest risk first and opened
    await scrollAndTap(tester, find.byKey(const Key('quickCheck')));
    expect(find.text('Heart Disease'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.textContaining('moderate risk of heart disease'), findsOneWidget);

    // Deep Check -> heart asks about the stress test first -> full form
    await tester.tap(find.byKey(const Key('deepCheck-heart')));
    await tester.pumpAndSettle();
    expect(find.text('Have you done an exercise stress test recently?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('stressYes')));
    await tester.pumpAndSettle();
    expect(find.text('Max Heart Rate'), findsOneWidget);
    await scrollTo(tester, 'deepCheckSubmit');
    expect(find.text('Chest Pain Type'), findsOneWidget);
    expect(find.text('Resting ECG Result'), findsOneWidget);
    expect(find.text('Major Vessel Number'), findsNothing); // not a model input

    // Submit -> Deep-Check Result
    await scrollAndTap(tester, find.byKey(const Key('deepCheckSubmit')));
    expect(find.byKey(const Key('deepPercent')), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.textContaining('not a diagnosis'), findsOneWidget);

    // History tab now lists the new result at the top, under "Today"
    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();
    expect(AppTabs.current.value, AppTabs.history);
    expect(find.text('Diagnosis 8'), findsOneWidget);

    // Opening it shows the saved result again
    await tester.tap(find.byKey(const Key('history-Diagnosis 8')));
    await tester.pumpAndSettle();
    expect(find.text('80%'), findsOneWidget);
  });

  testWidgets('Main "View Prediction History" card switches to the History tab', (tester) async {
    await pumpApp(tester, details: sampleDetails());
    await typeAndLogin(tester, FakeAuthService.validEmail, FakeAuthService.validPassword);
    await tester.tap(find.byKey(const Key('historyCard')));
    await tester.pumpAndSettle();
    expect(AppTabs.current.value, AppTabs.history);
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('closed result card opens; Diabetes deep check uses its own form', (tester) async {
    await pumpApp(tester, details: sampleDetails());
    await typeAndLogin(tester, FakeAuthService.validEmail, FakeAuthService.validPassword);
    await tester.tap(find.byKey(const Key('predictCard')));
    await tester.pumpAndSettle();
    await scrollAndTap(tester, find.byKey(const Key('quickCheck')));

    // Diabetes starts closed: no Deep Check button for it yet.
    expect(find.byKey(const Key('deepCheck-diabetes')), findsNothing);
    await tester.tap(find.text('Diabetes Mellitus'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('deepCheck-diabetes')), findsOneWidget);

    await tester.tap(find.byKey(const Key('deepCheck-diabetes')));
    await tester.pumpAndSettle();
    // Only the per-check readings: no stress-test question, no smoking (from Lifestyle)
    expect(find.text('HbA1c Level'), findsOneWidget);
    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('Smoking History'), findsNothing);
    expect(find.text('Chest Pain Type'), findsNothing); // heart-only question
    expect(find.byKey(const Key('stressYes')), findsNothing);
  });

  testWidgets('heart without a stress test uses the reduced form', (tester) async {
    await pumpApp(tester, details: sampleDetails());
    await typeAndLogin(tester, FakeAuthService.validEmail, FakeAuthService.validPassword);
    await tester.tap(find.byKey(const Key('predictCard')));
    await tester.pumpAndSettle();
    await scrollAndTap(tester, find.byKey(const Key('quickCheck')));
    await tester.tap(find.byKey(const Key('deepCheck-heart')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('stressNo')));
    await tester.pumpAndSettle();
    expect(find.textContaining('without a stress test'), findsOneWidget);
    expect(find.text('Resting BP'), findsOneWidget);
    expect(find.text('Max Heart Rate'), findsNothing); // the 3 hospital-only readings
    expect(find.text('ST Depression'), findsNothing);
    await scrollAndTap(tester, find.byKey(const Key('deepCheckSubmit')));
    expect(find.byKey(const Key('deepPercent')), findsOneWidget);
  });

  testWidgets('new user: details asked once (My details -> History -> Lifestyle), then the check',
      (tester) async {
    await pumpApp(tester); // no saved details
    await typeAndLogin(tester, FakeAuthService.validEmail, FakeAuthService.validPassword);
    expect(find.byKey(const Key('detailsBanner')), findsOneWidget);

    await tester.tap(find.byKey(const Key('predictCard')));
    await tester.pumpAndSettle();
    expect(find.text('Complete your details'), findsOneWidget);
    await tester.tap(find.byKey(const Key('startDetails')));
    await tester.pumpAndSettle();

    // ---- My details (1-9). Saving with nothing filled shows the errors first.
    expect(find.text('My details'), findsOneWidget);
    await scrollAndTap(tester, find.byKey(const Key('saveMyDetails')));
    expect(find.textContaining('Some answers are missing'), findsOneWidget);
    // Back to the very top (the date of birth is the first question)
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(find.text('Please choose your date of birth'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dobButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // the date picker's default date is fine
    await tester.pumpAndSettle();
    await answer(tester, 'sex', 'Male');
    await typeNumber(tester, 'height', '170');
    await typeNumber(tester, 'income', '6500');
    await answer(tester, 'education', 'SPM (completed Form 5)');
    await answer(tester, 'coverage', 'Yes');
    await answer(tester, 'married', 'Yes');
    await answer(tester, 'work', 'Private sector employee');
    await answer(tester, 'residence', 'Urban (town or city)');
    await scrollAndTap(tester, find.byKey(const Key('saveMyDetails')));

    // ---- Medical history (10-14)
    expect(find.text('Medical history'), findsOneWidget);
    for (final key in ['highBp', 'highChol', 'cholChecked', 'heartDisease', 'walking']) {
      await answer(tester, key, 'No');
    }
    await scrollAndTap(tester, find.byKey(const Key('saveHistory')));

    // ---- Lifestyle check (15-19): levels shown after saving
    expect(find.text('Lifestyle check'), findsOneWidget);
    await answer(tester, 'smoked100', 'No');
    await answer(tester, 'smokesNow', 'No');
    await answer(tester, 'activity', '1-2 times a week');
    await answer(tester, 'fruit', 'Once a day');
    await answer(tester, 'vegetables', 'A few times a week');
    await answer(tester, 'drinks', 'No');
    await scrollAndTap(tester, find.byKey(const Key('saveLifestyle')));
    expect(find.text('Your lifestyle'), findsOneWidget);
    expect(find.text('Semi-active'), findsOneWidget);
    expect(find.text('Never smoked'), findsOneWidget);
    await tester.tap(find.byKey(const Key('lifestyleDone')));
    await tester.pumpAndSettle();

    // ---- Then the Quick Prediction opens, already using the saved details
    expect(find.text('Using your saved details'), findsOneWidget);
    await typeNumber(tester, 'weight', '70');
    await scrollAndTap(tester, find.byKey(const Key('quickCheck')));
    expect(find.text('50%'), findsOneWidget);

    // Back on Main, the banner is gone (details complete, lifestyle just taken)
    AppTabs.goTo(tester.element(find.byType(Scaffold).last), AppTabs.home);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detailsBanner')), findsNothing);
  });
}
