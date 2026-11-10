// =============================================================================
// PRIVACY & SECURITY (Profile -> Privacy & Security) - no mockup in Section 3.5.4
//
//   <-
//   Privacy & Security
//   What the app keeps, and who can see it.
//   | What is saved           |   bullet points
//   | What is not saved       |
//   | Who can see it          |
//   | Keep your account safe  |   + Change password
//   | Deleting your data      |
//
// Plain information. If what the app stores changes (firestore_maps.dart,
// backend/app/db.py), update the bullet points here too.
// =============================================================================
import 'package:flutter/material.dart';

import '../navigation/password_change.dart';
import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../widgets/info_page.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key, required this.services, required this.user});

  final AppServices services;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return InfoPage(
      title: 'Privacy & Security',
      subtitle: 'What the app keeps, and who can see it.',
      children: [
        const InfoCard(
          title: 'What is saved',
          children: [
            Bullet('Your account: name, email, date of birth, sex and phone number.'),
            Bullet('My details: height, education, household income, health coverage, '
                'marriage, work and where you live.'),
            Bullet('Your medical history and Lifestyle check answers.'),
            Bullet('Your last weight, so you do not have to type it again.'),
            Bullet('Each deep check: the readings you entered and the result. '
                'These are what you see in History.'),
          ],
        ),
        const InfoCard(
          title: 'What is not saved',
          children: [
            Bullet('Quick predictions: the answers and results are gone when you leave '
                'the result screen.'),
            Bullet('Your password: Firebase Authentication checks it. '
                'The app never stores it.'),
          ],
        ),
        const InfoCard(
          title: 'Who can see it',
          children: [
            Bullet('You, while signed in. The database rules block every other account.'),
            Bullet('The people who run the app\'s server and database, to keep it working.'),
            Bullet('Deep-check results are saved by the server, so they cannot be changed '
                'from a phone.'),
            Bullet('Your answers are only used to estimate your risk. Income is only used '
                'as a general social factor.'),
          ],
        ),
        InfoCard(
          title: 'Keep your account safe',
          children: [
            const Bullet('Log out when you use a shared phone (Profile, then Log out).'),
            const Bullet('Use a password you do not use anywhere else.'),
            InfoRow(
              key: const Key('privacyPassword'),
              icon: Icons.key,
              label: 'Change password',
              onTap: () => sendPasswordChangeLink(context, services, user.email),
            ),
          ],
        ),
        const InfoCard(
          title: 'Deleting your data',
          children: [
            Bullet('Deleting your account from inside the app is not available in this '
                'version. Until it is, ask the app\'s administrator to remove your '
                'account and data.'),
          ],
        ),
      ],
    );
  }
}
