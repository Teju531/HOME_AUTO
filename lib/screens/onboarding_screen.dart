import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _ctrl = PageController();
  int _current = 0;

  final List<_Page> _pages = const [
    _Page(
      title: 'CONNECT',
      desc: 'Connect all your smart home\ndevices using easiest steps\nand manage fast.',
      titleColor: Color(0xFF8A6FEA),
      bgColor: Color(0xFFECEBFF),
      imagePath: 'assets/connect.png',
    ),
    _Page(
      title: 'CONTROL',
      desc: 'Control your devices from home,\nabroad or from anywhere in the\nworld and just relax.',
      titleColor: Color(0xFFE86BC0),
      bgColor: Color(0xFFFFE8F6),
      imagePath: 'assets/control.png',
    ),
    _Page(
      title: 'SAVE',
      desc: 'Create scenes as per your\nmood and needs, just one click\nand manage your home.',
      titleColor: Color(0xFF6B79EA),
      bgColor: Color(0xFFECEBFF),
      imagePath: 'assets/save.png',
    ),
  ];

  void _skip() => Navigator.pushReplacementNamed(context, '/login');

  @override
  Widget build(BuildContext context) {
    final page = _pages[_current];
    final bool isLast = _current == _pages.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) => _PageContent(page: _pages[i]),
              ),
            ),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: _current == i ? 14 : 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _current == i ? page.titleColor : const Color(0xFFCCCCCC),
                ),
              )),
            ),
            const SizedBox(height: 32),
            // Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _skip,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: page.titleColor, width: 1.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Text(
                    isLast ? 'Get Started' : 'Skip',
                    style: TextStyle(color: page.titleColor, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Page {
  final String title, desc;
  final Color titleColor, bgColor;
  final String imagePath;
  const _Page({
    required this.title,
    required this.desc,
    required this.titleColor,
    required this.bgColor,
    required this.imagePath,
  });
}

class _PageContent extends StatelessWidget {
  final _Page page;
  const _PageContent({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        children: [
          // Logo at top
          SizedBox(
            width: 200,
            height: 72,
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.home_outlined, size: 60, color: Color(0xFF8A6FEA)),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  color: page.bgColor,
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Blob background decorations
                    Positioned(top: 20, right: 20, child: Container(width: 30, height: 30, decoration: BoxDecoration(color: page.titleColor.withOpacity(0.3), shape: BoxShape.circle))),
                    Positioned(bottom: 30, left: 20, child: Container(width: 18, height: 18, decoration: BoxDecoration(color: const Color(0xFFFF7BAC).withOpacity(0.5), shape: BoxShape.circle))),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Image.asset(
                        page.imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.image_not_supported_outlined,
                          size: 80,
                          color: page.titleColor.withOpacity(0.85),
                        ),
                      ),
                    ),
                    Positioned(bottom: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: page.titleColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Text('IoT', style: TextStyle(color: page.titleColor, fontWeight: FontWeight.w600, fontSize: 13)))),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(page.title, style: TextStyle(color: page.titleColor, fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: 1)),
          const SizedBox(height: 16),
          Text(page.desc, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF888888), fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }
}
