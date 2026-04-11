import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_constants.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _obscurePass = true, _obscureConfirm = true, _accepted = false;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the terms and policy')),
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
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      // AuthWrapper listens to authStateChanges and routes to /home or /home-setup
    } on FirebaseAuthException catch (e) {
      String message = 'Signup failed';
      if (e.code == 'email-already-in-use') message = 'Email already in use';
      if (e.code == 'weak-password') message = 'Password is too weak';
      if (e.code == 'invalid-email') message = 'Invalid email address';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
              const Expanded(child: Center(child: Text('Sign Up', style: TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w700)))),
              const SizedBox(width: 48),
            ]),
            const SizedBox(height: 20),
            _label('Email'), _field(_emailCtrl, 'email@email.com', false),
            const SizedBox(height: 16),
            _label('Password'), _passField(_passCtrl, 'password@123', _obscurePass, () => setState(() => _obscurePass = !_obscurePass)),
            const SizedBox(height: 16),
            _label('Confirm Password'), _passField(_confirmCtrl, 'password@123', _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),
            const SizedBox(height: 16),
            Row(children: [
              SizedBox(width: 20, height: 20, child: Checkbox(value: _accepted, onChanged: (v) => setState(() => _accepted = v ?? false), activeColor: AppColors.primary, side: const BorderSide(color: Color(0xFF999999), width: 1.5))),
              const SizedBox(width: 8),
              const Text('I accept the policy and terms.', style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
            ]),
            const SizedBox(height: 24),
            GradientButton(text: 'Continue', onPressed: _signup, height: 52),
            const SizedBox(height: 14),
            Center(child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text.rich(TextSpan(text: 'Already have an account? ', style: TextStyle(color: Color(0xFF888888), fontSize: 13), children: [TextSpan(text: 'Login here', style: TextStyle(color: AppColors.primary))])),
            )),
            const SizedBox(height: 40),
            Align(alignment: Alignment.centerRight, child: Opacity(opacity: 0.5, child: Icon(Icons.lightbulb_outline, size: 140, color: const Color(0xFFFFD600).withOpacity(0.7)))),
          ]),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(color: Color(0xFF888888), fontSize: 15)));

  Widget _field(TextEditingController ctrl, String hint, bool obscure) => TextField(
    controller: ctrl,
    obscureText: obscure,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 15),
      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCCCCCC))),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
    ),
  );

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
