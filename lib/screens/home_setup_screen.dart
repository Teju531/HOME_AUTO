import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';
import '../models/app_store.dart';

class HomeSetupScreen extends StatefulWidget {
  const HomeSetupScreen({super.key});
  @override
  State<HomeSetupScreen> createState() => _HomeSetupScreenState();
}

class _HomeSetupScreenState extends State<HomeSetupScreen> {
  final _nameCtrl = TextEditingController(text: 'My Home');
  final _idCtrl   = TextEditingController();
  bool _loading = false;
  // 0 = choose, 1 = create, 2 = join
  int _mode = 0;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _createHome() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    final homeId = await AppStore.instance.createHome(name);
    if (!mounted) return;
    setState(() => _loading = false);
    if (homeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create home. Try again.'), backgroundColor: Colors.red),
      );
      return;
    }
    // Show the homeId so the user can share it with family members
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Home Created!', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Share this Home ID with your family members so they can join:', style: TextStyle(color: AppColors.textLight, fontSize: 13)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFECEBFF), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Expanded(child: Text(homeId, style: const TextStyle(color: AppColors.primaryMid, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
              IconButton(
                icon: const Icon(Icons.copy, color: AppColors.primary, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: homeId));
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Home ID copied!')));
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

  Future<void> _joinHome() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) return;
    setState(() => _loading = true);
    final ok = await AppStore.instance.joinHome(id);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Home ID not found. Check and try again.'), backgroundColor: Colors.red),
      );
      return;
    }
    await AppStore.instance.loadFromFirestore();
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
              const Text('Set Up Your Home', style: TextStyle(color: AppColors.primaryDark, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Create a new home or join an existing one to share control with your family.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textLight, fontSize: 14, height: 1.4)),
              const SizedBox(height: 40),

              if (_mode == 0) ...[
                GradientButton(text: 'Create a New Home', onPressed: () => setState(() => _mode = 1), height: 52),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => setState(() => _mode = 2),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: const Text('Join an Existing Home', style: TextStyle(color: AppColors.primary, fontSize: 16)),
                ),
              ],

              if (_mode == 1) ...[
                const Align(alignment: Alignment.centerLeft, child: Text('Home Name', style: TextStyle(color: AppColors.textLight, fontSize: 15))),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: AppColors.primaryMid, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'e.g. My Home',
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.lightGrey)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 28),
                _loading
                    ? const CircularProgressIndicator()
                    : GradientButton(text: 'Create Home', onPressed: _createHome, height: 52),
                const SizedBox(height: 12),
                TextButton(onPressed: () => setState(() => _mode = 0), child: const Text('← Back', style: TextStyle(color: AppColors.textLight))),
              ],

              if (_mode == 2) ...[
                const Align(alignment: Alignment.centerLeft, child: Text('Enter Home ID', style: TextStyle(color: AppColors.textLight, fontSize: 15))),
                const SizedBox(height: 6),
                TextField(
                  controller: _idCtrl,
                  style: const TextStyle(color: AppColors.primaryMid, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Paste the Home ID here',
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.lightGrey)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 28),
                _loading
                    ? const CircularProgressIndicator()
                    : GradientButton(text: 'Join Home', onPressed: _joinHome, height: 52),
                const SizedBox(height: 12),
                TextButton(onPressed: () => setState(() => _mode = 0), child: const Text('← Back', style: TextStyle(color: AppColors.textLight))),
              ],

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
