import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_constants.dart';
import '../models/app_store.dart';

class MyDevicesScreen extends StatefulWidget {
  const MyDevicesScreen({super.key});
  @override
  State<MyDevicesScreen> createState() => _MyDevicesScreenState();
}

class _MyDevicesScreenState extends State<MyDevicesScreen> {
  final _store = AppStore.instance;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning!';
    if (h < 17) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  String _displayName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }
    final email = user?.email ?? '';
    if (email.isEmpty) return 'User';
    final local = email.split('@').first.trim();
    return local.isEmpty ? 'User' : local[0].toUpperCase() + local.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ChannelItem>>(
      valueListenable: _store.channels,
      builder: (context, _, __) {
        final channels = _store.permittedChannels;
        final allDevices = channels.expand((c) => c.devices).toList();
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
                  _miniBtn(Icons.power_outlined, AppColors.primary, () {}),
                  _miniBtn(Icons.nightlight_round, AppColors.primaryDark, () => Navigator.pushNamed(context, '/my-scenes')),
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
                          Icon(Icons.power, color: AppColors.primaryDark, size: 20),
                          SizedBox(width: 6),
                          Text('My Devices', style: TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w700)),
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
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_greeting(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(_displayName(), style: const TextStyle(color: Colors.white, fontSize: 14)),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              const Text('Total Devices', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text('${allDevices.length}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                            ]),
                          ]),
                        ),
                        const SizedBox(height: 20),

                        // Section header
                        Row(children: [
                          const Icon(Icons.power, color: AppColors.primaryDark, size: 18),
                          const SizedBox(width: 6),
                          const Text('Devices in my home',
                              style: TextStyle(color: AppColors.primaryDark, fontSize: 16, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/add-device'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.textPurple, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.add, color: AppColors.textPurple, size: 16),
                            label: const Text('Add Device', style: TextStyle(color: AppColors.textPurple, fontSize: 12)),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        const Text('List of all electronic devices in my home.',
                            style: TextStyle(color: AppColors.textLight, fontSize: 12, fontStyle: FontStyle.italic)),
                        const SizedBox(height: 14),

                        if (allDevices.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 40),
                              child: Text('No devices yet. Add a device to a channel.',
                                  style: TextStyle(color: AppColors.textLight, fontSize: 13)),
                            ),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: allDevices.length,
                            itemBuilder: (_, i) => _deviceCard(allDevices[i], channels),
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

  Widget _deviceCard(DeviceItem d, List<ChannelItem> channels) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: d.isOn ? const Color(0xFFECEBFF) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: d.isOn ? AppColors.primary : AppColors.lightGrey,
          width: d.isOn ? 1.5 : 1,
        ),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(d.icon, color: d.isOn ? AppColors.primary : AppColors.primaryMid, size: 22),
            const Spacer(),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textLight, size: 18),
              padding: EdgeInsets.zero,
              onSelected: (value) async {
                if (value == 'rename') await _renameDevice(d);
                else if (value == 'delete') await _deleteDevice(d);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'rename', child: Row(children: [
                  Icon(Icons.edit, color: AppColors.primary, size: 16),
                  SizedBox(width: 8),
                  Text('Rename', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                ])),
                const PopupMenuItem(value: 'delete', child: Row(children: [
                  Icon(Icons.delete_outline, color: AppColors.red, size: 16),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: AppColors.red, fontSize: 13)),
                ])),
              ],
            ),
          ]),
          const SizedBox(height: 6),
          Text(d.name,
              style: const TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(d.channelName,
              style: const TextStyle(color: AppColors.textLight, fontSize: 10),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(d.plug,
                style: const TextStyle(color: AppColors.orange, fontSize: 9, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(d.isOn ? 'ON' : 'OFF',
                style: TextStyle(
                    color: d.isOn ? AppColors.green : AppColors.textLight,
                    fontSize: 12, fontWeight: FontWeight.w700)),
            PowerButton(
              isOn: d.isOn,
              size: 34,
              onTap: () {
                final ci = channels.indexWhere((c) => c.name == d.channelName);
                if (ci != -1) {
                  final di = channels[ci].devices.indexWhere(
                      (dev) => dev.name == d.name && dev.plug == d.plug);
                  if (di != -1) _store.toggleDevice(d.channelName, di);
                }
              },
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _renameDevice(DeviceItem d) async {
    final ctrl = TextEditingController(text: d.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Device'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Device name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == d.name) return;
    await _store.renameDevice(d.channelName, d, newName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device renamed')));
  }

  Future<void> _deleteDevice(DeviceItem d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Device'),
        content: Text('Delete "${d.name}" from ${d.channelName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (ok == true) await _store.deleteDevice(d.channelName, d);
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
