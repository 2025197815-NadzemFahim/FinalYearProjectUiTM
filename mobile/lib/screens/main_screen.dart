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
// To use a real image instead, see _Banner below. Tapping a banner or an info
// card opens the matching Health guide (navigation/guides.dart).
// =============================================================================
import 'package:flutter/material.dart';

import '../models/user_details.dart';
import '../navigation/app_tabs.dart';
import '../navigation/details_flow.dart';
import '../navigation/guides.dart';
import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'lifestyle_check_screen.dart';
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
        _DetailsBanner(services: services),
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
                  // Completes any missing details first (asked once), then opens
                  // the Quick Prediction form on top of the Home tab.
                  onTap: () async {
                    if (!await ensureDetailsComplete(context, services) || !context.mounted) return;
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => QuickPredictionInputScreen(services: services)));
                  },
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
        _BannerCarousel(services: services),
        const SizedBox(height: 24),
        _InfoCardRow(services: services),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Below the header, at most one of these (checked in this order):
///   - the saved details could not be loaded  -> "Try again"
///   - they are still loading                 -> a small spinner
///   - they are not complete yet              -> "Complete your details"
///   - the lifestyle answers are 90+ days old -> "Time to retake..."
/// Nothing otherwise.
class _DetailsBanner extends StatelessWidget {
  const _DetailsBanner({required this.services});
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final profile = services.profile;

    // ListenableBuilder + Listenable.merge: redraw when ANY of the three changes.
    return ListenableBuilder(
      listenable: Listenable.merge([profile.details, profile.loading, profile.loadError]),
      builder: (context, _) {
        final UserDetails d = profile.details.value;

        if (profile.loadError.value != null) {
          return _BannerRow(
            key: const Key('loadErrorBanner'),
            color: const Color(0xFFFDECEA), // light red
            icon: const Icon(Icons.cloud_off, color: AppColors.riskHigh),
            text: 'Your saved details could not be loaded. Tap to try again.',
            onTap: profile.reload,
          );
        }
        if (profile.loading.value) {
          return const _BannerRow(
            color: AppColors.mintCard,
            icon: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            text: 'Loading your saved details...',
          );
        }
        if (!d.isComplete) {
          return _BannerRow(
            key: const Key('detailsBanner'),
            color: AppColors.mintCard,
            icon: const Icon(Icons.assignment_ind_outlined, color: AppColors.green),
            text: 'Complete your details (2 min) so each check asks less.',
            onTap: () => ensureDetailsComplete(context, services),
          );
        }
        if (d.lifestyle.needsRetake(DateTime.now())) {
          return _BannerRow(
            key: const Key('detailsBanner'),
            color: AppColors.mintCard,
            icon: const Icon(Icons.assignment_ind_outlined, color: AppColors.green),
            text: 'Time to retake your lifestyle check.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => LifestyleCheckScreen(services: services))),
          );
        }
        return const SizedBox.shrink(); // = draw nothing
      },
    );
  }
}

/// One rounded banner: icon, text, and a chevron when it can be tapped.
class _BannerRow extends StatelessWidget {
  const _BannerRow({
    super.key,
    required this.color,
    required this.icon,
    required this.text,
    this.onTap,
  });

  final Color color;
  final Widget icon;
  final String text;
  final VoidCallback? onTap; // null = not tappable (e.g. while loading)

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                icon,
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: AppFonts.body(size: 14))),
                if (onTap != null) const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
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
  _BannerData(
    small: 'February is',
    big: 'NATIONAL HEART MONTH',
    caption: 'Take care of your heart: eat healthy, stay active, get regular checkups!',
    colors: [Color(0xFFFF8A65), Color(0xFFE53935)],
    icon: Icons.favorite,
    guide: Guides.healthyHabits,
  ),
  _BannerData(
    small: 'November 14',
    big: 'WORLD DIABETES DAY',
    caption: 'Know your blood sugar. Early checks prevent complications.',
    colors: [Color(0xFF64B5F6), Color(0xFF1E5BD8)],
    icon: Icons.bloodtype,
    guide: Guides.bloodSugar,
  ),
  _BannerData(
    small: 'October 29',
    big: 'WORLD STROKE DAY',
    caption: 'Act F.A.S.T. - Face, Arms, Speech, Time to call for help.',
    colors: [Color(0xFFBA68C8), Color(0xFF6A1B9A)],
    icon: Icons.psychology,
    guide: Guides.strokeFast,
  ),
];

/// What one banner shows, and which Health guide opens when it is tapped.
class _BannerData {
  const _BannerData({
    required this.small,
    required this.big,
    required this.caption,
    required this.colors,
    required this.icon,
    required this.guide,
  });

  final String small;        // "February is"
  final String big;          // "NATIONAL HEART MONTH"
  final String caption;      // the line under the title
  final List<Color> colors;  // gradient, left to right
  final IconData icon;
  final String guide;        // a guide id from Guides
}

/// Swipeable banners + page dots. StatefulWidget: it remembers which page is showing.
class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.services});
  final AppServices services;

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
          child: _Banner(
            key: Key('banner-${_banners[i].guide}'),
            data: _banners[i],
            currentPage: _page,
            onTap: () => openGuide(context, widget.services, _banners[i].guide),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.data, required this.currentPage, required this.onTap});

  final _BannerData data;
  final int currentPage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          // A gradient blends between colours. To use a picture instead:
          //   image: DecorationImage(image: AssetImage('assets/heart.png'), fit: BoxFit.cover),
          gradient: LinearGradient(colors: data.colors),
        ),
        child: Row(
          children: [
            Icon(data.icon, color: Colors.white.withValues(alpha: 0.9), size: 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(data.small, style: AppFonts.body(size: 13, color: Colors.white)),
                  Text(data.big,
                      textAlign: TextAlign.right,
                      style: AppFonts.body(size: 22, weight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(data.caption,
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
  const _InfoCardRow({required this.services});
  final AppServices services;

  /// (title, colour, the Health guide it opens)
  static const _cards = [
    ('Prevent the spread\nof COVID-19 Virus', Color(0xFF2F5BE0), Guides.infections),
    ('Know your numbers:\ncheck your blood pressure', Color(0xFFEF4B3F), Guides.bloodPressure),
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
          final (title, color, guide) = _cards[i];
          return GestureDetector(
            key: Key('card-$guide'),
            onTap: () => openGuide(context, services, guide),
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
