// =============================================================================
// 4. MAIN INTERFACE (Figure 3.18) - the Home tab
//
//   [ green header: "Welcome back, <name>!" ]
//   [ Predict a Disease card ] [ View Prediction History card ]
//   [ <- swipeable health banners with dots -> ]
//   [ <- horizontally scrolling info cards -> ]
//
// Banner content is SAMPLE data: the mockup uses third-party poster images,
// so each banner is rebuilt from colours, an icon and the mockup's text.
// To use a real image instead, see _Banner below.
// =============================================================================
import 'package:flutter/material.dart';

import '../navigation/app_tabs.dart';
import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/coming_soon.dart';
import 'quick_prediction_input_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key, required this.services, required this.user});

  final AppServices services;
  final AppUser user;

  /// "Ali Ahmad" -> "Ali". Falls back to "there" if no name is set.
  String get _firstName {
    final name = user.displayName?.trim() ?? '';
    return name.isEmpty ? 'there' : name.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    // ListView = a Column that scrolls. Children are laid out top to bottom.
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Header(text: 'Welcome back,\n$_firstName!'),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _ActionCard(
                  key: const Key('predictCard'),
                  background: AppColors.lavenderCard,
                  icon: Icons.edit_calendar,
                  iconColor: const Color(0xFF5B6CF0),
                  title: 'Predict a Disease with AI Model',
                  subtitle: 'Predicting a disease of Heart Disease, Diabetes or Stroke',
                  // Opens the Quick Prediction form on top of the Home tab.
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => QuickPredictionInputScreen(services: services))),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ActionCard(
                  key: const Key('historyCard'),
                  background: AppColors.mintCard,
                  icon: Icons.document_scanner_outlined,
                  iconColor: AppColors.green,
                  title: 'View Prediction History',
                  subtitle: 'Viewing previous disease prediction.',
                  onTap: () => AppTabs.goTo(context, AppTabs.history), // switch tab
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _BannerCarousel(),
        const SizedBox(height: 24),
        const _InfoCardRow(),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// The green top section with the very rounded bottom corners.
class _Header extends StatelessWidget {
  const _Header({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // MediaQuery.paddingOf(context).top = height of the phone's status bar,
      // so the green colour fills behind it like in the mockup.
      padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + 64, 24, 64),
      decoration: const BoxDecoration(
        color: AppColors.green,
        // Only the BOTTOM corners are rounded.
        borderRadius: BorderRadius.vertical(bottom: Radius.elliptical(220, 70)),
      ),
      child: Text(text,
          textAlign: TextAlign.center,
          style: AppFonts.body(size: 30, color: Colors.white, weight: FontWeight.w500)),
    );
  }
}

/// "Predict a Disease" / "View Prediction History" cards.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    super.key,
    required this.background,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color background;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Material + InkWell = a coloured, rounded area with a tap ripple.
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Small rounded square behind the icon.
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: iconColor.withValues(alpha: 0.35)),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 12),
              Text(title, style: AppFonts.body(size: 15, weight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle, style: AppFonts.body(size: 12, color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- banners

/// Sample banner data. Add, remove or reorder entries to change the carousel.
const _banners = [
  (
    'February is',
    'NATIONAL HEART MONTH',
    'Take care of your heart: eat healthy, stay active, get regular checkups!',
    [Color(0xFFFF8A65), Color(0xFFE53935)],
    Icons.favorite,
  ),
  (
    'November 14',
    'WORLD DIABETES DAY',
    'Know your blood sugar. Early checks prevent complications.',
    [Color(0xFF64B5F6), Color(0xFF1E5BD8)],
    Icons.bloodtype,
  ),
  (
    'October 29',
    'WORLD STROKE DAY',
    'Act F.A.S.T. - Face, Arms, Speech, Time to call for help.',
    [Color(0xFFBA68C8), Color(0xFF6A1B9A)],
    Icons.psychology,
  ),
];

/// Swipeable banners + page dots. StatefulWidget: it remembers which page is showing.
class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel();

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  // viewportFraction 0.85: each page is 85% wide, so the neighbours peek in
  // at the edges like in the mockup.
  final _controller = PageController(viewportFraction: 0.85);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: PageView.builder(
        controller: _controller,
        itemCount: _banners.length,
        onPageChanged: (i) => setState(() => _page = i),
        // itemBuilder makes one page at a time, by index.
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _Banner(index: i, currentPage: _page),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.index, required this.currentPage});
  final int index;
  final int currentPage;

  @override
  Widget build(BuildContext context) {
    final (small, big, caption, colors, icon) = _banners[index];
    return GestureDetector(
      onTap: () => showComingSoon(context, 'Health articles'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          // A gradient blends between colours. To use a picture instead:
          //   image: DecorationImage(image: AssetImage('assets/heart.png'), fit: BoxFit.cover),
          gradient: LinearGradient(colors: colors),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(small, style: AppFonts.body(size: 13, color: Colors.white)),
                  Text(big,
                      textAlign: TextAlign.right,
                      style: AppFonts.body(size: 22, weight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(caption,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.body(size: 11, color: Colors.white)),
                  const Spacer(),
                  // The page dots: the current one is pink, the rest grey.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (var d = 0; d < _banners.length; d++)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: d == currentPage ? const Color(0xFFE91E8C) : Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- info cards

/// The blue/red "Prevent the spread..." cards that scroll sideways.
class _InfoCardRow extends StatelessWidget {
  const _InfoCardRow();

  static const _cards = [
    ('Prevent the spread\nof COVID-19 Virus', Color(0xFF2F5BE0)),
    ('Know your numbers:\ncheck your blood pressure', Color(0xFFEF4B3F)),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 105,
      child: ListView.separated(
        scrollDirection: Axis.horizontal, // scroll left-right instead of up-down
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          final (title, color) = _cards[i];
          return GestureDetector(
            onTap: () => showComingSoon(context, 'Health articles'),
            child: Container(
              width: 315,
              // clipBehavior cuts off the part of the circle that sticks out
              // past the rounded corners.
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              // Stack lets the decorative circle sit behind the text.
              child: Stack(
                children: [
                  Positioned(
                    right: -50,
                    top: -40,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Expanded: the title takes the space left above the link
                        // and is cut off with "..." if it ever doesn't fit.
                        Expanded(
                          child: Text(title,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              style: AppFonts.body(size: 15, weight: FontWeight.w600, color: Colors.white)),
                        ),
                        Text('Find out now →', style: AppFonts.body(size: 13, color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
