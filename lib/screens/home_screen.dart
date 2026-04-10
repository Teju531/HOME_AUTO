import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_constants.dart';
import '../models/app_store.dart';
import 'add_channel_wifi_screen.dart';
import '../services/firestore_service.dart';
import 'qr_scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _store = AppStore.instance;
  late final Timer _clockTimer;
  late final Timer _bleRefreshTimer;
  DateTime _now = DateTime.now();

  static const String _serviceShort = '33ff';
  static const String _charShort    = '11ff';

  String _btStatus = '';

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _bleRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _store.refreshBleStatus();
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _bleRefreshTimer.cancel();
    super.dispose();
  }

  // -- ADD CHANNEL: Step 1 - Scan QR to get MAC
  Future<void> _startAddChannel() async {
    final camStatus = await Permission.camera.request();
    if (!camStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission required to scan QR.')));
      return;
    }

    if (!mounted) return;

    final qrResult = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );

    if (!mounted || qrResult == null || qrResult.trim().isEmpty) return;

    setState(() => _btStatus = 'Reading QR code...');

    final mac = _extractMac(qrResult.trim());

    if (mac == null) {
      setState(() => _btStatus = '');
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read MAC from QR. Please try again.'),
              backgroundColor: AppColors.red));
      return;
    }

    setState(() => _btStatus = 'QR scanned. Checking device ownership...');

    final homeId = _store.homeId;
    if (homeId != null) {
      final ownerHomeId = await FirestoreService.instance.getDeviceOwnerHomeId(mac);
      if (!mounted) return;

      if (ownerHomeId != null && ownerHomeId != homeId) {
        setState(() => _btStatus = '');
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(children: [
              Icon(Icons.lock, color: AppColors.red, size: 22),
              SizedBox(width: 8),
              Text('Device Already Registered'),
            ]),
            content: const Text(
              'This device is already registered to another account. '
              'Only the original owner can use this device.\n\n'
              'If you believe this is an error, contact the device owner.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    setState(() => _btStatus = 'Enabling Bluetooth...');

    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      try { await FlutterBluePlus.turnOn(); } catch (_) {}
      await Future.delayed(const Duration(seconds: 2));
    }

    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      setState(() => _btStatus = '');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable Bluetooth and try again.')));
      return;
    }

    setState(() => _btStatus = 'Scanning for device $mac...');

    final device = await _findDeviceByMac(mac);

    if (!mounted) return;

    if (device == null) {
      setState(() => _btStatus = '');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Device $mac not found nearby. Make sure it is powered on.'),
              backgroundColor: AppColors.red));
      return;
    }

    await _connectAndGoToWifi(device);
  }

  // -- Scan BLE for up to 10s, return device matching MAC
  Future<BluetoothDevice?> _findDeviceByMac(String mac) async {
    final normalizedTarget = mac.toUpperCase().replaceAll(':', '').replaceAll('-', '');
    BluetoothDevice? found;

    final completer = Completer<BluetoothDevice?>();
    StreamSubscription? sub;

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final deviceMac = r.device.remoteId.str
            .toUpperCase().replaceAll(':', '').replaceAll('-', '');
        if (deviceMac == normalizedTarget) {
          found = r.device;
          if (!completer.isCompleted) completer.complete(r.device);
          break;
        }
      }
    });

    FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && !completer.isCompleted) {
        completer.complete(found);
      }
    });

    final result = await completer.future;
    await sub.cancel();
    await FlutterBluePlus.stopScan();
    return result;
  }

  // -- Connect to device and navigate to WiFi screen
  Future<void> _connectAndGoToWifi(BluetoothDevice device) async {
    setState(() => _btStatus =
        'Connecting to ${device.platformName.isNotEmpty ? device.platformName : device.remoteId}...');

    try {
      await device.connect(timeout: const Duration(seconds: 15));
      final services = await device.discoverServices();

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

      _store.connectBle(device);

      final mac = device.remoteId.str;
      final homeId = _store.homeId;
      if (homeId != null && mac.isNotEmpty) {
        FirestoreService.instance.registerDevice(homeId, mac);
      }

      Navigator.pushNamed(
        context,
        '/add-channel-wifi',
        arguments: AddChannelWifiArgs(device: device, characteristic: found),
      );
    } catch (e) {
      setState(() => _btStatus = '');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e'),
              backgroundColor: Colors.red));
    }
  }

  // -- Reconnect BLE using already-registered MACs (no QR needed)
  Future<void> _connectBleForControl() async {
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      try { await FlutterBluePlus.turnOn(); } catch (_) {}
      await Future.delayed(const Duration(seconds: 2));
    }
    if (!mounted) return;

    final homeId = _store.homeId;
    if (homeId == null) return;

    setState(() => _btStatus = 'Looking up registered devices...');
    final macs = await FirestoreService.instance.getRegisteredMacs(homeId);
    if (!mounted) return;

    if (macs.isEmpty) {
      setState(() => _btStatus = '');
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No registered devices found. Scan QR to add one.')));
      return;
    }

    setState(() => _btStatus = 'Scanning for known devices...');
    final device = await _findAnyRegisteredDevice(macs);
    setState(() => _btStatus = '');
    if (!mounted) return;

    if (device == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No registered devices found nearby.'),
              backgroundColor: AppColors.red));
      return;
    }

    final ok = await _store.connectBle(device);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Connected to ${device.platformName}' : 'Failed to connect'),
      backgroundColor: ok ? AppColors.green : AppColors.red,
    ));
  }

  // -- Scan BLE and return first device matching any registered MAC
  Future<BluetoothDevice?> _findAnyRegisteredDevice(List<String> macs) async {
    final targets = macs
        .map((m) => m.toUpperCase().replaceAll(':', '').replaceAll('-', ''))
        .toSet();
    BluetoothDevice? found;
    final completer = Completer<BluetoothDevice?>();
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final id = r.device.remoteId.str
            .toUpperCase().replaceAll(':', '').replaceAll('-', '');
        if (targets.contains(id)) {
          found = r.device;
          if (!completer.isCompleted) completer.complete(r.device);
          break;
        }
      }
    });
    FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && !completer.isCompleted) completer.complete(found);
    });
    final result = await completer.future;
    await sub.cancel();
    await FlutterBluePlus.stopScan();
    return result;
  }

  // -- Extract MAC from various QR formats
  String? _extractMac(String raw) {
    final macRegex = RegExp(r'([0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2}');
    final match = macRegex.firstMatch(raw);
    if (match != null) return match.group(0)!.toUpperCase();

    final hexRegex = RegExp(r'^[0-9A-Fa-f]{12}$');
    if (hexRegex.hasMatch(raw)) {
      return raw.toUpperCase().replaceAllMapped(
          RegExp(r'.{2}'), (m) => '${m.group(0)}:').trimRight().replaceAll(RegExp(r':$'), '');
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<List<ChannelItem>>(
          valueListenable: _store.channels,
          builder: (context, _, __) {
            final channels = _store.permittedChannels;
            final scenes = _store.scenes.value;

            return Stack(children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Top bar
                    Row(children: [
                      const SizedBox(width: 40),
                      const Expanded(
                        child: Center(
                          child: Text('Home', style: TextStyle(
                              color: AppColors.primaryMid,
                              fontSize: 20, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const ProfileAvatar(),
                      const SizedBox(width: 4),
                    ]),
                    const SizedBox(height: 16),

                    // BLE status banner
                    if (_btStatus.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF08A2A).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF08A2A)),
                        ),
                        child: Row(children: [
                          const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFFF08A2A))),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_btStatus,
                              style: const TextStyle(
                                  color: Color(0xFFF08A2A),
                                  fontSize: 13, fontWeight: FontWeight.w600))),
                        ]),
                      ),
                    ],

                    // Connection mode indicator
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
                              color: bleOn ? AppColors.green : AppColors.primary),
                        ),
                        child: Row(children: [
                          Icon(bleOn ? Icons.bluetooth_connected : Icons.wifi,
                              color: bleOn ? AppColors.green : AppColors.primary,
                              size: 16),
                          const SizedBox(width: 8),
                          Text(
                            bleOn
                                ? 'Local (Bluetooth) - instant control'
                                : 'Remote (WiFi/MQTT) - cloud control',
                            style: TextStyle(
                                color: bleOn ? AppColors.green : AppColors.primary,
                                fontSize: 12, fontWeight: FontWeight.w600),
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

                    // Greeting card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                            Text(_greeting(), style: const TextStyle(
                                color: Colors.white, fontSize: 16,
                                fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(_displayName(), style: const TextStyle(
                                color: Colors.white, fontSize: 14)),
                          ],
                        )),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(_formatDate(_now), style: const TextStyle(
                              color: Colors.white, fontSize: 16,
                              fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(_formatTime(_now), style: const TextStyle(
                              color: Colors.white, fontSize: 14)),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 24),

                    // My Channels
                    _sectionHeader(
                      'My Channels', 'View All',
                      () => Navigator.pushNamed(context, '/my-channels'),
                      icon: Icons.grid_view_rounded,
                    ),
                    const Text('List of existing channels',
                        style: TextStyle(color: AppColors.textLight,
                            fontSize: 12, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 12),

                    if (channels.isEmpty)
                      _emptyState(
                        'No channels yet. Scan the QR on your device to add one.',
                        Icons.qr_code_scanner,
                        'Scan & Add Channel',
                        _startAddChannel,
                      )
                    else
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: channels.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (_, i) => _channelChip(channels[i]),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // My Scenes
                    _sectionHeader(
                      'My Scenes', 'View All',
                      () => Navigator.pushNamed(context, '/my-scenes'),
                      icon: Icons.nightlight_round,
                    ),
                    const SizedBox(height: 12),

                    if (scenes.isEmpty)
                      _emptyState(
                        'No scenes yet. Create a custom scene.',
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
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (_, i) => _sceneChip(scenes[i], i),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/my-scenes'),
                          style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary, width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24)),
                              minimumSize: const Size(double.infinity, 46)),
                          icon: const Icon(Icons.add, color: AppColors.primary, size: 20),
                          label: const Text('Add Scene',
                              style: TextStyle(color: AppColors.primary, fontSize: 14)),
                        ),
                      ]),
                  ],
                ),
              ),
            ]);
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _miniBtn(Icons.nightlight_round, AppColors.primaryDark, () => Navigator.pushNamed(context, '/my-scenes')),
              _miniBtn(Icons.grid_view_rounded, AppColors.primaryDark, () => Navigator.pushNamed(context, '/my-channels')),
              _miniBtn(Icons.qr_code_scanner, AppColors.primaryMid, _startAddChannel),
              _miniBtn(Icons.power_outlined, AppColors.primaryDark, () => Navigator.pushNamed(context, '/my-devices')),
              _miniBtn(Icons.people_outline, AppColors.primaryDark, () => Navigator.pushNamed(context, '/users')),
              _miniBtn(Icons.logout, AppColors.red, () async {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushReplacementNamed(context, '/login');
              }),
            ],
          ),
        ),
      ),
    );
  }

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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact),
          icon: const Icon(Icons.arrow_forward, color: AppColors.textPurple, size: 14),
          label: Text(btnLabel, style: const TextStyle(
              color: AppColors.textPurple, fontSize: 11)),
          iconAlignment: IconAlignment.end,
        ),
    ]);
  }

  Widget _channelChip(ChannelItem ch) {
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
            const Icon(Icons.grid_view_rounded, color: AppColors.primaryMid, size: 18),
            const Spacer(),
            PowerButton(
              isOn: ch.isOn,
              onTap: () async {
                if (ch.devices.isEmpty) return;
                for (var i = 0; i < ch.devices.length; i++) {
                  await _store.toggleDevice(ch.name, i);
                }
              },
              size: 32,
            ),
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

  Widget _sceneChip(SceneItem scene, int idx) {
    final Color c = scene.isOn ? AppColors.green : AppColors.grey;
    return GestureDetector(
      onTap: () => _store.toggleScene(idx),
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
      Center(
        child: Container(
          width: 236,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12070B72),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: OutlinedButton.icon(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.92),
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                minimumSize: const Size(236, 46),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 16),
            ),
            label: Text(btnLabel,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ),
      const SizedBox(height: 8),
    ]);
  }

  Widget _miniBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: color, size: 26),
    );
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

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning!';
    if (h < 17) return 'Good Afternoon!';
    return 'Good Evening!';
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
