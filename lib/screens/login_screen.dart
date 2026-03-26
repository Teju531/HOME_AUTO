import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../constants/app_constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscure = true;
  bool _rememberMe = false;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      String message = "Login failed";
      if (e.code == 'user-not-found') {
        message = "No user found with this email";
      } else if (e.code == 'wrong-password') {
        message = "Incorrect password";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _googleSignIn() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return; // user cancelled

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In failed: $e')),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Logo
              Center(
                child: Image.asset(
                  'assets/logo.png',
                  height: 80,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.home_outlined, size: 80, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),
              // AppBar row
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                    onPressed: () => Navigator.pushReplacementNamed(context, '/onboarding'),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text('Login',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 20),
              _fieldLabel('Email'),
              _underlineField(_emailCtrl, 'email@email.com', false),
              const SizedBox(height: 20),
              _fieldLabel('Password'),
              _underlineField(_passCtrl, 'password@123', true, isPassword: true),
              const SizedBox(height: 14),
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (v) => setState(() => _rememberMe = v ?? false),
                      activeColor: AppColors.primary,
                      side: const BorderSide(color: Color(0xFF999999), width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Remember Me',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 14)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/forgot'),
                    child: const Text('Forgot Password?',
                        style: TextStyle(color: Color(0xFF888888), fontSize: 14)),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              GradientButton(text: 'Login', onPressed: _login, height: 52),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/signup'),
                  child: const Text.rich(TextSpan(
                    text: "Don't have an account? ",
                    style: TextStyle(color: Color(0xFF888888), fontSize: 13),
                    children: [
                      TextSpan(
                          text: 'Sign Up here',
                          style: TextStyle(color: AppColors.primary))
                    ],
                  )),
                ),
              ),
              const SizedBox(height: 22),
              Row(children: const [
                Expanded(child: Divider()),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR',
                        style: TextStyle(color: Color(0xFF888888), fontSize: 13))),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 18),
              Row(
                children: [
                  // FB button (not implemented)
                  Expanded(
                    child: _socialBtn(
                      'Connect with FB',
                      const Color(0xFF4267B2),
                      Icons.facebook,
                      () {}, // FB login not implemented
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Google button
                  Expanded(
                    child: _socialBtn(
                      'Connect with G+',
                      const Color(0xFF333333),
                      Icons.g_mobiledata,
                      _googleSignIn, // 👈 connected
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: Opacity(
                  opacity: 0.55,
                  child: Icon(Icons.lightbulb_outline,
                      size: 120,
                      color: const Color(0xFFFFD600).withOpacity(0.7)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label,
            style: const TextStyle(color: Color(0xFF888888), fontSize: 15)),
      );

  Widget _underlineField(TextEditingController ctrl, String hint, bool obscure,
      {bool isPassword = false}) {
    return TextField(
      controller: ctrl,
      obscureText: isPassword ? _obscure : false,
      style: const TextStyle(color: Color(0xFF555555), fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 15),
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFCCCCCC))),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                    size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
      ),
    );
  }

  Widget _socialBtn(String label, Color color, IconData icon, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
}
