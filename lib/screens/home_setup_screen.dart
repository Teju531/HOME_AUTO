import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_constants.dart';
import '../models/app_store.dart';
import 'qr_scanner_screen.dart';

class HomeSetupScreen extends StatefulWidget {
  const HomeSetupScreen({super.key});
  @override
  State<HomeSetupScreen> createState() => _HomeSetupScreenState();
}

class _HomeSetupScreenState extends State<HomeSetupScreen> {
  final _nameCtrl  = TextEditingController(text: 'My Home');
  final _idCtrl    = TextEditingController();
  final _tokenCtrl = TextEditingController();
  bool _loading = false;
  // 0=choose, 1=create, 2=join by ID, 3=join by QR/token
  int _mode = 0;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  // ── Create home ────────────────────────────────────────────────────────────
  Future<void> _createHome() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    final homeId = await AppStore.instance.createHome(name);
    if (!mounted) return;
    setState(() => _loading = false);
    if (homeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create home. Try again.'),
              backgroundColor: Colors.red));
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Home Created!',
            style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Your home is ready. You can invite family members from the Users screen.',
              style: TextStyle(color: AppColors.textLight, fontSize: 13)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFECEBFF),
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Expanded(child: Text(homeId,
                  style: const TextStyle(color: AppColors.primaryMid,
                      fontSize: 13, fontWeight: FontWeight.w700))),
              IconButton(
                icon: const Icon(Icons.copy, color: AppColors.primary, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: homeId));
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Home ID copied!')));
                },
              ),
            ]),
          ),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Continue', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    await AppStore.instance.loadFromFirestore();
    Navigator.pushReplacementNamed(context, '/home');
  }

  // ── Join by Home ID ────────────────────────────────────────────────────────
  Future<void> _joinHome() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) return;
    setState(() => _loading = true);
    final ok = await AppStore.instance.joinHome(id);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Home ID not found. Check and try again.'),
              backgroundColor: Colors.red));
      return;
    }
    await AppStore.instance.loadFromFirestore();
    Navigator.pushReplacementNamed(context, '/home');
  }

  // ── Join by scanning invite QR ─────────────────────────────────────────────
  Future<void> _scanInviteQR() async {
    final camStatus = await Permission.camera.request();
    if (!camStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission required.')));
      return;
    }

    if (!mounted) return;
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );

    if (!mounted || result == null || result.trim().isEmpty) return;

    // Show loading immediately after scan so user sees feedback
    setState(() => _loading = true);

    String token = result.trim();
    if (token.toUpperCase().startsWith('INVITE:')) {
      token = token.substring(7).trim();
    }

    await _redeemToken(token);
  }

  // ── Redeem token (from QR or manual entry) ─────────────────────────────────
  Future<void> _redeemToken(String token) async {
    if (token.isEmpty) return;
    setState(() => _loading = true);

    // Show a visible processing dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Text('Joining home...'),
        ]),
      ),
    );

    final error = await AppStore.instance.redeemInvite(token);
    if (!mounted) return;
    Navigator.pop(context); // close dialog
    setState(() => _loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.red));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully joined the home!'),
            backgroundColor: AppColors.green));
    await AppStore.instance.loadFromFirestore();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.home_outlined, size: 72, color: AppColors.primaryMid),
              const SizedBox(height: 16),
              const Text('Set Up Your Home',
                  style: TextStyle(color: AppColors.primaryDark,
                      fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                'Create a new home or join an existing one to share control with your family.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 40),

              // ── Mode 0: Choose
              if (_mode == 0) ...[
                GradientButton(
                  text: 'Create a New Home',
                  onPressed: () => setState(() => _mode = 1),
                  height: 52,
                ),
                const SizedBox(height: 12),
                // Join with QR (primary join method)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _scanInviteQR,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    icon: const Icon(Icons.qr_code_scanner,
                        color: AppColors.primary, size: 20),
                    label: const Text('Join with Invite QR',
                        style: TextStyle(color: AppColors.primary, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 12),
                // Join by entering token manually
                TextButton(
                  onPressed: () => setState(() => _mode = 3),
                  child: const Text('Enter invite code manually',
                      style: TextStyle(color: AppColors.textLight, fontSize: 13)),
                ),
                const SizedBox(height: 4),
                // Join by Home ID (legacy)
                TextButton(
                  onPressed: () => setState(() => _mode = 2),
                  child: const Text('Join with Home ID',
                      style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                ),
              ],

              // ── Mode 1: Create
              if (_mode == 1) ...[
                const Align(alignment: Alignment.centerLeft,
                    child: Text('Home Name',
                        style: TextStyle(color: AppColors.textLight, fontSize: 15))),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: AppColors.primaryMid, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'e.g. My Home',
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.lightGrey)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 28),
                _loading
                    ? const CircularProgressIndicator()
                    : GradientButton(
                    text: 'Create Home', onPressed: _createHome, height: 52),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _mode = 0),
                  child: const Text('← Back',
                      style: TextStyle(color: AppColors.textLight)),
                ),
              ],

              // ── Mode 2: Join by Home ID
              if (_mode == 2) ...[
                const Align(alignment: Alignment.centerLeft,
                    child: Text('Enter Home ID',
                        style: TextStyle(color: AppColors.textLight, fontSize: 15))),
                const SizedBox(height: 6),
                TextField(
                  controller: _idCtrl,
                  style: const TextStyle(color: AppColors.primaryMid, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Paste the Home ID here',
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.lightGrey)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 28),
                _loading
                    ? const CircularProgressIndicator()
                    : GradientButton(
                    text: 'Join Home', onPressed: _joinHome, height: 52),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _mode = 0),
                  child: const Text('← Back',
                      style: TextStyle(color: AppColors.textLight)),
                ),
              ],

              // ── Mode 3: Enter invite token manually
              if (_mode == 3) ...[
                const Align(alignment: Alignment.centerLeft,
                    child: Text('Enter Invite Code',
                        style: TextStyle(color: AppColors.textLight, fontSize: 15))),
                const SizedBox(height: 6),
                TextField(
                  controller: _tokenCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                      color: AppColors.primaryMid,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4),
                  decoration: const InputDecoration(
                    hintText: 'XXXXXXXX',
                    hintStyle: TextStyle(letterSpacing: 2, color: AppColors.grey),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.lightGrey)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Enter the 8-character code shared by the home owner.',
                    style: TextStyle(color: AppColors.textLight,
                        fontSize: 11, fontStyle: FontStyle.italic)),
                const SizedBox(height: 28),
                _loading
                    ? const CircularProgressIndicator()
                    : GradientButton(
                  text: 'Join Home',
                  onPressed: () => _redeemToken(_tokenCtrl.text.trim()),
                  height: 52,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _mode = 0),
                  child: const Text('← Back',
                      style: TextStyle(color: AppColors.textLight)),
                ),
              ],

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
