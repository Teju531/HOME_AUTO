import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/app_store.dart';

class BleControlService {
  BleControlService._();
  static final BleControlService instance = BleControlService._();

  static const String _serviceShort = '33ff';
  static const String _charShort    = '11ff';

  BluetoothDevice?        _device;
  BluetoothCharacteristic? _char;
  StreamSubscription?     _connSub;

  // Track plug states per channel for building the 4-digit command
  final Map<String, List<bool>> _plugStates = {};

  bool get isConnected =>
      _device != null &&
      _char != null &&
      (_device!.isConnected);

  String? get connectedDeviceName => _device?.platformName;

  // ── Connect to a BLE device and find the control characteristic ───────────
  Future<bool> connect(BluetoothDevice device) async {
    await disconnect();
    try {
      await device.connect(timeout: const Duration(seconds: 15));
      final services = await device.discoverServices();

      BluetoothCharacteristic? found;

      // Try to find characteristic by short UUID
      for (final svc in services) {
        if (svc.serviceUuid.toString().toLowerCase()
            .replaceAll('-', '').contains(_serviceShort)) {
          for (final c in svc.characteristics) {
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
        for (final svc in services) {
          for (final c in svc.characteristics) {
            if (c.properties.write || c.properties.writeWithoutResponse) {
              found = c;
              break;
            }
          }
          if (found != null) break;
        }
      }

      if (found == null) return false;

      _device = device;
      _char   = found;

      // Listen for disconnection
      _connSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _device = null;
          _char   = null;
          debugPrint('BLE control device disconnected');
        }
      });

      debugPrint('BLE control connected to ${device.platformName}');
      return true;
    } catch (e) {
      debugPrint('BLE control connect failed: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    _connSub?.cancel();
    _connSub = null;
    try { await _device?.disconnect(); } catch (_) {}
    _device = null;
    _char   = null;
  }

  // Initialize plug states from known device states (call after connect)
  void syncPlugStates(String channelName, List<DeviceItem> devices) {
    final states = List<bool>.filled(4, false);
    for (final d in devices) {
      final idx = _plugIndex(d.plug);
      if (idx >= 0 && idx < 4) states[idx] = d.isOn;
    }
    _plugStates[channelName] = states;
    debugPrint('BLE plugStates synced for $channelName: $states');
  }

  // ── Send plug command — builds *XXXX# string ──────────────────────────────
  Future<bool> sendPlugCommand(String channelName, String plug, bool isOn) async {
    if (!isConnected) return false;
    final cmd = _buildCommand(channelName, plug, isOn);
    return _write(cmd);
  }

  Future<bool> sendChannelCommand(String channelName, bool isOn) async {
    if (!isConnected) return false;
    final states = List<bool>.filled(4, isOn);
    _plugStates[channelName] = states;
    final cmd = '*${states.map((s) => s ? "1" : "0").join()}#';
    return _write(cmd);
  }

  String _buildCommand(String channelName, String plug, bool isOn) {
    final states = _plugStates[channelName] ?? [false, false, false, false];
    final idx = _plugIndex(plug);
    if (idx >= 0 && idx < 4) states[idx] = isOn;
    _plugStates[channelName] = states;
    return '*${states.map((s) => s ? "1" : "0").join()}#';
  }

  int _plugIndex(String plug) {
    final match = RegExp(r'\d+').firstMatch(plug);
    if (match == null) return 0;
    return (int.tryParse(match.group(0) ?? '1') ?? 1) - 1;
  }

  Future<bool> _write(String data) async {
    final char = _char;
    if (char == null) return false;
    try {
      final bytes = utf8.encode(data);
      if (char.properties.write) {
        await char.write(bytes, withoutResponse: false, allowLongWrite: true);
      } else if (char.properties.writeWithoutResponse) {
        await char.write(bytes, withoutResponse: true);
      } else {
        return false;
      }
      debugPrint('BLE >> $data');
      return true;
    } catch (e) {
      debugPrint('BLE write failed: $e');
      _device = null;
      _char   = null;
      return false;
    }
  }
}
