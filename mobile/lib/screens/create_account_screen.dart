// =============================================================================
// 2. CREATE ACCOUNT INTERFACE (Figure 3.16) - use case "Register" (Table 3.12)
//
// First/last name side by side, then e-mail, password, contact number, date of
// birth, a Male/Female toggle and the Create Account button. Green waves
// top-left and bottom-left.
//
// Date of birth, sex and contact are asked ONLY here (decisions 2026-11-04);
// every check reuses them. The mockup's "Age" box became "Date of birth" so the
// age is calculated from today's date at each check and never goes out of date.
//
// Assumption: the mockup draws the eye icon on the E-mail row, which looks
// like a copy-paste slip; it is placed on the Password row, where it works.
// =============================================================================
import 'package:flutter/material.dart';

import '../models/user_details.dart';
import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/rounded_field.dart';
import '../widgets/wave_header.dart';
import 'login_screen.dart' show PasswordEyeButton, showErrorDialog, validateEmail;

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _contact = TextEditingController();
  final _dobText = TextEditingController(); // shows the chosen date, e.g. "20/5/1990"
  DateTime? _dob;

  String _sex = 'Male';     // the toggle's current choice
  bool _hidePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _email, _password, _contact, _dobText]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v, String what) =>
      (v == null || v.trim().isEmpty) ? 'Enter your $what.' : null;

  /// Opens a calendar. Only adults can be chosen: the app is for 18+, the same
  /// rule as the database (firestore.rules: 18-120).
  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(now.year - 120, now.month, now.day),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Date of birth',
    );
    if (picked == null) return;
    setState(() {
      _dob = picked;
      _dobText.text = '${picked.day}/${picked.month}/${picked.year}';
    });
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    String? error;
    try {
      final profile = widget.services.profile, dob = _dob!, sex = _sex.toLowerCase();
      final contact = _contact.text.trim();
      await widget.services.auth.register(
        firstName: _firstName.text,
        lastName: _lastName.text,
        email: _email.text,
        password: _password.text,
        // Date of birth, sex and contact are asked ONLY here; every check reuses
        // them. register() runs this while the new account is still signed in.
        onCreated: (uid) => profile.saveAccount(
          uid: uid,
          dateOfBirth: dob,
          sex: sex, // 'male' / 'female', the API's spelling
          contact: contact,
        ),
      );
    } on AuthFailure catch (e) {
      error = e.message;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      await showErrorDialog(context, 'Could not create account', error);
      return;
    }

    // Success: go back to Login (Table 3.12) and show a short message there.
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
        const SnackBar(content: Text('Account created. Please log in.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const WaveHeader(height: 115, widthFactor: 0.6),
          // Positioned pins a child to an edge of the Stack.
          const Positioned(left: 0, bottom: 0, child: BottomCornerWave()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 50),
                        Text('Create account',
                            textAlign: TextAlign.center, style: AppFonts.title(size: 30)),
                        const SizedBox(height: 4),
                        Text('Personal information',
                            textAlign: TextAlign.center,
                            style: AppFonts.body(size: 15, color: AppColors.hint)),
                        const SizedBox(height: 32),
                        // First + last name share one row: each gets half (Expanded).
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: RoundedField(
                                fieldKey: const Key('firstName'),
                                controller: _firstName,
                                hint: 'First name',
                                icon: Icons.person,
                                textInputAction: TextInputAction.next,
                                validator: (v) => _required(v, 'first name'),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: RoundedField(
                                fieldKey: const Key('lastName'),
                                controller: _lastName,
                                hint: 'Last name',
                                icon: Icons.person,
                                textInputAction: TextInputAction.next,
                                validator: (v) => _required(v, 'last name'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        RoundedField(
                          fieldKey: const Key('regEmail'),
                          controller: _email,
                          hint: 'E-mail',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: validateEmail,
                        ),
                        const SizedBox(height: 22),
                        RoundedField(
                          fieldKey: const Key('regPassword'),
                          controller: _password,
                          hint: 'Password',
                          icon: Icons.lock,
                          obscure: _hidePassword,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              (v ?? '').length < 6 ? 'At least 6 characters.' : null,
                          suffix: PasswordEyeButton(
                            hidden: _hidePassword,
                            onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          ),
                        ),
                        const SizedBox(height: 22),
                        RoundedField(
                          fieldKey: const Key('contact'),
                          controller: _contact,
                          hint: 'Contact Number',
                          icon: Icons.phone_android,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          validator: (v) => _required(v, 'contact number'),
                        ),
                        const SizedBox(height: 22),
                        RoundedField(
                          fieldKey: const Key('dob'),
                          controller: _dobText,
                          hint: 'Date of birth',
                          icon: Icons.calendar_month,
                          readOnly: true,     // no keyboard: tapping opens the calendar
                          onTap: _pickDob,
                          validator: (_) {
                            if (_dob == null) return 'Choose your date of birth.';
                            final age = UserProfile.ageFromBirth(_dob!, DateTime.now());
                            return (age < 18 || age > 120) ? 'You must be 18-120 years old.' : null;
                          },
                        ),
                        const SizedBox(height: 40),
                        _SexToggle(
                          value: _sex,
                          onChanged: (v) => setState(() => _sex = v),
                        ),
                        const SizedBox(height: 28),
                        Center(
                          child: PrimaryButton(
                            key: const Key('createAccount'),
                            label: 'Create Account',
                            width: 260,
                            loading: _loading,
                            onPressed: _submit,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The grey "Male | Female" switch. Only used here, so it lives in this file
/// (private: the leading _ means other files can't use it).
class _SexToggle extends StatelessWidget {
  const _SexToggle({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3), // the grey border around the white pill
      decoration: BoxDecoration(
        color: AppColors.segmentTrack,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          for (final option in const ['Male', 'Female'])
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(option),
                // AnimatedContainer animates the white highlight sliding across.
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == option ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(option,
                      style: AppFonts.body(
                          size: 14, color: value == option ? Colors.black : AppColors.iconGrey)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
