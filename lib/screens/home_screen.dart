import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../constants/app_constants.dart';
import '../models/app_store.dart';
import 'add_channel_wifi_screen.dart'; // for AddChannelWifiArgs

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _store = AppStore.instance;
  late final Timer _clockTimer;
  DateTime _now = DateTime.now();

  // ── BLE short UUIDs — same pattern as your existing home_screen ─────────────
  static const String _serviceShort = '33ff';
  static const String _charShort    = '11ff';

  String _btStatus = ''; // shown as a status banner while connecting

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // Refresh BLE status every 3 seconds
    Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _store.refreshBleStatus();
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  // ── Connect BLE for direct control only (no WiFi provisioning) ─────────────
  Future<void> _connectBleForControl() async {
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      try { await FlutterBluePlus.turnOn(); } catch (_) {}
      await Future.delayed(const Duration(seconds: 2));
    }
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable Bluetooth.')));
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BleScanSheet(
        onDeviceSelected: (device) async {
          Navigator.pop(context);
          setState(() => _btStatus = 'Connecting to ${device.platformName.isNotEmpty ? device.platformName : device.remoteId}…');
          final ok = await _store.connectBle(device);
          setState(() => _btStatus = '');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok ? 'Connected to ${device.platformName}' : 'Failed to connect'),
            backgroundColor: ok ? AppColors.green : AppColors.red,
          ));
        },
      ),
    );
  }

  // ── STEP 1: Check permissions & BT on, then open scan sheet ─────────────────
  // flutter_blue_plus handles BT permissions internally when startScan() is called
  Future<void> _startAddChannel() async {
    // Turn BT on if off (shows system dialog on Android)
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      try { await FlutterBluePlus.turnOn(); } catch (_) {}
      await Future.delayed(const Duration(seconds: 2));
    }

    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable Bluetooth and try again.')));
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BleScanSheet(
        onDeviceSelected: _connectAndGoToWifi,
      ),
    );
  }

  // ── STEP 2: Connect to selected device, find characteristic ─────────────────
  Future<void> _connectAndGoToWifi(BluetoothDevice device) async {
    Navigator.pop(context); // close scan sheet

    setState(() => _btStatus =
        'Connecting to ${device.platformName.isNotEmpty ? device.platformName : device.remoteId}…');

    try {
      await device.connect(timeout: const Duration(seconds: 15));
      final services = await device.discoverServices();

      // Find characteristic — short UUID match (same as your existing logic)
      BluetoothCharacteristic? found;
      for (var svc in services) {
        if (svc.serviceUuid.toString().toLowerCase()
            .replaceAll('-', '').contains(_serviceShort)) {
          for (var c in svc.characteristics) {
            if (c.characteristicUuid.toString().toLowerCase()
                .replaceAll('-', '').contains(_charShort)) {
              found = c;
              break;
            }
          }
        }
        if (found != null) break;
      }

      // Fallback: first writable characteristic
      if (found == null) {
        for (var svc in services) {
          for (var c in svc.characteristics) {
            if (c.properties.write || c.properties.writeWithoutResponse) {
              found = c;
              break;
            }
          }
          if (found != null) break;
        }
      }

      setState(() => _btStatus = '');

      if (!mounted) return;

      if (found == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Connected but no writable characteristic found.'),
          backgroundColor: Colors.orange,
        ));
        return;
      }

      // ── STEP 3: Register device for direct BLE control + navigate to WiFi screen
      _store.connectBle(device); // non-blocking — registers for direct control
      Navigator.pushNamed(
        context,
        '/add-channel-wifi',
        arguments: AddChannelWifiArgs(
          device: device,
          characteristic: found,
        ),
      );
    } catch (e) {
      setState(() => _btStatus = '');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e'),
              backgroundColor: Colors.red));
    }
  }

  // ── BUILD ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ValueListenableBuilder<List<ChannelItem>>(
          valueListenable: _store.channels,
          builder: (context, channels, _) {
            final allDevices = _store.allDevices;
            final scenes    = _store.scenes.value;

            return Stack(children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Top bar ───────────────────────────────────────────────
                    Row(children: [
                      const Spacer(),
                      const Text('Home', style: TextStyle(
                          color: AppColors.primaryMid,
                          fontSize: 20, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      const Icon(Icons.notifications_none,
                          color: AppColors.primaryMid, size: 26),
                    ]),
                    const SizedBox(height: 16),

                    // ── BLE status banner (shown while connecting) ─────────────
                    if (_btStatus.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF08A2A).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF08A2A)),
                        ),
                        child: Row(children: [
                          const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFF08A2A))),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_btStatus,
                              style: const TextStyle(
                                  color: Color(0xFFF08A2A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600))),
                        ]),
                      ),
                    ],

                    // ── Connection mode indicator ─────────────────────────
                    ValueListenableBuilder<bool>(
                      valueListenable: _store.isBleConnected,
                      builder: (context, bleOn, _) => Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: bleOn
                              ? AppColors.green.withOpacity(0.1)
                              : AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: bleOn ? AppColors.green : AppColors.primary,
                          ),
                        ),
                        child: Row(children: [
                          Icon(
                            bleOn ? Icons.bluetooth_connected : Icons.wifi,
                            color: bleOn ? AppColors.green : AppColors.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            bleOn ? 'Local (Bluetooth) — instant control' : 'Remote (WiFi/MQTT) — cloud control',
                            style: TextStyle(
                              color: bleOn ? AppColors.green : AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (!bleOn)
                            GestureDetector(
                              onTap: _connectBleForControl,
                              child: const Text('Connect BLE',
                                  style: TextStyle(color: AppColors.primary,
                                      fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          if (bleOn)
                            GestureDetector(
                              onTap: () async {
                                await _store.disconnectBle();
                                setState(() {});
                              },
                              child: const Text('Disconnect',
                                  style: TextStyle(color: AppColors.red,
                                      fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                        ]),
                      ),
                    ),

                    // ── Greeting card ─────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMid,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 8, offset: Offset(0, 4))],
                      ),
                      child: Row(children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Good Morning!', style: TextStyle(
                                color: Colors.white, fontSize: 16,
                                fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(_displayNameFromEmail(),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14)),
                          ],
                        )),
                        Column(crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_formatDate(_now), style: const TextStyle(
                                color: Colors.white, fontSize: 16,
                                fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(_formatTime(_now), style: const TextStyle(
                                color: Colors.white, fontSize: 14)),
                          ],
                        ),
                      ]),
                    ),
                    const SizedBox(height: 24),

                    // ── My Channels ───────────────────────────────────────────
                    _sectionHeader(
                      'My Channels', 'View All Channels',
                      () => Navigator.pushNamed(context, '/my-channels'),
                      icon: Icons.grid_view_rounded,
                    ),
                    const Text('List of existing channels',
                        style: TextStyle(color: AppColors.textLight,
                            fontSize: 12, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 12),

                    if (channels.isEmpty)
                      // ── Empty state: "Add Channels" → triggers BLE scan ─────
                      _emptyState(
                        'There are no channels yet, please add a channel & configure it.',
                        Icons.add_box_outlined,
                        'Add Channels',
                        _startAddChannel, // ← BLE scan starts here
                      )
                    else
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: channels.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (_, i) => _channelChip(channels[i], i),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // ── My Devices ────────────────────────────────────────────
                    _sectionHeader(
                      'My Devices', 'View All Devices',
                      () => Navigator.pushNamed(context, '/my-devices'),
                      icon: Icons.power_outlined,
                    ),
                    const Text('List of my electronic devices',
                        style: TextStyle(color: AppColors.textLight,
                            fontSize: 12, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 12),

                    if (allDevices.isEmpty)
                      _emptyState(
                        'There are No devices added yet, please add a device to the channel.',
                        Icons.devices_other,
                        'Add Devices',
                        () => Navigator.pushNamed(context, '/add-device'),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.3),
                        itemCount: allDevices.length > 4 ? 4 : allDevices.length,
                        itemBuilder: (_, i) => _deviceCard(allDevices[i], i),
                      ),
                    const SizedBox(height: 24),

                    // ── My Scenes ─────────────────────────────────────────────
                    _sectionHeader('My Scenes', null, null,
                        icon: Icons.nightlight_round),
                    const SizedBox(height: 12),

                    if (scenes.isEmpty)
                      _emptyState(
                        'There are no scenes added yet, you can create your custom scene.',
                        Icons.wb_twilight,
                        'Add Scene',
                        () => Navigator.pushNamed(context, '/my-scenes'),
                      )
                    else
                      Column(children: [
                        SizedBox(
                          height: 88,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: scenes.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (_, i) => _sceneChip(scenes[i], i),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/my-scenes'),
                          style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.primary, width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24)),
                              minimumSize:
                                  const Size(double.infinity, 46)),
                          icon: const Icon(Icons.add,
                              color: AppColors.primary, size: 20),
                          label: const Text('Add Scene',
                              style: TextStyle(
                                  color: AppColors.primary, fontSize: 14)),
                        ),
                      ]),
                  ],
                ),
              ),

              // ── Bottom nav (unchanged) ──────────────────────────────────────
              Positioned(
                left: 16, right: 16, bottom: 14,
                child: Row(children: [
                  _navBtn(Icons.nightlight_round, AppColors.primaryDark,
                      () => Navigator.pushNamed(context, '/my-scenes')),
                  const SizedBox(width: 10),
                  _navBtn(Icons.grid_view_rounded, AppColors.primaryDark,
                      () => Navigator.pushNamed(context, '/my-channels')),
                  const SizedBox(width: 10),
                  _navBtn(Icons.power_outlined, AppColors.primaryDark,
                      () => Navigator.pushNamed(context, '/my-devices')),
                  const SizedBox(width: 10),
                  _navBtn(Icons.people_outline, AppColors.primaryDark,
                      () => Navigator.pushNamed(context, '/users')),
                  const Spacer(),
                  // ── Add Channel shortcut in nav bar ─────────────────────────
                  GestureDetector(
                    onTap: _startAddChannel,
                    child: Container(
                      width: 46, height: 46,
                      decoration: const BoxDecoration(
                          color: Color(0xFF4B4FA3), shape: BoxShape.circle),
                      child: const Icon(Icons.add, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _navBtn(Icons.logout, AppColors.red, () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushReplacementNamed(context, '/login');
                  }),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }

  // ── Helpers (all unchanged from your original) ────────────────────────────
  Widget _sectionHeader(String title, String? btnLabel, VoidCallback? onBtnTap,
      {required IconData icon}) {
    return Row(children: [
      Icon(icon, color: AppColors.primaryDark, size: 18),
      const SizedBox(width: 6),
      Text(title, style: const TextStyle(color: AppColors.primaryDark,
          fontSize: 17, fontWeight: FontWeight.w700)),
      const Spacer(),
      if (btnLabel != null && onBtnTap != null)
        OutlinedButton.icon(
          onPressed: onBtnTap,
          style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.textPurple, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact),
          icon: const Icon(Icons.arrow_forward,
              color: AppColors.textPurple, size: 14),
          label: Text(btnLabel, style: const TextStyle(
              color: AppColors.textPurple, fontSize: 11)),
          iconAlignment: IconAlignment.end,
        ),
    ]);
  }

  Widget _channelChip(ChannelItem ch, int idx) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/channel-home'),
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFECEBFF),
            borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.grid_view_rounded,
                color: AppColors.primaryMid, size: 18),
            const Spacer(),
            PowerButton(
                isOn: ch.isOn,
                onTap: () async {
                  // Only toggle devices that actually exist in this channel
                  if (ch.devices.isEmpty) return;
                  final newState = !ch.isOn;
                  for (var i = 0; i < ch.devices.length; i++) {
                    await _store.toggleDevice(ch.name, i);
                  }
                },
                size: 32),
          ]),
          const SizedBox(height: 6),
          Text(ch.name, style: const TextStyle(
              color: AppColors.primaryMid, fontSize: 13,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(ch.devicesLabel, style: const TextStyle(
              color: AppColors.orange, fontSize: 11,
              fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _deviceCard(DeviceItem device, int i) {
    return GestureDetector(
      onTap: () {
        final ci = _store.channels.value
            .indexWhere((c) => c.name == device.channelName);
        if (ci != -1) {
          final di = _store.channels.value[ci].devices.indexWhere(
              (d) => d.name == device.name && d.plug == device.plug);
          if (di != -1) _store.toggleDevice(device.channelName, di);
        }
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(
                color: Color(0x14000000),
                blurRadius: 6, offset: Offset(0, 2))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Icon(device.icon, color: AppColors.primaryMid, size: 20),
              const Spacer(),
              PowerButton(
                  isOn: device.isOn,
                  onTap: () {
                    final ci = _store.channels.value
                        .indexWhere((c) => c.name == device.channelName);
                    if (ci != -1) {
                      final di = _store.channels.value[ci].devices.indexWhere(
                          (d) => d.name == device.name && d.plug == device.plug);
                      if (di != -1)
                        _store.toggleDevice(device.channelName, di);
                    }
                    setState(() {});
                  },
                  size: 34),
            ]),
            const SizedBox(height: 5),
            Text(device.name, style: const TextStyle(
                color: AppColors.primaryMid, fontSize: 12,
                fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis, maxLines: 1),
            Text(device.channelName, style: const TextStyle(
                color: AppColors.textLight, fontSize: 10),
                overflow: TextOverflow.ellipsis, maxLines: 1),
            const SizedBox(height: 3),
            PlugTag(device.plug),
          ],
        ),
      ),
    );
  }

  Widget _sceneChip(SceneItem scene, int idx) {
    final Color c = scene.isOn ? AppColors.green : AppColors.grey;
    return GestureDetector(
      onTap: () { _store.toggleScene(idx); setState(() {}); },
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: scene.isOn
                ? const Color(0xFFECEBFF) : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: Colors.white,
                  border: Border.all(color: c, width: 2)),
              child: Icon(Icons.power_settings_new, color: c, size: 20)),
          const SizedBox(height: 4),
          Text(scene.name, style: const TextStyle(
              color: AppColors.primaryMid, fontSize: 10,
              fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _emptyState(String text, IconData icon,
      String btnLabel, VoidCallback onTap) {
    return Column(children: [
      const SizedBox(height: 8),
      Text(text, textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textLight,
              fontSize: 13, height: 1.4)),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            minimumSize: const Size(180, 44)),
        icon: const Icon(Icons.add, color: AppColors.primary, size: 18),
        label: Text(btnLabel,
            style: const TextStyle(color: AppColors.primary, fontSize: 14)),
      ),
      const SizedBox(height: 8),
    ]);
  }

  Widget _navBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
          width: 46, height: 46,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 22)),
    );
  }

  String _displayNameFromEmail() {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.trim().isEmpty) return 'User';
    final localPart = email.split('@').first.trim();
    if (localPart.isEmpty) return 'User';
    return localPart[0].toUpperCase() + localPart.substring(1);
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  BLE Scan Sheet
// ═════════════════════════════════════════════════════════════════════════════
class _BleScanSheet extends StatefulWidget {
  final Function(BluetoothDevice) onDeviceSelected;
  const _BleScanSheet({required this.onDeviceSelected});
  @override
  State<_BleScanSheet> createState() => _BleScanSheetState();
}

