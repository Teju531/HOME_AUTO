import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/app_store.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Home helpers ───────────────────────────────────────────────────────────
  DocumentReference<Map<String, dynamic>> _homeDoc(String homeId) =>
      _db.collection('homes').doc(homeId);

  CollectionReference<Map<String, dynamic>> _channelsFor(String homeId) =>
      _homeDoc(homeId).collection('channels');

  CollectionReference<Map<String, dynamic>> _scenesFor(String homeId) =>
      _homeDoc(homeId).collection('scenes');

  String _deviceId(String name, String plug) =>
      '${name.trim()}_${plug.trim()}'.replaceAll(RegExp(r'\s+'), '_');

  // ── Create a new home, returns homeId ──────────────────────────────────────
  Future<String?> createHome(String displayName) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final ref = _db.collection('homes').doc();
      await ref.set({
        'homeId':      ref.id,
        'ownerUid':    uid,
        'displayName': displayName,
        'members':     [uid],
        'createdAt':   FieldValue.serverTimestamp(),
      });
      await _db.collection('users').doc(uid).set(
        {'homeId': ref.id, 'email': FirebaseAuth.instance.currentUser?.email},
        SetOptions(merge: true),
      );
      return ref.id;
    } catch (e) {
      debugPrint('Error creating home: $e');
      return null;
    }
  }

  // ── Join an existing home by homeId ────────────────────────────────────────
  Future<bool> joinHome(String homeId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final doc = await _homeDoc(homeId).get();
      if (!doc.exists) return false;
      await _homeDoc(homeId).update({
        'members': FieldValue.arrayUnion([uid]),
      });
      await _db.collection('users').doc(uid).set(
        {'homeId': homeId, 'email': FirebaseAuth.instance.currentUser?.email},
        SetOptions(merge: true),
      );
      return true;
    } catch (e) {
      debugPrint('Error joining home: $e');
      return false;
    }
  }

  // ── Get homeId for current user (null = not in any home yet) ───────────────
  Future<String?> getHomeId() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.data()?['homeId'] as String?;
    } catch (e) {
      debugPrint('Error getting homeId: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CHANNELS
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<ChannelItem>> loadChannels(String homeId) async {
    try {
      final channels = _channelsFor(homeId);
      final snapshot = await channels.get();
      final List<ChannelItem> result = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final devSnap = await channels.doc(doc.id).collection('devices').get();
        final devices = devSnap.docs.map((d) {
          final dd = d.data();
          final iconCode = (dd['iconCode'] as num?)?.toInt() ?? Icons.devices.codePoint;
          return DeviceItem(
            name: (dd['name'] as String?) ?? '',
            channelName: (data['name'] as String?) ?? '',
            plug: (dd['plug'] as String?) ?? '',
            icon: IconData(iconCode, fontFamily: 'MaterialIcons'),
            isOn: (dd['isOn'] as bool?) ?? false,
          );
        }).toList();

        result.add(ChannelItem(
          name: (data['name'] as String?) ?? doc.id,
          room: (data['room'] as String?) ?? '',
          totalPlugs: (data['totalPlugs'] as num?)?.toInt() ?? 4,
          isOn: (data['isOn'] as bool?) ?? false,
          devices: devices,
        ));
      }
      result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return result;
    } catch (e) {
      debugPrint('Error loading channels: $e');
      return [];
    }
  }

  Future<void> addChannel(String homeId, ChannelItem channel) async {
    try {
      await _channelsFor(homeId).doc(channel.name).set({
        'name':       channel.name,
        'room':       channel.room,
        'totalPlugs': channel.totalPlugs,
        'isOn':       channel.isOn,
        'createdAt':  FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding channel: $e');
    }
  }

  Future<void> updateChannelState(String homeId, String channelName, bool isOn) async {
    try {
      await _channelsFor(homeId).doc(channelName).set({
        'name':      channelName,
        'isOn':      isOn,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating channel: $e');
    }
  }

  Future<void> deleteChannel(String homeId, String channelName) async {
    try {
      final channels = _channelsFor(homeId);
      final devSnap = await channels.doc(channelName).collection('devices').get();
      for (final d in devSnap.docs) await d.reference.delete();
      await channels.doc(channelName).delete();
    } catch (e) {
      debugPrint('Error deleting channel: $e');
    }
  }

  Future<void> clearChannelDevices(String homeId, String channelName) async {
    try {
      final devSnap = await _channelsFor(homeId).doc(channelName).collection('devices').get();
      for (final d in devSnap.docs) await d.reference.delete();
    } catch (e) {
      debugPrint('Error clearing devices: $e');
    }
  }

  Future<void> renameChannel(String homeId, String oldName, ChannelItem updated) async {
    try {
      final channels = _channelsFor(homeId);
      final devSnap = await channels.doc(oldName).collection('devices').get();

      await channels.doc(updated.name).set({
        'name':       updated.name,
        'room':       updated.room,
        'totalPlugs': updated.totalPlugs,
        'isOn':       updated.isOn,
        'createdAt':  FieldValue.serverTimestamp(),
      });

      for (final d in devSnap.docs) {
        final dd = d.data();
        final devId = _deviceId((dd['name'] as String?) ?? '', (dd['plug'] as String?) ?? '');
        await channels.doc(updated.name).collection('devices').doc(devId).set(dd);
      }

      for (final d in devSnap.docs) await d.reference.delete();
      await channels.doc(oldName).delete();
    } catch (e) {
      debugPrint('Error renaming channel: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DEVICES
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> addDevice(String homeId, String channelName, DeviceItem device) async {
    try {
      final devId = _deviceId(device.name, device.plug);
      await _channelsFor(homeId).doc(channelName).collection('devices').doc(devId).set({
        'name':      device.name,
        'plug':      device.plug,
        'iconCode':  device.icon.codePoint,
        'isOn':      device.isOn,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding device: $e');
    }
  }

  Future<void> deleteDevice(String homeId, String channelName, DeviceItem device) async {
    try {
      final devId = _deviceId(device.name, device.plug);
      await _channelsFor(homeId).doc(channelName).collection('devices').doc(devId).delete();
    } catch (e) {
      debugPrint('Error deleting device: $e');
    }
  }

  Future<void> renameDevice(String homeId, String channelName, DeviceItem oldDevice, String newName) async {
    try {
      final oldId = _deviceId(oldDevice.name, oldDevice.plug);
      final newId = _deviceId(newName, oldDevice.plug);
      final ref = _channelsFor(homeId).doc(channelName).collection('devices');
      final data = (await ref.doc(oldId).get()).data() ?? {};
      data['name'] = newName;
      await ref.doc(newId).set(data);
      if (oldId != newId) await ref.doc(oldId).delete();
    } catch (e) {
      debugPrint('Error renaming device: $e');
    }
  }

  Future<void> updateDeviceState(String homeId, String channelName, DeviceItem device, bool isOn) async {
    try {
      final devId = _deviceId(device.name, device.plug);
      await _channelsFor(homeId).doc(channelName).collection('devices').doc(devId).set({
        'name':      device.name,
        'plug':      device.plug,
        'iconCode':  device.icon.codePoint,
        'isOn':      isOn,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating device: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SCENES
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<SceneItem>> loadScenes(String homeId) async {
    try {
      final snapshot = await _scenesFor(homeId).get();
      final scenes = snapshot.docs.map((doc) {
        final data = doc.data();
        return SceneItem(
          name: (data['name'] as String?) ?? doc.id,
          deviceCount: (data['deviceCount'] as num?)?.toInt() ?? 0,
          isOn: (data['isOn'] as bool?) ?? false,
        );
      }).toList();
      scenes.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return scenes;
    } catch (e) {
      debugPrint('Error loading scenes: $e');
      return [];
    }
  }

  Future<void> addScene(String homeId, SceneItem scene) async {
    try {
      await _scenesFor(homeId).doc(scene.name).set({
        'name':        scene.name,
        'deviceCount': scene.deviceCount,
        'isOn':        scene.isOn,
        'createdAt':   FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding scene: $e');
    }
  }

  Future<void> updateSceneState(String homeId, String sceneName, bool isOn) async {
    try {
      await _scenesFor(homeId).doc(sceneName).set({
        'name':      sceneName,
        'isOn':      isOn,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating scene: $e');
    }
  }

  Future<void> deleteScene(String homeId, String sceneName) async {
    try {
      await _scenesFor(homeId).doc(sceneName).delete();
    } catch (e) {
      debugPrint('Error deleting scene: $e');
    }
  }
}
