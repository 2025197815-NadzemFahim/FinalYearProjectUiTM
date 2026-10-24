// The rounded white cards on the Profile mockup (Figure 3.24):
//
//   ( icon ) My Activity             >
//   ------------------------------------
//   ( icon ) Settings                 >
//
// MenuCard draws the card and the lines between rows; MenuItem is one row.
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One row: grey circle icon, label, chevron. Plain data - MenuCard draws it.
class MenuItem {
  const MenuItem({required this.icon, required this.label, required this.onTap, this.key});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Key? key; // lets tests find this row
}

class MenuCard extends StatelessWidget {
  const MenuCard({super.key, required this.items});

  final List<MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      // ClipRRect cuts the tap ripple to the rounded corners.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) // a divider between rows, not before the first one
                  const Divider(height: 1, indent: 20, endIndent: 20, color: AppColors.divider),
                _MenuRow(item: items[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item});
  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: item.key,
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        // Row places its children left to right.
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.tileIconBg,
              child: Icon(item.icon, color: Colors.black87, size: 20),
            ),
            const SizedBox(width: 16),
            // Expanded makes the label take all the space left over,
            // which pushes the chevron to the far right.
            Expanded(child: Text(item.label, style: AppFonts.body(size: 17))),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
