import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_constants.dart';
import '../models/app_store.dart';
import '../services/firestore_service.dart';
import 'add_channel_wifi_screen.dart';
import 'qr_scanner_screen.dart';

class AddChannelQRScreen extends StatefulWidget {
  const AddChannelQRScreen({super.key});
  @override
  State<AddChannelQRScreen> createState() => _AddChannelQRScreenState();
}

class _AddChannelQRScreenState extends State<AddChannelQRScreen> {
  final _store = AppStore.instance;
  static const String _serviceShort = '33ff';
  static const String _charShort = '11ff';
  String _status = '';
  bool _loading = false;

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

    setState(() { _status = 'Reading QR code…'; _loading = true; });

    final mac = _extractMac(qrResult.trim());
    if (mac == null) {
      setState(() { _status = ''; _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read MAC from QR. Please try again.'),
              backgroundColor: AppColors.red));
      return;
    }

    setState(() => _status = 'QR scanned. Checking device ownership…');

    final homeId = _store.homeId;
    if (homeId != null) {
      final ownerHomeId = await FirestoreService.instance.getDeviceOwnerHomeId(mac);
      if (!mounted) return;
      if (ownerHomeId != null && ownerHomeId != homeId) {
        setState(() { _status = ''; _loading = false; });
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
                'Only the original owner can use this device.'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
        return;
      }
    }

    setState(() => _status = 'Enabling Bluetooth…');
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      try { await FlutterBluePlus.turnOn(); } catch (_) {}
      await Future.delayed(const Duration(seconds: 2));
    }
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      setState(() { _status = ''; _loading = false; });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable Bluetooth and try again.')));
      return;
    }

    setState(() => _status = 'Scanning for device $mac…');
    final device = await _findDeviceByMac(mac);
    if (!mounted) return;
    if (device == null) {
      setState(() { _status = ''; _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Device $mac not found nearby.'),
              backgroundColor: AppColors.red));
      return;
    }
    await _connectAndGoToWifi(device);
  }

  Future<BluetoothDevice?> _findDeviceByMac(String mac) async {
    final target = mac.toUpperCase().replaceAll(':', '').replaceAll('-', '');
    BluetoothDevice? found;
    final completer = Completer<BluetoothDevice?>();
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final id = r.device.remoteId.str.toUpperCase().replaceAll(':', '').replaceAll('-', '');
        if (id == target) {
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

  Future<void> _connectAndGoToWifi(BluetoothDevice device) async {
    setState(() => _status =
        'Connecting to ${device.platformName.isNotEmpty ? device.platformName : device.remoteId}…');
    try {
      await device.connect(timeout: const Duration(seconds: 15));
      final services = await device.discoverServices();
      BluetoothCharacteristic? found;
      for (var svc in services) {
        if (svc.serviceUuid.toString().toLowerCase().replaceAll('-', '').contains(_serviceShort)) {
          for (var c in svc.characteristics) {
            if (c.characteristicUuid.toString().toLowerCase().replaceAll('-', '').contains(_charShort)) {
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
      setState(() { _status = ''; _loading = false; });
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
      Navigator.pushNamed(context, '/add-channel-wifi',
          arguments: AddChannelWifiArgs(device: device, characteristic: found));
    } catch (e) {
      setState(() { _status = ''; _loading = false; });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e'), backgroundColor: Colors.red));
    }
  }

  String? _extractMac(String raw) {
    final macRegex = RegExp(r'([0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2}');
    final match = macRegex.firstMatch(raw);
    if (match != null) return match.group(0)!.toUpperCase();
    final hexRegex = RegExp(r'^[0-9A-Fa-f]{12}$');
    if (hexRegex.hasMatch(raw)) {
      return raw.toUpperCase()
          .replaceAllMapped(RegExp(r'.{2}'), (m) => '${m.group(0)}:')
          .trimRight()
          .replaceAll(RegExp(r':$'), '');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
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
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.electrical_services, color: AppColors.primaryMid, size: 80),
                    const SizedBox(height: 24),
                    const Text(
                      'Scan the QR code on your device to add a new channel.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textLight, fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 32),
                    if (_loading)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: Row(children: [
                          const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_status,
                              style: const TextStyle(color: AppColors.primary,
                                  fontSize: 13, fontWeight: FontWeight.w600))),
                        ]),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _startAddChannel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 22),
                          label: const Text('Scan QR & Add Channel',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
