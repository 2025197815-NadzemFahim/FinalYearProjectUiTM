// =============================================================================
// SETTINGS (Profile -> Settings) - no mockup in Section 3.5.4
//
//   <-
//   Settings
//   Your account and information about this app.
//   | Account                                  |
//   | (person) Name             Nadzem Fahim   |
//   | (mail)   Email            you@...        |
//   | (key)    Change password              >  |
//   | (card)   Edit my details              >  |
//   | Help                                     |
//   | (book)   Health guides                >  |
//   | (lock)   Privacy & Security           >  |
//   | (i)      About this app               >  |
//
// Name and email are set at Create Account and only shown here.
// "Change password" emails a link (navigation/password_change.dart).
// =============================================================================
import 'package:flutter/material.dart';

import '../navigation/password_change.dart';
import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../services/prediction_service.dart';
import '../theme/app_theme.dart';
import '../widgets/info_page.dart';
import 'guides_screen.dart';
import 'my_details_screen.dart';
import 'privacy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.services, required this.user});

  final AppServices services;
  final AppUser user;

  /// Keep this the same as "version:" in pubspec.yaml (the part before the +).
  static const appVersion = '0.1.0';

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  /// Flutter's ready-made About box: name, version, and a "View licenses"
  /// button listing the open-source packages the app uses.
  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Chronic Disease Early Prediction',
      applicationVersion: 'Version $appVersion',
      applicationIcon: const Icon(Icons.health_and_safety, size: 40, color: AppColors.green),
      children: [
        Text(
          'Estimates your risk of heart disease, diabetes and stroke from your '
          'answers and readings.',
          style: AppFonts.body(size: 14),
        ),
        const SizedBox(height: 12),
        Text(PredictionService.disclaimer, style: AppFonts.body(size: 13, color: AppColors.hint)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (user.displayName?.isNotEmpty ?? false) ? user.displayName! : '-';

    return InfoPage(
      title: 'Settings',
      subtitle: 'Your account and information about this app.',
      children: [
        InfoCard(
          title: 'Account',
          children: [
            InfoRow(icon: Icons.person, label: 'Name', note: name),
            InfoRow(icon: Icons.mail, label: 'Email', note: user.email ?? '-'),
            InfoRow(
              key: const Key('settingsPassword'),
              icon: Icons.key,
              label: 'Change password',
              note: 'We email you a link to set a new one.',
              onTap: () => sendPasswordChangeLink(context, services, user.email),
            ),
            InfoRow(
              key: const Key('settingsDetails'),
              icon: Icons.badge,
              label: 'Edit my details',
              onTap: () => _open(context, MyDetailsScreen(services: services)),
            ),
          ],
        ),
        InfoCard(
          title: 'Help',
          children: [
            InfoRow(
              key: const Key('settingsGuides'),
              icon: Icons.menu_book,
              label: 'Health guides',
              onTap: () => _open(context, GuidesScreen(services: services)),
            ),
            InfoRow(
              key: const Key('settingsPrivacy'),
              icon: Icons.shield,
              label: 'Privacy & Security',
              onTap: () => _open(context, PrivacyScreen(services: services, user: user)),
            ),
            InfoRow(
              key: const Key('settingsAbout'),
              icon: Icons.info_outline,
              label: 'About this app',
              note: 'Version $appVersion',
              onTap: () => _showAbout(context),
            ),
          ],
        ),
      ],
    );
  }
}
