import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../models/app_store.dart';
import 'add_channel_wifi_screen.dart';

class ConnectingScreen extends StatefulWidget {
  const ConnectingScreen({super.key});
  @override
  State<ConnectingScreen> createState() => _ConnectingScreenState();
}

class _ConnectingScreenState extends State<ConnectingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  String _channelName = 'Migro_CH1';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final raw = ModalRoute.of(context)?.settings.arguments;
      if (raw is String && raw.trim().isNotEmpty) {
        _channelName = raw.trim();
      } else if (raw is AddChannelWifiArgs) {
        _channelName = raw.device.platformName.isNotEmpty
            ? raw.device.platformName
            : 'Migro_CH1';
      }
      // Short delay to show the connecting animation, then proceed
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        AppStore.instance.addChannel(_channelName);
        Navigator.pushReplacementNamed(context, '/connection-success',
            arguments: _channelName);
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            height: 180, width: 180,
            decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.electrical_services,
                size: 80, color: Color(0xFF888888)),
          ),
          const SizedBox(height: 40),
          RotationTransition(
              turns: _ctrl,
              child: const Icon(Icons.sync, color: AppColors.primary, size: 48)),
          const SizedBox(height: 20),
          const Text('Connecting to Device.',
              style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Please wait…',
              style: TextStyle(color: AppColors.textLight, fontSize: 14)),
        ]),
      ),
    );
  }
}
