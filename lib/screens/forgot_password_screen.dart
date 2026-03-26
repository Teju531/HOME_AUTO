import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_constants.dart';

// ─── Forgot Password ──────────────────────────────────────────────────────────
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      Navigator.pushNamed(context, '/check-email');
    } on FirebaseAuthException catch (e) {
      String message = 'Something went wrong';
      if (e.code == 'user-not-found') {
        message = 'No account found with this email';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.primary), onPressed: () => Navigator.pop(context)),
              const Expanded(child: Center(child: Text('Forgot Password', style: TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w700)))),
              const SizedBox(width: 48),
            ]),
            const SizedBox(height: 24),
            const Text("Enter the email associated with your account and we'll send an email with instructions to reset your password.", style: TextStyle(color: Color(0xFF666666), fontSize: 15, height: 1.5)),
            const SizedBox(height: 28),
            const Text('Email', style: TextStyle(color: Color(0xFF888888), fontSize: 15)),
            const SizedBox(height: 6),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'email@email.com',
                hintStyle: TextStyle(color: Color(0xFFAAAAAA), fontSize: 15),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCCCCCC))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
              ),
            ),
            const SizedBox(height: 36),
            GradientButton(text: 'Continue', onPressed: _sendReset, height: 52),
            const SizedBox(height: 80),
            Align(alignment: Alignment.centerRight, child: Opacity(opacity: 0.5, child: Icon(Icons.lightbulb_outline, size: 140, color: const Color(0xFFFFD600).withOpacity(0.7)))),
          ]),
        ),
      ),
    );
  }
}

// ─── Check Email ──────────────────────────────────────────────────────────────
class CheckEmailScreen extends StatelessWidget {
  const CheckEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const Spacer(flex: 2),
            const Icon(Icons.mark_email_read_outlined, size: 80, color: Color(0xFFCCCCCC)),
            const SizedBox(height: 24),
            const Text('Check Your Email', style: TextStyle(color: Color(0xFF444444), fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const Text('We have sent a password recovery\ninstructions to your registered email.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF888888), fontSize: 15, height: 1.5)),
            const SizedBox(height: 32),
            GradientButton(text: 'Ok', onPressed: () => Navigator.pushReplacementNamed(context, '/login'), height: 52, width: 200),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text.rich(TextSpan(text: "Didn't receive the email? Check your spam folder or ", style: TextStyle(color: Color(0xFF888888), fontSize: 13), children: [TextSpan(text: 'try again', style: TextStyle(color: AppColors.primary))]), textAlign: TextAlign.center),
            ),
            const Spacer(flex: 3),
          ]),
        ),
      ),
    );
  }
}

// ─── Create New Password ──────────────────────────────────────────────────────
// Note: Firebase handles password reset via email link.
// This screen is kept for UI purposes only.
class CreateNewPasswordScreen extends StatefulWidget {
  const CreateNewPasswordScreen({super.key});
  @override
  State<CreateNewPasswordScreen> createState() => _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen> {
  bool _obscure1 = true, _obscure2 = true;
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_passCtrl.text.trim().length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters')),
      );
      return;
    }
    if (_passCtrl.text.trim() != _confirmCtrl.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updatePassword(_passCtrl.text.trim());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully')),
        );
      }
      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to update password')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.primary), onPressed: () => Navigator.pop(context)),
              const Expanded(child: Center(child: Text('Create New Password', style: TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w700)))),
              const SizedBox(width: 48),
            ]),
            const SizedBox(height: 24),
            const Text("Your new password must be different from your previously used passwords.", style: TextStyle(color: Color(0xFF666666), fontSize: 14, height: 1.5)),
            const SizedBox(height: 28),
            const Text('Password', style: TextStyle(color: Color(0xFF888888), fontSize: 15)),
            const SizedBox(height: 6),
            _passField(_passCtrl, 'password@123', _obscure1, () => setState(() => _obscure1 = !_obscure1)),
            const SizedBox(height: 6),
            const Text('Must be at least 8 characters.', style: TextStyle(color: Color(0xFF999999), fontSize: 12)),
            const SizedBox(height: 20),
            const Text('Confirm Password', style: TextStyle(color: Color(0xFF888888), fontSize: 15)),
            const SizedBox(height: 6),
            _passField(_confirmCtrl, 'password@123', _obscure2, () => setState(() => _obscure2 = !_obscure2)),
            const SizedBox(height: 6),
            const Text('Both passwords must match.', style: TextStyle(color: Color(0xFF999999), fontSize: 12)),
            const SizedBox(height: 36),
            GradientButton(text: 'Reset Password', onPressed: _resetPassword, height: 52),
            const SizedBox(height: 60),
            Align(alignment: Alignment.centerRight, child: Opacity(opacity: 0.5, child: Icon(Icons.lightbulb_outline, size: 130, color: const Color(0xFFFFD600).withOpacity(0.7)))),
          ]),
        ),
      ),
    );
  }

  Widget _passField(TextEditingController ctrl, String hint, bool obscure, VoidCallback toggle) => TextField(
    controller: ctrl,
    obscureText: obscure,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 15),
      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCCCCCC))),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
      suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey, size: 20), onPressed: toggle),
    ),
  );
}