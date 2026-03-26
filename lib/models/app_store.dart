import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/mqtt_service.dart';

// ─── Device Model ──────────────────────────────────────────────────────────────
class DeviceItem {
  final String name;
  final String channelName;
  final String plug;
  final IconData icon;
  bool isOn;

  DeviceItem({
    required this.name,
    required this.channelName,
    required this.plug,
    required this.icon,
    this.isOn = false,
  });

  DeviceItem copyWith({String? name, String? channelName, String? plug, IconData? icon, bool? isOn}) {
    return DeviceItem(
      name: name ?? this.name,
      channelName: channelName ?? this.channelName,
      plug: plug ?? this.plug,
      icon: icon ?? this.icon,
      isOn: isOn ?? this.isOn,
    );
  }
}

// ─── Channel Model ─────────────────────────────────────────────────────────────
class ChannelItem {
  final String name;
  final String room;
  final int totalPlugs;
  bool isOn;
  List<DeviceItem> devices;

  ChannelItem({
    required this.name,
    this.room = '',
    this.totalPlugs = 4,
    this.isOn = true,
    List<DeviceItem>? devices,
  }) : devices = devices ?? [];

  int get activeDevices => devices.where((d) => d.isOn).length;
  String get devicesLabel => '${devices.length}/$totalPlugs Devices';

  ChannelItem copyWith({String? name, String? room, bool? isOn, List<DeviceItem>? devices}) {
    return ChannelItem(
      name: name ?? this.name,
      room: room ?? this.room,
      totalPlugs: totalPlugs,
      isOn: isOn ?? this.isOn,
      devices: devices ?? this.devices,
    );
  }
}

// ─── Scene Model ───────────────────────────────────────────────────────────────
class SceneItem {
  final String name;
  final int deviceCount;
  bool isOn;
  final IconData icon;

  SceneItem({
    required this.name,
    this.deviceCount = 0,
    this.isOn = false,
    this.icon = Icons.nightlight_round,
  });
}

// ─── Member Model ──────────────────────────────────────────────────────────────
class MemberItem {
  final String name;
  final String? avatarPath;
  const MemberItem({required this.name, this.avatarPath});
}

// ─── App Store (singleton) ────────────────────────────────────────────────────
class AppStore {
  AppStore._() {
    _mqtt.events.listen(_handleMqttEvent);
  }
  static final AppStore instance = AppStore._();

  final _fs = FirestoreService.instance;
  final _mqtt = MqttService.instance;

  // ── homeId — shared across all members of the same home ───────────────────
  String? homeId;

  // ── ValueNotifiers (UI listens to these) ──────────────────────────────────
  final ValueNotifier<List<ChannelItem>> channels = ValueNotifier([]);
  final ValueNotifier<List<SceneItem>>   scenes   = ValueNotifier([]);
  final ValueNotifier<bool> isLoading = ValueNotifier(false);
  final ValueNotifier<Map<String, dynamic>> lastTelemetry = ValueNotifier({});
  final ValueNotifier<Map<String, dynamic>> lastAck = ValueNotifier({});

  // Members (kept local for now)
  final List<MemberItem> members = const [
    MemberItem(name: 'Aditya'),
    MemberItem(name: 'Naman'),
    MemberItem(name: 'Tina'),
    MemberItem(name: 'Atishay'),
  ];

  List<DeviceItem> get allDevices =>
      channels.value.expand((c) => c.devices).toList();

  // ── Load homeId then all data from Firestore ───────────────────────────────
  Future<void> loadFromFirestore() async {
    isLoading.value = true;
    homeId ??= await _fs.getHomeId();
    if (homeId != null) {
      channels.value = await _fs.loadChannels(homeId!);
      scenes.value   = await _fs.loadScenes(homeId!);
    }
    isLoading.value = false;
  }

  Future<void> startRealtime(String uid) async {
    // Use homeId as the MQTT topic namespace so all members share the same topics
    await _mqtt.connectForUser(uid, homeId: homeId);
  }

  Future<void> stopRealtime() async {
    await _mqtt.disconnect();
  }

  // ── Create a new home ──────────────────────────────────────────────────────
  Future<String?> createHome(String displayName) async {
    final id = await _fs.createHome(displayName);
    if (id != null) homeId = id;
    return id;
  }

