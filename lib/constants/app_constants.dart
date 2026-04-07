import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppColors {
  // Primary palette
  static const Color primary = Color(0xFF5E60CE);
  static const Color primaryDark = Color(0xFF070B72);
  static const Color primaryMid = Color(0xFF4B4FA3);

  // Gradient
  static const List<Color> gradientPurplePink = [Color(0xFF7B84F7), Color(0xFFE46BBE)];
  static const List<Color> gradientPurpleLight = [Color(0xFF8784EF), Color(0xFFE177D3)];

  // Accent
  static const Color pink = Color(0xFFE86BC0);
  static const Color orange = Color(0xFFF08A2A);
  static const Color red = Color(0xFFFF4A4A);
  static const Color green = Color(0xFF5ACB5A);
  static const Color greenBorder = Color(0xFF8ED48F);

  // Background
  static const Color background = Color(0xFFF2F2F2);
  static const Color card = Color(0xFFF7F7F7);
  static const Color white = Colors.white;

  // Text
  static const Color textDark = Color(0xFF2C2F84);
  static const Color textMid = Color(0xFF4B4FA3);
  static const Color textLight = Color(0xFF7D7D7D);
  static const Color textOrange = Color(0xFFF08A2A);
  static const Color textPurple = Color(0xFF6C74F3);

  // Neutral
  static const Color grey = Color(0xFFA8A8A8);
  static const Color lightGrey = Color(0xFFE0E0E0);
}

class AppGradients {
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7B84F7), Color(0xFFE46BBE)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

class AppTextStyles {
  static const TextStyle title = TextStyle(
    color: AppColors.primaryMid,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle headline = TextStyle(
    color: AppColors.primaryDark,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle body = TextStyle(
    color: AppColors.textLight,
    fontSize: 14,
  );

  static const TextStyle label = TextStyle(
    color: AppColors.textMid,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );
}

// Profile avatar — listens to AppStore.profilePhoto, taps to /my-account
// Import app_store lazily to avoid circular dependency
class ProfileAvatar extends StatelessWidget {
  final double radius;
  const ProfileAvatar({super.key, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    // Import here to avoid top-level circular import
    final store = _AppStoreRef.instance;
    return ValueListenableBuilder<String?>(
      valueListenable: store.profilePhoto,
      builder: (context, path, _) {
        final user = FirebaseAuth.instance.currentUser;
        final initial = ((user?.displayName?.isNotEmpty == true
            ? user!.displayName![0]
            : user?.email?[0]) ?? '?').toUpperCase();
        final ImageProvider? img =
            path != null && File(path).existsSync() ? FileImage(File(path)) : null;
        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/my-account'),
          child: CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.primary.withOpacity(0.15),
            backgroundImage: img,
            child: img == null
                ? Text(initial,
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: radius * 0.75,
                        fontWeight: FontWeight.w700))
                : null,
          ),
        );
      },
    );
  }
}

// Thin wrapper so app_constants doesn't directly import app_store
class _AppStoreRef {
  static late dynamic instance;
}

void initProfileAvatarStore(dynamic store) {
  _AppStoreRef.instance = store;
}

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final double height;
  final double? width;
  final double fontSize;

  const GradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.height = 52,
    this.width,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width ?? double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: AppGradients.primaryGradient,
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// Summary header card (used on many screens)
class SummaryCard extends StatelessWidget {
  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  const SummaryCard({
    super.key,
    this.leftLabel = 'Good Morning!',
    this.leftValue = 'Nitin',
    required this.rightLabel,
    required this.rightValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primaryMid,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(leftLabel, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(leftValue, style: const TextStyle(color: Colors.white, fontSize: 15)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(rightLabel, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(rightValue, style: const TextStyle(color: Colors.white, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }
}

// Bottom nav dock used on most screens
class BottomNavDock extends StatelessWidget {
  final VoidCallback? onHome;
  final VoidCallback? onClose;
  final List<Widget>? extras;

  const BottomNavDock({super.key, this.onHome, this.onClose, this.extras});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 14,
      child: Row(
        children: [
          _NavButton(icon: Icons.home, color: AppColors.primaryDark, onTap: onHome ?? () => Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false)),
          const SizedBox(width: 10),
          if (extras != null) ...extras!.map((w) => Padding(padding: const EdgeInsets.only(right: 10), child: w)),
          const Spacer(),
          _NavButton(icon: Icons.close, color: AppColors.red, onTap: onClose ?? () => Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false)),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}

// Power button circle widget
class PowerButton extends StatelessWidget {
  final bool isOn;
  final VoidCallback onTap;
  final double size;

  const PowerButton({super.key, required this.isOn, required this.onTap, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final Color color = isOn ? AppColors.green : AppColors.red;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: color, width: 2.5),
        ),
        child: Icon(Icons.power_settings_new, color: color, size: size * 0.6),
      ),
    );
  }
}

// Pill/tag widget (for Plug 1, etc.)
class PlugTag extends StatelessWidget {
  final String label;
  const PlugTag(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.orange, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(color: AppColors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
