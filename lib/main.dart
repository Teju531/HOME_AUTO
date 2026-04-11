import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/app_store.dart';
import 'constants/app_constants.dart';

import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/add_channel_qr_screen.dart';
import 'screens/add_channel_wifi_screen.dart';
import 'screens/connecting_screen.dart';
import 'screens/connection_success_screen.dart';
import 'screens/connection_failed_screen.dart';
import 'screens/home_screen.dart';
import 'screens/my_channels_screen.dart';
import 'screens/channel_home_screen.dart' show ChannelHomeScreen;
import 'screens/add_device_to_channel_screen.dart';
import 'screens/my_devices_screen.dart';
import 'screens/my_scenes_screen.dart';
import 'screens/manage_scene_screen.dart';
import 'screens/users_screen.dart';
import 'screens/user_permissions_screen.dart';
import 'screens/my_account_screen.dart';
import 'screens/home_setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp().timeout(
    const Duration(seconds: 10),
    onTimeout: () => throw Exception('Firebase init timed out'),
  );
  initProfileAvatarStore(AppStore.instance);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const IoTApp());
}

class IoTApp extends StatelessWidget {
  const IoTApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT Smart Home',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF2F2F2),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF5E60CE),
        ),
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AuthWrapper(),
      routes: {
        '/onboarding':         (_) => const OnboardingScreen(),
        '/login':              (_) => const LoginScreen(),
        '/signup':             (_) => const SignupScreen(),
        '/forgot':             (_) => const ForgotPasswordScreen(),
        '/check-email':        (_) => const CheckEmailScreen(),
        '/create-password':    (_) => const CreateNewPasswordScreen(),
        '/home-setup':         (_) => const HomeSetupScreen(),
        '/home':               (_) => const HomeScreen(),
        '/my-channels':        (_) => const MyChannelsScreen(),
        '/channel-home':       (_) => const ChannelHomeScreen(),
        '/add-channel-qr':     (_) => const AddChannelQRScreen(),
        '/scan-channel-qr':    (_) => const AddChannelQRScreen(),
        '/add-channel-wifi':   (_) => const AddChannelWifiScreen(),
        '/connecting':         (_) => const ConnectingScreen(),
        '/connection-success': (_) => const ConnectionSuccessScreen(),
        '/connection-failed':  (_) => const ConnectionFailedScreen(),
        '/add-device':         (_) => const AddDeviceToChannelScreen(),
        '/my-devices':         (_) => const MyDevicesScreen(),
        '/my-scenes':          (_) => const MyScenesScreen(),
        '/manage-scene':       (_) => const ManageSceneScreen(),
        '/users':              (_) => const UsersScreen(),
        '/user-permissions':   (_) => const UserPermissionsScreen(),
        '/my-account':         (_) => const MyAccountScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _activeUid;
  bool _initializing = false;
  bool _navigated = false;

  @override
  void dispose() {
    AppStore.instance.stopRealtime();
    super.dispose();
  }

  Future<void> _initForUser(String uid) async {
    // Reset so loadFromFirestore always re-reads from Firestore fresh
    AppStore.instance.homeId = null;

    await AppStore.instance.loadFromFirestore();
    if (!mounted || _navigated) return;

    final homeId = AppStore.instance.homeId;
    if (homeId == null) {
      _go('/home-setup');
      return;
    }

    _go('/home');
  }

  void _go(String route) {
    if (!mounted || _navigated) return;
    _navigated = true;
    setState(() => _initializing = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pushReplacementNamed(context, route);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _initializing) {
          return const Scaffold(body: Center(child: _StartupLogoAnimation()));
        }

        if (snapshot.hasData) {
          final uid = snapshot.data!.uid;
          if (_activeUid != uid) {
            _activeUid = uid;
            _navigated = false;
            _initializing = true;
            Future.microtask(() => _initForUser(uid));
            AppStore.instance.startRealtime(uid).catchError((e) {
              debugPrint('Realtime MQTT start failed: $e');
            });
          }
          return const Scaffold(body: Center(child: _StartupLogoAnimation()));
        }

        // Logged out
        if (_activeUid != null) {
          _activeUid = null;
          _navigated = false;
          _initializing = false;
          AppStore.instance.homeId = null;
          AppStore.instance.stopRealtime();
          AppStore.instance.stopScheduleChecker();
        }
        return const OnboardingScreen();
      },
    );
  }
}

class _StartupLogoAnimation extends StatefulWidget {
  const _StartupLogoAnimation();

  @override
  State<_StartupLogoAnimation> createState() => _StartupLogoAnimationState();
}

class _StartupLogoAnimationState extends State<_StartupLogoAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.75, end: 1.0).animate(_opacity),
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 230,
              height: 120,
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Apsis smart home',
              style: TextStyle(
                color: Color(0xFF5E60CE),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
