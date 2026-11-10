// =============================================================================
// 10. PROFILE INTERFACE (Figure 3.24) - the Profile tab
//
//               ( NF )                 <- photo ring with the name's initials
//            Nadzem Fahim
//        nadzemfahim@gmail.com
//           [ Edit Profile ]
//   | My details          > |
//   | Medical history     > |
//   | Lifestyle check     > |
//
//   | My Activity         > |
//   | Health guides       > |
//   | Settings            > |
//   | Privacy & Security  > |
//
//   | Log out             > |
//
// Logout is real (use case Table 3.17). Edit Profile and the first card open
// My details, Medical history and the Lifestyle check (task U4). My Activity,
// Settings and Privacy & Security had no mockup; their screens follow the same
// look (widgets/info_page.dart).
// =============================================================================
import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/menu_card.dart';
import '../widgets/phone_width.dart';
import 'guides_screen.dart';
import 'lifestyle_check_screen.dart';
import 'medical_history_screen.dart';
import 'my_activity_screen.dart';
import 'my_details_screen.dart';
import 'privacy_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.services, required this.user});

  final AppServices services;
  final AppUser user;

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  Future<void> _confirmLogout(BuildContext context) async {
    // Ask first: logging out by accident is annoying.
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to see your history.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('confirm-logout'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await services.auth.signOut();
      // No navigation code here: AuthGate sees "signed out" and shows Login.
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (user.displayName?.isNotEmpty ?? false) ? user.displayName! : 'User';
    return SafeArea(
      child: PhoneWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          children: [
            Center(child: _ProfilePhoto(name: name)),
            const SizedBox(height: 14),
            Text(name, textAlign: TextAlign.center, style: AppFonts.body(size: 22, weight: FontWeight.w500)),
            Text(user.email ?? '', textAlign: TextAlign.center, style: AppFonts.body(size: 13)),
            const SizedBox(height: 24),
            Center(
              child: _GreyPillButton(
                label: 'Edit Profile',
                onTap: () => _open(context, MyDetailsScreen(services: services)),
              ),
            ),
            const SizedBox(height: 28),
            // The details every check re-uses (asked once, editable here).
            MenuCard(items: [
              MenuItem(
                key: const Key('menuMyDetails'),
                icon: Icons.badge,
                label: 'My details',
                onTap: () => _open(context, MyDetailsScreen(services: services)),
              ),
              MenuItem(
                key: const Key('menuHistory'),
                icon: Icons.medical_services,
                label: 'Medical history',
                onTap: () => _open(context, MedicalHistoryScreen(services: services)),
              ),
              MenuItem(
                key: const Key('menuLifestyle'),
                icon: Icons.directions_run,
                label: 'Lifestyle check',
                onTap: () => _open(context, LifestyleCheckScreen(services: services)),
              ),
            ]),
            const SizedBox(height: 24),
            MenuCard(items: [
              MenuItem(
                key: const Key('menuActivity'),
                icon: Icons.access_time_filled,
                label: 'My Activity',
                onTap: () => _open(context, MyActivityScreen(services: services)),
              ),
              MenuItem(
                key: const Key('menuGuides'),
                icon: Icons.menu_book,
                label: 'Health guides',
                onTap: () => _open(context, GuidesScreen(services: services)),
              ),
              MenuItem(
                key: const Key('menuSettings'),
                icon: Icons.settings,
                label: 'Settings',
                onTap: () => _open(context, SettingsScreen(services: services, user: user)),
              ),
              MenuItem(
                key: const Key('menuPrivacy'),
                icon: Icons.shield,
                label: 'Privacy & Security',
                onTap: () => _open(context, PrivacyScreen(services: services, user: user)),
              ),
            ]),
            const SizedBox(height: 24),
            // A separate card, so Log out stands apart like in the mockup.
            MenuCard(items: [
              MenuItem(
                key: const Key('logout'),
                icon: Icons.logout,
                label: 'Log out',
                onTap: () => _confirmLogout(context),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// The dark-green ring with the person's initials inside ("Nadzem Fahim" -> "NF").
///
/// A real photo needs two more things: a package to pick a picture
/// (image_picker) and somewhere to keep it (Firebase Storage). Then show it with
///   decoration: BoxDecoration(image: DecorationImage(image: NetworkImage(url), ...))
class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto({required this.name});

  final String name;

  static const double size = 165;

  /// The first letter of the first two words, in capitals. "User" -> "U".
  static String initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('profileInitials'),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.mintCard,
        border: Border.all(color: AppColors.darkGreen, width: 6), // ring colour/thickness
      ),
      child: Text(
        initials(name),
        style: AppFonts.serif(size: 56, color: AppColors.darkGreen),
      ),
    );
  }
}

/// The small grey rounded "Edit Profile" button.
class _GreyPillButton extends StatelessWidget {
  const _GreyPillButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.tileIconBg,
      borderRadius: BorderRadius.circular(20),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          child: Text(label, style: AppFonts.body(size: 13)),
        ),
      ),
    );
  }
}