  // ── Join an existing home ──────────────────────────────────────────────────
  Future<bool> joinHome(String id) async {
    final ok = await _fs.joinHome(id);
    if (ok) homeId = id;
    return ok;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CHANNEL OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> addChannel(String name, {String room = 'New Room'}) async {
    final existing = channels.value;
    if (existing.any((c) => c.name.toLowerCase() == name.toLowerCase())) return;
    final newChannel = ChannelItem(name: name, room: room, isOn: false);
    channels.value = [...existing, newChannel];
    if (homeId != null) await _fs.addChannel(homeId!, newChannel);
  }

  Future<void> toggleChannel(int index) async {
    await _ensureRealtimeConnected();
    final list = List<ChannelItem>.from(channels.value);
    final previous = list[index].isOn;
    list[index] = list[index].copyWith(isOn: !previous);
    channels.value = list;
    final sent = await _mqtt.publishChannelCommand(
      channelName: list[index].name,
      isOn: list[index].isOn,
    );
    if (!sent) {
      list[index] = list[index].copyWith(isOn: previous);
      channels.value = list;
      return;
    }
    if (homeId != null) await _fs.updateChannelState(homeId!, list[index].name, list[index].isOn);
  }

  Future<void> deleteChannel(String channelName) async {
    channels.value = channels.value.where((c) => c.name != channelName).toList();
    if (homeId != null) await _fs.deleteChannel(homeId!, channelName);
  }

  Future<void> clearDevicesInChannel(String channelName) async {
    final list = List<ChannelItem>.from(channels.value);
    final ci = list.indexWhere((c) => c.name == channelName);
    if (ci == -1) return;
    list[ci] = list[ci].copyWith(devices: []);
    channels.value = list;
    if (homeId != null) await _fs.clearChannelDevices(homeId!, channelName);
  }

  Future<void> renameChannel(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final list = List<ChannelItem>.from(channels.value);
    final ci = list.indexWhere((c) => c.name == oldName);
    if (ci == -1) return;
    final exists = list.any((c) => c.name.toLowerCase() == trimmed.toLowerCase() && c.name != oldName);
    if (exists) throw Exception('A channel with this name already exists.');
    final updatedDevices = list[ci].devices.map((d) => d.copyWith(channelName: trimmed)).toList();
    final updatedChannel = list[ci].copyWith(name: trimmed, devices: updatedDevices);
    list[ci] = updatedChannel;
    channels.value = list;
    if (homeId != null) await _fs.renameChannel(homeId!, oldName, updatedChannel);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DEVICE OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> toggleDevice(String channelName, int deviceIndex) async {
    await _ensureRealtimeConnected();
    final list = List<ChannelItem>.from(channels.value);
    final ci = list.indexWhere((c) => c.name == channelName);
    if (ci == -1) return;
    final devices = List<DeviceItem>.from(list[ci].devices);
    final previous = devices[deviceIndex].isOn;
    devices[deviceIndex] = devices[deviceIndex].copyWith(isOn: !previous);
    list[ci] = list[ci].copyWith(devices: devices);
    channels.value = list;
    final sent = await _mqtt.publishDeviceCommand(
      channelName: channelName,
      deviceName: devices[deviceIndex].name,
      plug: devices[deviceIndex].plug,
      isOn: devices[deviceIndex].isOn,
    );
    if (!sent) {
      devices[deviceIndex] = devices[deviceIndex].copyWith(isOn: previous);
      list[ci] = list[ci].copyWith(devices: devices);
      channels.value = list;
      return;
    }
    if (homeId != null) await _fs.updateDeviceState(homeId!, channelName, devices[deviceIndex], devices[deviceIndex].isOn);
  }

  Future<void> addDeviceToChannel(String channelName, DeviceItem device) async {
    final list = List<ChannelItem>.from(channels.value);
    final ci = list.indexWhere((c) => c.name == channelName);
    if (ci == -1) return;
    final devices = [...list[ci].devices, device];
    list[ci] = list[ci].copyWith(devices: devices);
    channels.value = list;
    if (homeId != null) await _fs.addDevice(homeId!, channelName, device);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SCENE OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> addScene(SceneItem scene) async {
    scenes.value = [...scenes.value, scene];
    if (homeId != null) await _fs.addScene(homeId!, scene);
  }

  Future<void> toggleScene(int index) async {
    final list = List<SceneItem>.from(scenes.value);
    list[index].isOn = !list[index].isOn;
    scenes.value = List.from(list);
    if (homeId != null) await _fs.updateSceneState(homeId!, list[index].name, list[index].isOn);
  }

  Future<void> deleteScene(String sceneName) async {
    scenes.value = scenes.value.where((s) => s.name != sceneName).toList();
    if (homeId != null) await _fs.deleteScene(homeId!, sceneName);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  MQTT INBOUND
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _handleMqttEvent(MqttInboundEvent event) async {
    if (event.type == MqttInboundType.channelState) {
      final channelName = _readString(event.payload, keys: const ['channelName', 'channel', 'name']);
      final isOn = _readBool(event.payload, keys: const ['isOn', 'state', 'value']);
      if (channelName == null || channelName.isEmpty || isOn == null) return;

      final list = List<ChannelItem>.from(channels.value);
      final ci = list.indexWhere((c) => c.name == channelName);
      if (ci == -1) {
        final created = ChannelItem(name: channelName, isOn: isOn);
        channels.value = [...list, created];
        if (homeId != null) await _fs.addChannel(homeId!, created);
      } else {
        list[ci] = list[ci].copyWith(isOn: isOn);
        channels.value = list;
      }
      if (homeId != null) await _fs.updateChannelState(homeId!, channelName, isOn);
      return;
    }

    if (event.type == MqttInboundType.deviceState) {
      final channelName = _readString(event.payload, keys: const ['channelName', 'channel']);
      final deviceName  = _readString(event.payload, keys: const ['deviceName', 'device', 'name']);
      final plug = _readString(event.payload, keys: const ['plug', 'pin']) ?? 'Plug 1';
      final isOn = _readBool(event.payload, keys: const ['isOn', 'state', 'value']);
      if (channelName == null || channelName.isEmpty || deviceName == null || deviceName.isEmpty || isOn == null) return;

      final list = List<ChannelItem>.from(channels.value);
      final ci = list.indexWhere((c) => c.name == channelName);
      ChannelItem channel;
      if (ci == -1) {
        channel = ChannelItem(name: channelName, isOn: true, devices: []);
        list.add(channel);
      } else {
        channel = list[ci];
      }

      final devices = List<DeviceItem>.from(channel.devices);
      final di = devices.indexWhere((d) => d.name == deviceName && d.plug == plug);
      DeviceItem current;
      if (di == -1) {
        current = DeviceItem(name: deviceName, channelName: channelName, plug: plug, icon: Icons.device_unknown, isOn: isOn);
        devices.add(current);
        if (homeId != null) await _fs.addDevice(homeId!, channelName, current);
      } else {
        current = devices[di].copyWith(isOn: isOn);
        devices[di] = current;
      }

      final updatedChannel = channel.copyWith(devices: devices);
      if (ci == -1) {
        list[list.length - 1] = updatedChannel;
        if (homeId != null) await _fs.addChannel(homeId!, updatedChannel);
      } else {
        list[ci] = updatedChannel;
      }
      channels.value = list;
      if (homeId != null) await _fs.updateDeviceState(homeId!, channelName, current, isOn);
      return;
    }

    if (event.type == MqttInboundType.telemetry) {
      lastTelemetry.value = Map<String, dynamic>.from(event.payload);
      return;
    }

    if (event.type == MqttInboundType.ack) {
      lastAck.value = Map<String, dynamic>.from(event.payload);
    }
  }

  String? _readString(Map<String, dynamic> data, {required List<String> keys}) {
    for (final key in keys) {
      final raw = data[key];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
      if (raw is num) return raw.toString();
    }
    return null;
  }

  bool? _readBool(Map<String, dynamic> data, {required List<String> keys}) {
    for (final key in keys) {
      final raw = data[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        final v = raw.trim().toLowerCase();
        if (v == '1' || v == 'true' || v == 'on') return true;
        if (v == '0' || v == 'false' || v == 'off') return false;
      }
    }
    return null;
  }

  Future<void> _ensureRealtimeConnected() async {
    if (_mqtt.isConnected) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return;
    try {
      await _mqtt.connectForUser(uid, homeId: homeId);
    } catch (e) {
      debugPrint('MQTT ensure connect failed: $e');
    }
  }
}
