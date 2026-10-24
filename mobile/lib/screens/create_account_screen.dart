// =============================================================================
// 2. CREATE ACCOUNT INTERFACE (Figure 3.16) - use case "Register" (Table 3.12)
//
// First/last name side by side, then e-mail, password, contact number, age,
// a Male/Female toggle and the Create Account button. Green waves top-left
// and bottom-left.
//
// Assumption: the mockup draws the eye icon on the E-mail row, which looks
// like a copy-paste slip; it is placed on the Password row, where it works.
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final _age = TextEditingController();

  String _sex = 'Male';     // the toggle's current choice
  bool _hidePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _email, _password, _contact, _age]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v, String what) =>
      (v == null || v.trim().isEmpty) ? 'Enter your $what.' : null;

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    String? error;
    try {
      await widget.services.auth.register(
        firstName: _firstName.text,
        lastName: _lastName.text,
        email: _email.text,
        password: _password.text,
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
                          fieldKey: const Key('age'),
                          controller: _age,
                          hint: 'Age',
                          icon: Icons.calendar_month,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (v) {
                            final age = int.tryParse(v ?? '');
                            // Same rule as the database (firestore.rules): 18-120.
                            if (age == null || age < 18 || age > 120) return 'Age must be 18-120.';
                            return null;
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
