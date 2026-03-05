import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/app_store.dart';
import 'qr_scanner_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class AddChannelQRScreen extends StatefulWidget {
  const AddChannelQRScreen({super.key});
  @override
  State<AddChannelQRScreen> createState() => _AddChannelQRScreenState();
}

class _AddChannelQRScreenState extends State<AddChannelQRScreen> {
  final _nameCtrl = TextEditingController(text: 'Migro_CH1');
  bool _rememberWifi = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // ── App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primaryDark, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text('Add Channel', textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      TextButton(
                        onPressed: _onNext,
                        child: const Text('Next', style: TextStyle(color: AppColors.primaryDark, fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Plug image
                        Center(
                          child: Container(
                            width: 200,
                            height: 180,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 8)],
                            ),
                            child: const Icon(Icons.electrical_services, color: AppColors.primaryMid, size: 80),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Scan QR button
                        OutlinedButton(
                          onPressed: _scanQRCode,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          child: const Text('Scan QR Code',
                              style: TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(height: 20),

                        // ── OR divider
                        Row(children: [
                          const Expanded(child: Divider(color: AppColors.primary, thickness: 1)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('OR', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                          const Expanded(child: Divider(color: AppColors.primary, thickness: 1)),
                        ]),
                        const SizedBox(height: 20),

                        // ── Channel Name
                        const Text('Set Channel Name',
                            style: TextStyle(color: AppColors.textLight, fontSize: 15, fontWeight: FontWeight.w400)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameCtrl,
                          style: const TextStyle(color: AppColors.primaryMid, fontSize: 14, fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            hintText: 'Migro_CH1',
                            hintStyle: TextStyle(color: AppColors.grey),
                            border: UnderlineInputBorder(),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.lightGrey)),
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Remember WiFi toggle
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text('Remember WiFi Settings',
                                      style: TextStyle(color: AppColors.primaryDark, fontSize: 14, fontWeight: FontWeight.w600)),
                                  SizedBox(height: 2),
                                  Text('(Saving WiFi settings will make future device setup much easier)',
                                      style: TextStyle(color: AppColors.textLight, fontSize: 12, height: 1.3)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Switch(
                              value: _rememberWifi,
                              onChanged: (v) => setState(() => _rememberWifi = v),
                              activeColor: AppColors.primaryDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // ── Bottom nav
            Positioned(
              left: 16, right: 16, bottom: 14,
              child: Row(children: [
                _navBtn(Icons.home, AppColors.primaryDark, () => Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false)),
                const SizedBox(width: 10),
                _navBtn(Icons.nightlight_round, AppColors.primaryDark, () => Navigator.pushNamed(context, '/my-scenes')),
                const SizedBox(width: 10),
                _navBtn(Icons.grid_view_rounded, AppColors.primaryDark, () => Navigator.pushNamed(context, '/my-channels')),
                const SizedBox(width: 10),
                _navBtn(Icons.view_in_ar, AppColors.primaryDark, () {}),
                const SizedBox(width: 10),
                _navBtn(Icons.people_outline, AppColors.primaryDark, () => Navigator.pushNamed(context, '/users')),
                const Spacer(),
                _navBtn(Icons.close, AppColors.red, () => Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  void _scanQRCode() async {
    // Request camera permission
    final status = await Permission.camera.request();
    
    if (status.isGranted) {
      if (!mounted) return;
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const QRScannerScreen()),
      );
      
      if (result != null && mounted) {
        setState(() {
          _nameCtrl.text = result;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QR Code scanned: $result'), backgroundColor: AppColors.green),
        );
      }
    } else if (status.isDenied || status.isPermanentlyDenied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required to scan QR codes'),
          backgroundColor: AppColors.red,
        ),
      );
      if (status.isPermanentlyDenied) {
        openAppSettings();
      }
    }
  }

  void _onNext() {
    final name = _nameCtrl.text.trim();
    if (name.isNotEmpty) {
      Navigator.pushNamed(context, '/add-channel-wifi', arguments: name);
    }
  }

  Widget _navBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
