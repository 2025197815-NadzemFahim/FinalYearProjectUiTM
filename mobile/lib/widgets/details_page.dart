// The shared layout of My details, Medical history and the Lifestyle check:
//
//   <-
//   My details                 <- serif title
//   Asked once, used in...     <- grey subtitle
//   [questions...]
//        [ Save ]
//
// Each screen only supplies its questions and what Save does.
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_back_button.dart';
import 'phone_width.dart';
import 'primary_button.dart';

class DetailsPage extends StatelessWidget {
  const DetailsPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.formKey,
    required this.children,
    required this.onSave,
    required this.saveKey,
    this.saving = false,
    this.saveLabel = 'Save',
  });

  final String title;
  final String subtitle;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;   // the questions
  final VoidCallback onSave;
  final Key saveKey;             // lets tests find the button
  final bool saving;             // shows a spinner on the button
  final String saveLabel;

  /// Call when Save finds missing answers. The red messages may be off-screen
  /// (e.g. date of birth at the top while you're at the Save button), so say so here.
  static void showMissing(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
          content: Text('Some answers are missing. They are marked in red above.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PhoneWidth(
          child: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                const Align(alignment: Alignment.centerLeft, child: AppBackButton()),
                Text(title, style: AppFonts.serif(size: 30)),
                const SizedBox(height: 4),
                Text(subtitle, style: AppFonts.body(size: 13, color: AppColors.hint)),
                const SizedBox(height: 24),
                ...children,
                const SizedBox(height: 12),
                Center(
                  child: PrimaryButton(
                    key: saveKey, label: saveLabel, width: 200, loading: saving, onPressed: onSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
