// =============================================================================
// 10. PROFILE INTERFACE (Figure 3.24) - the Profile tab
//
//            ( photo ring + camera badge )
//                   Nadzem Fahim
//              nadzemfahim@gmail.com
//                  [ Edit Profile ]
//   | My Activity        > |
//   | Settings           > |
//   | Privacy & Security > |
//
//   | Log out            > |
//
// Logout is real (use case Table 3.17). The other buttons have no mockup of
// their own yet, so they show a "not designed yet" message (showComingSoon).
// =============================================================================
import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/coming_soon.dart';
import '../widgets/menu_card.dart';
import '../widgets/phone_width.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.services, required this.user});

  final AppServices services;
  final AppUser user;

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
            Center(child: _ProfilePhoto(onCameraTap: () => showComingSoon(context, 'Profile photo'))),
            const SizedBox(height: 14),
            Text(name, textAlign: TextAlign.center, style: AppFonts.body(size: 22, weight: FontWeight.w500)),
            Text(user.email ?? '', textAlign: TextAlign.center, style: AppFonts.body(size: 13)),
            const SizedBox(height: 24),
            Center(
              child: _GreyPillButton(
                label: 'Edit Profile',
                onTap: () => showComingSoon(context, 'Edit Profile'),
              ),
            ),
            const SizedBox(height: 28),
            MenuCard(items: [
              MenuItem(
                icon: Icons.access_time_filled,
                label: 'My Activity',
                onTap: () => showComingSoon(context, 'My Activity'),
              ),
              MenuItem(
                icon: Icons.settings,
                label: 'Settings',
                onTap: () => showComingSoon(context, 'Settings'),
              ),
              MenuItem(
                icon: Icons.shield,
                label: 'Privacy & Security',
                onTap: () => showComingSoon(context, 'Privacy & Security'),
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

/// The dark-green ring with the small camera badge at the bottom-right.
class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto({required this.onCameraTap});
  final VoidCallback onCameraTap;

  static const double size = 165;

  @override
  Widget build(BuildContext context) {
    // Stack draws children on top of each other; Positioned places the badge.
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: AppColors.darkGreen, width: 6), // ring colour/thickness
              // When photos are added:
              //   image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
            ),
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: Material(
              color: AppColors.darkGreen,
              shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 2)),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onCameraTap,
                child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(Icons.photo_camera, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
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
