// The shared layout of the Profile pages that only SHOW information
// (My Activity, Settings, Privacy & Security). Same look as DetailsPage
// (the form pages), without the Save button:
//
//   <-
//   My Activity                       <- serif title
//   Your checks and your details.     <- grey subtitle
//   +-------------------------------+
//   | Your deep checks              |  <- InfoCard (white, rounded)
//   | (icon) Heart Disease    72.4% |  <- InfoRow
//   |        2 checks, latest Today |
//   +-------------------------------+
//
// Four widgets live here: InfoPage, InfoCard, InfoRow and Bullet.
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_back_button.dart';
import 'phone_width.dart';

/// Back arrow, title, subtitle, then the [children] (usually InfoCards).
class InfoPage extends StatelessWidget {
  const InfoPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PhoneWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              const Align(alignment: Alignment.centerLeft, child: AppBackButton()),
              Text(title, style: AppFonts.serif(size: 30)),
              const SizedBox(height: 4),
              Text(subtitle, style: AppFonts.body(size: 13, color: AppColors.hint)),
              const SizedBox(height: 24),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// A white rounded card with an optional heading, e.g. "Your deep checks".
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16), // space between cards
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: AppFonts.body(size: 16, weight: FontWeight.w600)),
            const SizedBox(height: 8),
          ],
          ...children,
        ],
      ),
    );
  }
}

/// One line inside an InfoCard:
///
///   (icon)  Label                 value   >     <- ">" only when it can be tapped
///           a small grey note
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.valueColor,
    this.note,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;       // shown on the right, e.g. "72.4%" or "Up to date"
  final Color? valueColor;   // e.g. the risk colour
  final String? note;        // the grey line under the label
  final VoidCallback? onTap; // null = just information, no chevron

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.mintCard,
            child: Icon(icon, size: 18, color: AppColors.green),
          ),
          const SizedBox(width: 12),

          // The label (and note) take the space left over.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppFonts.body(size: 15)),
                if (note != null)
                  Text(note!, style: AppFonts.body(size: 12, color: AppColors.hint)),
              ],
            ),
          ),

          if (value != null) ...[
            const SizedBox(width: 8),
            Text(
              value!,
              style: AppFonts.body(size: 14, weight: FontWeight.w600, color: valueColor),
            ),
          ],
          if (onTap != null) const Icon(Icons.chevron_right, color: AppColors.hint),
        ],
      ),
    );

    if (onTap == null) return row;

    // InkWell = the tap ripple. It needs a Material above it; the card is white.
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: row),
    );
  }
}

/// One bullet point:  "•  Log out when you use a shared phone."
class Bullet extends StatelessWidget {
  const Bullet(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // the dot stays at the first line
        children: [
          Text('•  ', style: AppFonts.body(size: 14)),
          Expanded(child: Text(text, style: AppFonts.body(size: 14))),
        ],
      ),
    );
  }
}
