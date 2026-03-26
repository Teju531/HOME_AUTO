import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/app_store.dart';

class MyScenesScreen extends StatefulWidget {
  const MyScenesScreen({super.key});
  @override
  State<MyScenesScreen> createState() => _MyScenesScreenState();
}

class _MyScenesScreenState extends State<MyScenesScreen> {
  final _store = AppStore.instance;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SceneItem>>(
      valueListenable: _store.scenes,
      builder: (context, scenes, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    // ── AppBar
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
                          Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications_none, color: AppColors.primaryDark, size: 24),
                                onPressed: () {},
                              ),
                              if (scenes.isNotEmpty)
                                Positioned(
                                  right: 8, top: 8,
                                  child: Container(
                                    width: 16, height: 16,
                                    decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                                    child: Center(child: Text('${scenes.length}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Summary card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.primaryMid,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 4))],
                              ),
                              child: Row(
                                children: [
                                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('Good Morning!', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                                    SizedBox(height: 4),
                                    Text('Nitin', style: TextStyle(color: Colors.white, fontSize: 14)),
                                  ])),
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    const Text('Total Channels', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text('${_store.channels.value.length}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                                  ]),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // ── Section header
                            Row(
                              children: [
                                const Row(children: [
                                  Icon(Icons.nightlight_round, color: AppColors.primaryDark, size: 18),
                                  SizedBox(width: 6),
                                  Text('My Scenes', style: TextStyle(color: AppColors.primaryDark, fontSize: 16, fontWeight: FontWeight.w700)),
                                ]),
                                const Spacer(),
                                OutlinedButton.icon(
                                  onPressed: () => _showAddSceneDialog(),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.add, color: AppColors.primary, size: 16),
                                  label: const Text('Add More Scenes', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                                ),
                              ],
                            ),
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
                                    crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 1.0),
                                itemCount: scenes.length,
                                itemBuilder: (_, i) => _sceneCard(scenes[i], i),
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
                    _navBtn(Icons.nightlight_round, AppColors.primaryDark, () {}),
                    const SizedBox(width: 10),
                    _navBtn(Icons.grid_view_rounded, AppColors.primaryDark, () => Navigator.pushNamed(context, '/my-channels')),
                    const SizedBox(width: 10),
                    _navBtn(Icons.power_outlined, AppColors.primaryDark, () => Navigator.pushNamed(context, '/my-devices')),
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
      },
    );
  }

  Widget _sceneCard(SceneItem scene, int idx) {
    return GestureDetector(
      onLongPress: () => _showSceneOptions(scene, idx),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.nightlight_round, color: AppColors.primaryMid, size: 18),
                const Spacer(),
                // Delete button
                GestureDetector(
                  onTap: () => _showSceneOptions(scene, idx),
                  child: const Icon(Icons.more_vert, color: AppColors.textLight, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(scene.name,
                style: const TextStyle(color: AppColors.primaryDark, fontSize: 14, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text('${scene.deviceCount} Device${scene.deviceCount == 1 ? '' : 's'}${scene.timerMinutes > 0 ? ' • ${scene.timerMinutes}min timer' : ''}',
                style: const TextStyle(color: AppColors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, '/manage-scene', arguments: scene.name),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary, width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 27),
                    ),
                    child: const Text('Manage', style: TextStyle(color: AppColors.primary, fontSize: 10)),
                  ),
                ),
                const SizedBox(width: 6),
                PowerButton(
                  isOn: scene.isOn,
                  size: 32,
                  onTap: () => _store.toggleScene(idx),
                ),
              ],
            ),
          ],
        ),
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
          _sheetItem('Manage the scene', () { Navigator.pop(context); Navigator.pushNamed(context, '/manage-scene', arguments: scene.name); }),
          _sheetItem('Delete scene', () async {
            Navigator.pop(context);
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Scene'),
                content: Text('Delete "${scene.name}"?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                ],
              ),
            );
            if (ok == true) await _store.deleteScene(scene.name);
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

  void _showAddSceneDialog() {
    Navigator.pushNamed(context, '/manage-scene');
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
