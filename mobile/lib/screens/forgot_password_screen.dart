// =============================================================================
// 3. FORGOT PASSWORD INTERFACE (Figure 3.17)
// Back arrow, serif heading, grey subtitle, one e-mail field, Reset button.
// =============================================================================
import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/primary_button.dart';
import '../widgets/rounded_field.dart';
import 'login_screen.dart' show showErrorDialog, validateEmail;

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    String? error;
    try {
      await widget.services.auth.sendPasswordReset(_email.text);
    } on AuthFailure catch (e) {
      error = e.message;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      await showErrorDialog(context, 'Could not send email', error);
    } else {
      // A SnackBar is the small message that slides up from the bottom.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Reset instructions sent to ${_email.text.trim()}.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(alignment: Alignment.centerLeft, child: AppBackButton()),
                    const SizedBox(height: 120),
                    // FittedBox shrinks the heading on very narrow phones instead of wrapping.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Forgot Password?', style: AppFonts.serif(size: 34)),
                    ),
                    const SizedBox(height: 8),
                    Text("No worries, we'll send you reset instruction",
                        textAlign: TextAlign.center,
                        style: AppFonts.body(size: 15, color: AppColors.hint)),
                    const SizedBox(height: 110),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: RoundedField(
                        fieldKey: const Key('resetEmail'),
                        controller: _email,
                        hint: 'Enter your email',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        validator: validateEmail,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: PrimaryButton(
                        key: const Key('resetPassword'),
                        label: 'Reset Password',
                        width: 260,
                        loading: _loading,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