class _BleScanSheetState extends State<_BleScanSheet> {
  final List<ScanResult> _results = [];
  StreamSubscription<List<ScanResult>>? _sub;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() { _scanning = true; _results.clear(); });
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    _sub = FlutterBluePlus.scanResults.listen((r) {
      if (mounted) setState(() { _results..clear()..addAll(r); });
    });
    FlutterBluePlus.isScanning.listen((s) {
      if (!s && mounted) setState(() => _scanning = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show all devices (named ones first)
    final named   = _results.where((r) => r.device.platformName.isNotEmpty).toList();
    final unnamed = _results.where((r) => r.device.platformName.isEmpty).toList();
    final visible = [...named, ...unnamed];

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2F2),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCCCCCC),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            const Icon(Icons.bluetooth_searching,
                color: Color(0xFF4B4FA3), size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Connect to Module',
                  style: TextStyle(color: Color(0xFF0A0F66),
                      fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            _scanning
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF4B4FA3)))
                : GestureDetector(
                    onTap: _startScan,
                    child: const Icon(Icons.refresh, color: Color(0xFF4B4FA3))),
          ]),
        ),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Select your Migro module from the list below.',
            style: TextStyle(color: Color(0xFF888888),
                fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: visible.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.bluetooth_searching,
                      color: Color(0xFFCFD0E6), size: 52),
                  const SizedBox(height: 12),
                  Text(_scanning ? 'Scanning for modules…' : 'No devices found. Tap ↻ to retry.',
                      style: const TextStyle(
                          color: Color(0xFF888888), fontSize: 14)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: visible.length,
                  itemBuilder: (_, i) {
                    final r    = visible[i];
                    final name = r.device.platformName.isNotEmpty
                        ? r.device.platformName
                        : 'Unknown (${r.device.remoteId.str.substring(0, 8)})';
                    final rssi = r.rssi;
                    final rssiColor = rssi > -60 ? Colors.green
                        : rssi > -75 ? Colors.orange : Colors.red;
                    final sigIcon  = rssi > -60 ? Icons.signal_wifi_4_bar
                        : rssi > -75 ? Icons.network_wifi_3_bar
                        : Icons.network_wifi_1_bar;
                    return GestureDetector(
                      onTap: () => widget.onDeviceSelected(r.device),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 6, offset: Offset(0, 2))],
                        ),
                        child: Row(children: [
                          const Icon(Icons.bluetooth,
                              color: Color(0xFF4B4FA3), size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(
                                  color: Color(0xFF0A0F66),
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                              Text(r.device.remoteId.str,
                                  style: const TextStyle(
                                      color: Color(0xFF888888), fontSize: 11)),
                            ],
                          )),
                          Icon(sigIcon, color: rssiColor, size: 16),
                          const SizedBox(width: 4),
                          Text('$rssi dBm',
                              style: TextStyle(
                                  fontSize: 10, color: rssiColor)),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right,
                              color: Color(0xFF6C74F3), size: 20),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}