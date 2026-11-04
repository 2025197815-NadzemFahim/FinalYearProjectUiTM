// The white card that opens and closes, from Figures 3.20 and 3.22:
//
//   | Heart Disease  50%                     v |   <- header (tap to open/close)
//   |------------------------------------------|   <- thin line
//   |  Your responses indicate ...             |   <- body (only when open)
//   |             [ Deep Check ]               |
//
// It is a StatefulWidget because "open or closed" changes while it is on screen.
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ExpandableCard extends StatefulWidget {
  const ExpandableCard({
    super.key,
    required this.title,
    required this.child,
    this.trailingText,
    this.initiallyExpanded = false,
  });

  final String title;          // "Heart Disease"
  final String? trailingText;  // "50%" - grey text after the title
  final Widget child;          // what appears when the card is open
  final bool initiallyExpanded;

  @override
  State<ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<ExpandableCard> {
  // "late" = given a value before first use (in initState below).
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded; // "widget." reads the constructor values
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), // space BELOW the card (outside it)
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          // InkWell makes the header tappable and shows a ripple.
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            // setState changes the value AND redraws the card.
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 16, 14), // space inside: left, top, right, bottom
              child: Row(
                children: [
                  // Flexible: on a narrow screen the texts shrink with "..." instead
                  // of overflowing the card (the yellow-black stripes).
                  Flexible(
                    child: Text(widget.title, style: AppFonts.serif(size: 15),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (widget.trailingText != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(widget.trailingText!, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: AppFonts.body(size: 15, color: AppColors.hint)),
                    ),
                  ],
                  const Spacer(),
                  // Arrow points down when open, right when closed (as in the mockup).
                  Icon(_expanded ? Icons.keyboard_arrow_down : Icons.chevron_right, size: 28),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          // AnimatedSize smoothly grows/shrinks the card when the body appears.
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _expanded
                ? Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 20), child: widget.child)
                : const SizedBox(width: double.infinity, height: 16), // empty strip when closed
          ),
        ],
      ),
    );
  }
}
