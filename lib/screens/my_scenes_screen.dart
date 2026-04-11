import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_constants.dart';
import '../models/app_store.dart';

class MyScenesScreen extends StatefulWidget {
  const MyScenesScreen({super.key});
  @override
  State<MyScenesScreen> createState() => _MyScenesScreenState();
}

class _MyScenesScreenState extends State<MyScenesScreen> {
  final _store = AppStore.instance;
  final Map<String, int> _countdowns = {};
  final Map<String, Timer> _countdownTimers = {};

  @override
  void dispose() {
    for (final t in _countdownTimers.values) t.cancel();
    super.dispose();
  }

  void _startCountdown(SceneItem scene) {
    if (scene.timerMinutes <= 0) return;
    _countdownTimers[scene.name]?.cancel();
    _countdowns[scene.name] = scene.timerMinutes * 60;
    _countdownTimers[scene.name] = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        final remaining = (_countdowns[scene.name] ?? 0) - 1;
        if (remaining <= 0) {
          _countdowns.remove(scene.name);
          _countdownTimers[scene.name]?.cancel();
          _countdownTimers.remove(scene.name);
        } else {
          _countdowns[scene.name] = remaining;
        }
      });
    });
  }

  void _stopCountdown(String sceneName) {
    _countdownTimers[sceneName]?.cancel();
    _countdownTimers.remove(sceneName);
    _countdowns.remove(sceneName);
  }

  String _formatCountdown(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SceneItem>>(
      valueListenable: _store.scenes,
      builder: (context, scenes, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _miniBtn(Icons.home_outlined, AppColors.primaryDark, () => Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false)),
                  _miniBtn(Icons.grid_view_rounded, AppColors.primaryDark, () => Navigator.pushNamed(context, '/my-channels')),
                  _miniBtn(Icons.power_outlined, AppColors.primaryDark, () => Navigator.pushNamed(context, '/my-devices')),
                  _miniBtn(Icons.nightlight_round, AppColors.primary, () {}),
                  _miniBtn(Icons.people_outline, AppColors.primaryDark, () => Navigator.pushNamed(context, '/users')),
                ],
              ),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                // AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primaryDark, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.nightlight_round, color: AppColors.primaryDark, size: 20),
                          SizedBox(width: 6),
                          Text('My Scenes', style: TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                      const Padding(padding: EdgeInsets.only(right: 8), child: ProfileAvatar()),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.primaryMid,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 4))],
                          ),
                          child: Row(children: [
                            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('My Scenes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                              SizedBox(height: 4),
                              Text('Manage your home scenes', style: TextStyle(color: Colors.white, fontSize: 13)),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              const Text('Total Scenes', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text('${scenes.length}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                            ]),
                          ]),
                        ),
                        const SizedBox(height: 20),

                        // Section header
                        Row(children: [
                          const Row(children: [
                            Icon(Icons.nightlight_round, color: AppColors.primaryDark, size: 18),
                            SizedBox(width: 6),
                            Text('My Scenes', style: TextStyle(color: AppColors.primaryDark, fontSize: 16, fontWeight: FontWeight.w700)),
                          ]),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/manage-scene'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.add, color: AppColors.primary, size: 16),
                            label: const Text('Add Scene', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        const Text('List of all scenes in my home',
                            style: TextStyle(color: AppColors.textLight, fontSize: 12, fontStyle: FontStyle.italic)),
                        const SizedBox(height: 14),

                        if (scenes.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 40),
                              child: Text('No scenes yet. Create one!',
                                  style: TextStyle(color: AppColors.textLight, fontSize: 13)),
                            ),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 1.1),
                            itemCount: scenes.length,
                            itemBuilder: (_, i) => _sceneCard(scenes[i], i),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sceneCard(SceneItem scene, int idx) {
    final Color c = scene.isOn ? AppColors.green : AppColors.grey;
    final countdown = _countdowns[scene.name];
    final hasCountdown = countdown != null && countdown > 0;

    return GestureDetector(
      onTap: () async {
        await _store.toggleScene(idx);
        final updated = _store.scenes.value[idx];
        if (updated.isOn && updated.timerMinutes > 0) {
          _startCountdown(updated);
        } else {
          _stopCountdown(scene.name);
        }
      },
      onLongPress: () => _showSceneOptions(scene, idx),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFECEBFF),
            borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.nightlight_round, color: AppColors.primaryMid, size: 18),
            const Spacer(),
            PowerButton(
              isOn: scene.isOn,
              size: 32,
              onTap: () async {
                await _store.toggleScene(idx);
                final updated = _store.scenes.value[idx];
                if (updated.isOn && updated.timerMinutes > 0) {
                  _startCountdown(updated);
                } else {
                  _stopCountdown(scene.name);
                }
              },
            ),
          ]),
          const SizedBox(height: 6),
          Text(scene.name,
              style: const TextStyle(
                  color: AppColors.primaryMid, fontSize: 13,
                  fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(
            scene.timerMinutes > 0
                ? '${scene.timerMinutes} min timer'
                : scene.hasSchedule
                    ? 'Scheduled'
                    : '${scene.deviceCount} device${scene.deviceCount == 1 ? '' : 's'}',
            style: const TextStyle(
                color: AppColors.orange, fontSize: 11,
                fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (hasCountdown)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.orange, width: 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.timer, size: 10, color: AppColors.orange),
                const SizedBox(width: 4),
                Text(_formatCountdown(countdown),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                        color: AppColors.orange, fontFamily: 'monospace')),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: c.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c, width: 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.power_settings_new, size: 10, color: c),
                const SizedBox(width: 4),
                Text(scene.isOn ? 'ON' : 'OFF',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c)),
              ]),
            ),
        ]),
      ),
    );
  }

  void _showSceneOptions(SceneItem scene, int idx) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.lightGrey, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          _sheetItem('Manage the scene', () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/manage-scene', arguments: scene.name);
          }),
          _sheetItem('Delete scene', () async {
            Navigator.pop(context);
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Scene'),
                content: Text('Delete "${scene.name}"?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete', style: TextStyle(color: AppColors.red))),
                ],
              ),
            );
            if (ok == true) {
              _stopCountdown(scene.name);
              await _store.deleteScene(scene.name);
            }
          }, isDestructive: true),
          _sheetItem('Cancel', () => Navigator.pop(context)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sheetItem(String label, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      title: Text(label, style: TextStyle(color: isDestructive ? AppColors.red : AppColors.primary, fontSize: 15)),
      onTap: onTap,
    );
  }

  Widget _miniBtn(IconData icon, Color color, VoidCallback onTap) {
    final isActive = color == AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }
}
