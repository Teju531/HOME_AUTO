import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/app_store.dart';

class MyDevicesScreen extends StatefulWidget {
  const MyDevicesScreen({super.key});
  @override
  State<MyDevicesScreen> createState() => _MyDevicesScreenState();
}

class _MyDevicesScreenState extends State<MyDevicesScreen> {
  final _store = AppStore.instance;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ChannelItem>>(
      valueListenable: _store.channels,
      builder: (context, channels, _) {
        final allDevices = _store.allDevices;
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
                              Icon(Icons.power, color: AppColors.primaryDark, size: 20),
                              SizedBox(width: 6),
                              Text('My Devices', style: TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                          IconButton(
                            icon: const Icon(Icons.notifications_none, color: AppColors.primaryDark, size: 24),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 110),
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
                                  const Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('Good Morning!', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                                      SizedBox(height: 4),
                                      Text('Nitin', style: TextStyle(color: Colors.white, fontSize: 14)),
                                    ]),
                                  ),
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    const Text('Total Devices', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text('${allDevices.length}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                                  ]),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // ── Section header
                            const Row(children: [
                              Icon(Icons.power, color: AppColors.primaryDark, size: 18),
                              SizedBox(width: 6),
                              Text('Devices in my home',
                                  style: TextStyle(color: AppColors.primaryDark, fontSize: 16, fontWeight: FontWeight.w700)),
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
                              ...allDevices.asMap().entries.map((e) => _deviceRow(e.value, e.key, channels)),
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
                    const Spacer(),
                    _navBtn(Icons.add, AppColors.red, () => Navigator.pushNamed(context, '/add-device')),
                  ]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _deviceRow(DeviceItem d, int globalIdx, List<ChannelItem> channels) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 4)],
        ),
        child: Row(
          children: [
            Icon(d.icon, color: AppColors.primaryMid, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(d.name,
                      style: const TextStyle(color: AppColors.primaryMid, fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${d.channelName} • ${d.plug}',
                      style: const TextStyle(color: AppColors.textLight, fontSize: 10),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PowerButton(
              isOn: d.isOn,
              size: 36,
              onTap: () {
                final ci = channels.indexWhere((c) => c.name == d.channelName);
                if (ci != -1) {
                  final di = channels[ci].devices.indexWhere(
                      (dev) => dev.name == d.name && dev.plug == d.plug);
                  if (di != -1) _store.toggleDevice(d.channelName, di);
                }
              },
            ),
            // ⋮ options menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textLight, size: 20),
              padding: EdgeInsets.zero,
              onSelected: (value) async {
                if (value == 'rename') {
                  await _renameDevice(d);
                } else if (value == 'delete') {
                  await _deleteDevice(d);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(children: [
                    Icon(Icons.edit, color: AppColors.primary, size: 18),
                    SizedBox(width: 10),
                    Text('Rename', style: TextStyle(color: AppColors.primary)),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, color: AppColors.red, size: 18),
                    SizedBox(width: 10),
                    Text('Delete', style: TextStyle(color: AppColors.red)),
                  ]),
                ),
              ],
            ),
          ],
        ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == d.name) return;
    await _store.renameDevice(d.channelName, d, newName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device renamed')));
  }

  Future<void> _deleteDevice(DeviceItem d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Device'),
        content: Text('Delete "${d.name}" from ${d.channelName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (ok == true) await _store.deleteDevice(d.channelName, d);
  }

  Widget _navBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
