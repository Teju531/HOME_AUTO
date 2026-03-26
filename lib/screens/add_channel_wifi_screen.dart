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
  bool _ssidSent = false;
  bool _passSent = false;

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
    if (_cmdChar == null) {
      _showSnack('BLE characteristic not found on this module.', Colors.red);
      return false;
    }
    if (_device == null) {
      _showSnack('No BLE device connected.', Colors.red);
      return false;
    }

    try {
      final connState = await _device!.connectionState.first;
      if (connState != BluetoothConnectionState.connected) {
        _showSnack('Module disconnected. Reconnect and try again.', Colors.red);
        return false;
      }

      final bytes = utf8.encode(data);
      if (_cmdChar!.properties.write) {
        await _cmdChar!.write(
          bytes,
          withoutResponse: false,
          allowLongWrite: true,
        );
      } else if (_cmdChar!.properties.writeWithoutResponse) {
        const chunkSize = 20;
        for (var i = 0; i < bytes.length; i += chunkSize) {
          final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
          await _cmdChar!.write(bytes.sublist(i, end), withoutResponse: true);
          await Future.delayed(const Duration(milliseconds: 40));
        }
      } else {
        _showSnack('Characteristic does not support write.', Colors.red);
        return false;
      }

      return true;
    } catch (e) {
      _showSnack('Send error: $e', Colors.red);
      return false;
    }
  }

  Future<bool> _sendStep(String stepName, String payload) async {
    final ok = await _bleWrite(payload);
    if (!ok) {
      _showSnack('Failed to send $stepName to module.', Colors.red);
      return false;
    }
    return true;
  }

  Future<void> _sendSsid() async {
    final ssid = _ssidCtrl.text.trim();
    if (ssid.isEmpty) {
      _showSnack('Please enter your WiFi name (SSID).', Colors.red);
      return;
    }

    setState(() => _isSending = true);
    if (!await _sendStep('SSID', 'SSID:$ssid\r\n')) {
      setState(() => _isSending = false);
      return;
    }

    setState(() {
      _isSending = false;
      _ssidSent = true;
      _passSent = false;
    });
    _showSnack('SSID sent to module.', Colors.green);
  }

  Future<void> _sendPassword() async {
    final pass = _passCtrl.text.trim();
    if (!_ssidSent) {
      _showSnack('Send SSID first, then send password.', Colors.orange);
      return;
    }
    if (pass.isEmpty) {
      _showSnack('Please enter your WiFi password.', Colors.red);
      return;
    }

    setState(() => _isSending = true);
    if (!await _sendStep('password', 'PASS:$pass\r\n')) {
      setState(() => _isSending = false);
      return;
    }

    setState(() {
      _isSending = false;
      _passSent = true;
    });
    _showSnack('Password sent to module.', Colors.green);
  }

  Future<void> _sendConnect() async {
    if (!_ssidSent || !_passSent) {
      _showSnack('Send SSID and password first.', Colors.orange);
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

    setState(() => _isSending = true);

    // Send all MQTT config + CONNECT while BLE is still active on this screen
    final mqttSteps = [
      'MQTT_HOST:$_mqttHost\r\n',
      'MQTT_PORT:$_mqttPort\r\n',
      'MQTT_UID:$topicId\r\n',
      'MQTT_ROOT:$_mqttRoot\r\n',
      'MQTT_TOPIC_CMD_CHANNEL:$_mqttRoot/$topicId/cmd/channel\r\n',
      'MQTT_TOPIC_CMD_DEVICE:$_mqttRoot/$topicId/cmd/device\r\n',
      'MQTT_TOPIC_STATE_CHANNEL:$_mqttRoot/$topicId/state/channel\r\n',
      'MQTT_TOPIC_STATE_DEVICE:$_mqttRoot/$topicId/state/device\r\n',
      'MQTT_TOPIC_TELEMETRY:$_mqttRoot/$topicId/state/telemetry\r\n',
      'MQTT_TOPIC_ACK:$_mqttRoot/$topicId/ack\r\n',
      'CONNECT\r\n',
    ];

    for (final step in mqttSteps) {
      final ok = await _sendStep(step.split(':').first, step);
      if (!ok) {
        setState(() => _isSending = false);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }

    setState(() => _isSending = false);

    if (!mounted) return;
    final channelName = _device!.platformName.isNotEmpty
        ? _device!.platformName
        : 'Migro_CH1';
    // Navigate with args so connecting screen knows provisioning is already done
    Navigator.pushNamed(
      context,
      '/connecting',
      arguments: channelName, // just the name — no more BLE writes needed
    );
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
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Add Channel',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  _isSending
                      ? const Padding(
                          padding: EdgeInsets.only(right: 14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
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
                    const Text(
                      'Follow our simple steps to configure the channel',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _step('Step 1', 'Turn Off your smartphone internet data.'),
                    _step('Step 2', 'Go to WiFi settings of your smart phone.'),
                    _step('Step 3', 'Start scanning for available WiFi networks.'),
                    _step('Step 4', 'Find Migro Switch in the WiFi networks list.'),
                    _step('Step 5', 'Connect to Migro Switch.'),
                    _step('Step 6', 'Once connected, come back to the app.'),
                    _step('Step 7', 'Provide SSID and Password of your home WiFi below.'),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade400),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bluetooth_connected, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Module: $deviceName',
                            style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Enter SSID',
                      style: TextStyle(color: AppColors.textLight, fontSize: 15, fontWeight: FontWeight.w400),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _ssidCtrl,
                      style: const TextStyle(color: AppColors.textLight, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'MY_Home_WiFi',
                        hintStyle: const TextStyle(color: AppColors.grey),
                        border: const UnderlineInputBorder(),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.lightGrey)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _isSending ? null : _sendSsid,
                        icon: const Icon(Icons.send, size: 16, color: AppColors.primary),
                        label: const Text(
                          'Send SSID',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary, width: 1.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Enter Password',
                      style: TextStyle(color: AppColors.textLight, fontSize: 15, fontWeight: FontWeight.w400),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      style: const TextStyle(color: AppColors.textLight, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'MY_Home_WiFi_Password',
                        hintStyle: const TextStyle(color: AppColors.grey),
                        border: const UnderlineInputBorder(),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.lightGrey)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePass ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.grey,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _isSending ? null : _sendPassword,
                        icon: const Icon(Icons.send, size: 16, color: AppColors.primary),
                        label: const Text(
                          'Send Password',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary, width: 1.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7B84F7), Color(0xFFE46BBE)],
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: (_isSending || !_ssidSent || !_passSent) ? null : _sendConnect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                          ),
                          child: _isSending
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text(
                                  'CONNECT',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                                ),
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
            TextSpan(
              text: '$num: ',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
            ),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }
}
