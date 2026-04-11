import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

enum MqttInboundType {
  channelState,
  deviceState,
  telemetry,
  ack,
}

class MqttInboundEvent {
  final MqttInboundType type;
  final Map<String, dynamic> payload;
  const MqttInboundEvent({required this.type, required this.payload});
}

class _BrokerConfig {
  final String host;
  final int port;
  final bool useWebSocket;
  const _BrokerConfig(this.host, this.port, {this.useWebSocket = false});
}

class MqttService {
  MqttService._();
  static final MqttService instance = MqttService._();

  static const List<_BrokerConfig> _brokers = [
    _BrokerConfig('test.mosquitto.org', 1883, useWebSocket: false),
    _BrokerConfig('test.mosquitto.org', 8080, useWebSocket: true),
  ];

  static const String _cmdTopic   = 'AWB_SMSW/cmd';
  static const String _stateTopic = 'AWB_SMSW/state';

  final StreamController<MqttInboundEvent> _eventsCtrl =
      StreamController<MqttInboundEvent>.broadcast();

  MqttServerClient? _client;
  String? _uid;
  bool _connecting = false;

  // Track plug states per channel: channelName -> [plug1, plug2, plug3, plug4]
  final Map<String, List<bool>> _plugStates = {};

  Stream<MqttInboundEvent> get events => _eventsCtrl.stream;

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  Future<void> connectForUser(String uid, {String? homeId}) async {
    final topicId = homeId ?? uid;
    if (isConnected && _uid == topicId) return;
    if (_connecting) return;
    _connecting = true;
    await disconnect();

    final safeId = topicId
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '')
        .substring(0, topicId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '').length.clamp(0, 15));
    final clientId = 'fl_${safeId}_${DateTime.now().millisecondsSinceEpoch % 10000}';

    debugPrint('MQTT attempting connect, clientId=$clientId topicId=$topicId');

    for (final broker in _brokers) {
      debugPrint('MQTT trying ${broker.host}:${broker.port} ws=${broker.useWebSocket}');
      final host = broker.useWebSocket ? 'ws://${broker.host}' : broker.host;
      final c = MqttServerClient.withPort(host, clientId, broker.port);
      c.logging(on: false);
      c.useWebSocket = broker.useWebSocket;
      c.keepAlivePeriod = 10;
      c.connectTimeoutPeriod = 8000;
      c.autoReconnect = true;
      c.onDisconnected = _onDisconnected;
      c.onConnected = _onConnected;
      c.onAutoReconnect = () => debugPrint('MQTT auto reconnecting');
      c.onAutoReconnected = () {
        debugPrint('MQTT auto reconnected');
        _subscribeTopics();
      };
      c.connectionMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      try {
        final status = await c.connect();
        debugPrint('MQTT connect status: ${status?.state} returnCode: ${status?.returnCode}');
      } catch (e) {
        debugPrint('MQTT connect exception on ${broker.host}: $e');
        c.disconnect();
        continue;
      }

      if (c.connectionStatus?.state == MqttConnectionState.connected) {
        debugPrint('MQTT connected to ${broker.host}:${broker.port}');
        _uid = topicId;
        _client = c;
        _connecting = false;
        _subscribeTopics();
        c.updates?.listen(_onMessage);
        return;
      }

      debugPrint('MQTT not connected on ${broker.host}, state=${c.connectionStatus?.state}');
      c.disconnect();
    }

    _connecting = false;
    throw Exception('MQTT connection failed on all brokers.');
  }

  Future<void> disconnect() async {
    _connecting = false;
    _client?.disconnect();
    _client = null;
    _uid = null;
  }

  // Build the 4-digit command string for a channel — * prefix required by ESP32
  // e.g. plug 1 ON, rest OFF = "*1000"
  String _buildPlugCommand(String channelName, String plug, bool isOn) {
    final states = _plugStates[channelName] ?? [false, false, false, false];
    final plugIndex = _plugIndex(plug);
    if (plugIndex >= 0 && plugIndex < 4) states[plugIndex] = isOn;
    _plugStates[channelName] = states;
    return '*${states.map((s) => s ? "1" : "0").join()}#';
  }

  // Build command string for entire channel on/off
  String _buildChannelCommand(String channelName, bool isOn) {
    final states = List<bool>.filled(4, isOn);
    _plugStates[channelName] = states;
    return '*${states.map((s) => s ? "1" : "0").join()}#';
  }

  int _plugIndex(String plug) {
    // "Plug 1" -> 0, "Plug 2" -> 1, etc.
    final match = RegExp(r'\d+').firstMatch(plug);
    if (match == null) return 0;
    return (int.tryParse(match.group(0) ?? '1') ?? 1) - 1;
  }

  Future<bool> publishChannelCommand({
    required String channelName,
    required bool isOn,
  }) async {
    if (!await _ensureConnected()) return false;
    final cmd = _buildChannelCommand(channelName, isOn);
    try {
      _publishRaw(_cmdTopic, cmd);
      return true;
    } catch (e) {
      debugPrint('MQTT publish channel failed: $e');
      return false;
    }
  }

  Future<bool> publishDeviceCommand({
    required String channelName,
    required String deviceName,
    required String plug,
    required bool isOn,
  }) async {
    if (!await _ensureConnected()) return false;
    final cmd = _buildPlugCommand(channelName, plug, isOn);
    try {
      _publishRaw(_cmdTopic, cmd);
      return true;
    } catch (e) {
      debugPrint('MQTT publish device failed: $e');
      return false;
    }
  }

  void _subscribeTopics() {
    if (!isConnected) return;
    _client!.subscribe(_stateTopic, MqttQos.atMostOnce);
    debugPrint('MQTT subscribed to $_stateTopic');
  }

  void _publishRaw(String topic, String message) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    _client!.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    debugPrint('MQTT >> $topic : $message');
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final msg in messages) {
      final rec = msg.payload as MqttPublishMessage;
      final raw = MqttPublishPayload.bytesToStringAsString(rec.payload.message).trim();
      debugPrint('MQTT << ${msg.topic} : $raw');

      // Strip * prefix and # suffix if present, then check for 4-digit binary state
      final clean = raw.replaceAll(RegExp(r'^\*|#$'), '');
      if (RegExp(r'^[01]{4}$').hasMatch(clean)) {
        _eventsCtrl.add(MqttInboundEvent(
          type: MqttInboundType.deviceState,
          payload: {
            'plugStates': clean,
            'plug1': clean[0] == '1',
            'plug2': clean[1] == '1',
            'plug3': clean[2] == '1',
            'plug4': clean[3] == '1',
          },
        ));
        return;
      }

      // Also handle JSON responses if ESP32 sends them
      try {
        // ignore: avoid_dynamic_calls
        final decoded = _safeJson(raw);
        if (decoded != null) {
          _eventsCtrl.add(MqttInboundEvent(
            type: MqttInboundType.deviceState,
            payload: decoded,
          ));
        }
      } catch (_) {}
    }
  }

  Map<String, dynamic>? _safeJson(String raw) {
    try {
      final obj = jsonDecode(raw);
      if (obj is Map<String, dynamic>) return obj;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _ensureConnected() async {
    if (isConnected) return true;
    final topicId = _uid;
    if (topicId == null) return false;
    try {
      await connectForUser(topicId).timeout(const Duration(seconds: 5));
      return isConnected;
    } catch (e) {
      debugPrint('MQTT reconnect failed: $e');
      return false;
    }
  }

  void _onConnected() => debugPrint('MQTT connected callback fired');
  void _onDisconnected() => debugPrint('MQTT disconnected, state=${_client?.connectionStatus?.state}');
}
