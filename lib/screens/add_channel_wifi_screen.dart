import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../constants/app_constants.dart';
import '../models/app_store.dart';

class AddChannelWifiArgs {
  final BluetoothDevice device;
  final BluetoothCharacteristic characteristic;
  final String ssid;
  final String password;

  const AddChannelWifiArgs({
    required this.device,
    required this.characteristic,
    this.ssid = '',
    this.password = '',
  });
}

class AddChannelWifiScreen extends StatefulWidget {
  const AddChannelWifiScreen({super.key});

  @override
  State<AddChannelWifiScreen> createState() => _AddChannelWifiScreenState();
}

class _AddChannelWifiScreenState extends State<AddChannelWifiScreen> {
  static const String _mqttHost = 'test.mosquitto.org';
  static const int    _mqttPort = 1883;
  static const String _mqttRoot = 'iot_home';

  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _isSending = false;
  String _statusText = '';

  BluetoothDevice? _device;
  BluetoothCharacteristic? _cmdChar;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AddChannelWifiArgs) {
      _device = args.device;
      _cmdChar = args.characteristic;
    }
  }

  @override
  void dispose() {
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<bool> _bleWrite(String data) async {
    if (_cmdChar == null || _device == null) return false;
    try {
      final connState = await _device!.connectionState.first;
      if (connState != BluetoothConnectionState.connected) return false;
      final bytes = utf8.encode(data);
      if (_cmdChar!.properties.write) {
        await _cmdChar!.write(bytes, withoutResponse: false, allowLongWrite: true);
      } else if (_cmdChar!.properties.writeWithoutResponse) {
        const chunkSize = 20;
        for (var i = 0; i < bytes.length; i += chunkSize) {
          final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
          await _cmdChar!.write(bytes.sublist(i, end), withoutResponse: true);
          await Future.delayed(const Duration(milliseconds: 40));
        }
      } else {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // Queue: sends all steps one by one in order
  Future<void> _onConnect() async {
    final ssid = _ssidCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (ssid.isEmpty) {
      _showSnack('Please enter your WiFi SSID.', Colors.red);
      return;
    }
    if (pass.isEmpty) {
      _showSnack('Please enter your WiFi password.', Colors.red);
      return;
    }
    if (_device == null || _cmdChar == null) {
      _showSnack('No BLE device connected.', Colors.red);
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnack('Not logged in.', Colors.red);
      return;
    }
    final topicId = AppStore.instance.homeId ?? uid;

    // Build the full queue of BLE commands to send in order
    final queue = [
      ('WiFi SSID',        'SSID:$ssid\r\n'),
      ('WiFi Password',    'PASS:$pass\r\n'),
      ('MQTT Host',        'MQTT_HOST:$_mqttHost\r\n'),
      ('MQTT Port',        'MQTT_PORT:$_mqttPort\r\n'),
      ('MQTT UID',         'MQTT_UID:$topicId\r\n'),
      ('MQTT Root',        'MQTT_ROOT:$_mqttRoot\r\n'),
      ('CMD Channel Topic','MQTT_TOPIC_CMD_CHANNEL:$_mqttRoot/$topicId/cmd/channel\r\n'),
      ('CMD Device Topic', 'MQTT_TOPIC_CMD_DEVICE:$_mqttRoot/$topicId/cmd/device\r\n'),
      ('State Channel',    'MQTT_TOPIC_STATE_CHANNEL:$_mqttRoot/$topicId/state/channel\r\n'),
      ('State Device',     'MQTT_TOPIC_STATE_DEVICE:$_mqttRoot/$topicId/state/device\r\n'),
      ('Telemetry Topic',  'MQTT_TOPIC_TELEMETRY:$_mqttRoot/$topicId/state/telemetry\r\n'),
      ('ACK Topic',        'MQTT_TOPIC_ACK:$_mqttRoot/$topicId/ack\r\n'),
      ('Connect',          'CONNECT\r\n'),
    ];

    setState(() { _isSending = true; _statusText = 'Starting…'; });

    for (final (label, payload) in queue) {
      if (!mounted) return;
      setState(() => _statusText = 'Sending $label…');
      final ok = await _bleWrite(payload);
      if (!ok) {
        setState(() { _isSending = false; _statusText = ''; });
        _showSnack('Failed at: $label. Please try again.', Colors.red);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }

    setState(() { _isSending = false; _statusText = ''; });

    if (!mounted) return;
    final channelName = _device!.platformName.isNotEmpty
        ? _device!.platformName
        : 'Migro_CH1';
    Navigator.pushNamed(context, '/connecting', arguments: channelName);
  }

  @override
  Widget build(BuildContext context) {
    final deviceName = _device?.platformName.isNotEmpty == true
        ? _device!.platformName
        : _device?.remoteId.toString() ?? 'Unknown';

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
                    onPressed: _isSending ? null : () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text('Add Channel', textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  _isSending
                      ? const Padding(
                          padding: EdgeInsets.only(right: 14),
                          child: SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                      : const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Enter your home WiFi credentials and tap Connect.',
                        style: TextStyle(color: AppColors.primary, fontSize: 13,
                            fontStyle: FontStyle.italic, height: 1.4)),
                    const SizedBox(height: 18),
                    _step('Step 1', 'Make sure the Migro module is powered on and in BLE mode.'),
                    _step('Step 2', 'Enter your home WiFi SSID and Password below.'),
                    _step('Step 3', 'Tap CONNECT — the app will send all credentials automatically.'),
                    const SizedBox(height: 20),

                    // BLE device indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade400),
                      ),
                      child: Row(children: [
                        const Icon(Icons.bluetooth_connected, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Text('Module: $deviceName',
                            style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    const SizedBox(height: 24),

                    // SSID field
                    const Text('WiFi SSID',
                        style: TextStyle(color: AppColors.textLight, fontSize: 15, fontWeight: FontWeight.w400)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _ssidCtrl,
                      enabled: !_isSending,
                      style: const TextStyle(color: AppColors.textLight, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'MY_Home_WiFi',
                        hintStyle: TextStyle(color: AppColors.grey),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.lightGrey)),
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Password field
                    const Text('WiFi Password',
                        style: TextStyle(color: AppColors.textLight, fontSize: 15, fontWeight: FontWeight.w400)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      enabled: !_isSending,
                      style: const TextStyle(color: AppColors.textLight, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'MY_Home_WiFi_Password',
                        hintStyle: const TextStyle(color: AppColors.grey),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.lightGrey)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.grey, size: 18),
                          onPressed: () => setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Status text shown while sending
                    if (_isSending && _statusText.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                          const SizedBox(width: 10),
                          Text(_statusText,
                              style: const TextStyle(color: AppColors.primary, fontSize: 13)),
                        ]),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // CONNECT button
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          gradient: LinearGradient(
                            colors: _isSending
                                ? [Colors.grey.shade400, Colors.grey.shade400]
                                : const [Color(0xFF7B84F7), Color(0xFFE46BBE)],
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: _isSending ? null : _onConnect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                          ),
                          child: _isSending
                              ? const SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : const Text('CONNECT',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                        ),
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

  Widget _step(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: AppColors.textLight, fontSize: 13, height: 1.4),
          children: [
            TextSpan(text: '$num: ',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color));
  }
}
