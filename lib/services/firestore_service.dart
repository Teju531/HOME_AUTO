import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/app_store.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Helpers ────────────────────────────────────────────────────────────────
  DocumentReference<Map<String, dynamic>> _homeDoc(String homeId) =>
      _db.collection('homes').doc(homeId);

  CollectionReference<Map<String, dynamic>> _channelsFor(String homeId) =>
      _homeDoc(homeId).collection('channels');

  CollectionReference<Map<String, dynamic>> _scenesFor(String homeId) =>
      _homeDoc(homeId).collection('scenes');

  String _deviceId(String name, String plug) =>
      '${name.trim()}_${plug.trim()}'.replaceAll(RegExp(r'\s+'), '_');

  // ══════════════════════════════════════════════════════════════════════════
  //  INVITE TOKENS
  // ══════════════════════════════════════════════════════════════════════════

  Future<String?> createInviteToken(String homeId) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final token = _randomToken();
      await _db.collection('inviteTokens').doc(token).set({
        'homeId':    homeId,
        'createdBy': uid,
        'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(hours: 24))),
        'used': false,
      });
      return token;
    } catch (e) {
      debugPrint('Error creating invite token: $e');
      return null;
    }
  }

  Future<_InviteResult> redeemInviteToken(String token) async {
    final uid = _uid;
    if (uid == null) return _InviteResult.error('Not logged in.');
    try {
      final doc = await _db.collection('inviteTokens').doc(token.toUpperCase()).get();
      if (!doc.exists) return _InviteResult.error('Invalid invite code.');

      final data = doc.data()!;
      if (data['used'] == true) {
        return _InviteResult.error('This invite has already been used.');
      }

      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        return _InviteResult.error('This invite has expired.');
      }

      final homeId = data['homeId'] as String;

      final userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.data()?['homeId'] == homeId) {
        return _InviteResult.error('You are already a member of this home.');
      }

      // Mark used and add member
      await _db.collection('inviteTokens').doc(token.toUpperCase())
          .update({'used': true});
      await _homeDoc(homeId).update({
        'members': FieldValue.arrayUnion([uid]),
      });
      await _db.collection('users').doc(uid).set(
        {
          'homeId': homeId,
          'homeIds': FieldValue.arrayUnion([homeId]),
          'email': FirebaseAuth.instance.currentUser?.email,
        },
        SetOptions(merge: true),
      );

      return _InviteResult.success(homeId);
    } catch (e) {
      debugPrint('Error redeeming invite: $e');
      return _InviteResult.error('Something went wrong. Try again.');
    }
  }

  String _randomToken() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    var seed = DateTime.now().millisecondsSinceEpoch;
    var result = '';
    for (var i = 0; i < 8; i++) {
      seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF;
      result += chars[seed % chars.length];
    }
    return result;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HOME MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

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
        {
          'homeId': ref.id,
          'homeIds': FieldValue.arrayUnion([ref.id]),
          'email': FirebaseAuth.instance.currentUser?.email,
        },
        SetOptions(merge: true),
      );
      return ref.id;
    } catch (e) {
      debugPrint('Error creating home: $e');
      return null;
    }
  }

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
        {
          'homeId': homeId,
          'homeIds': FieldValue.arrayUnion([homeId]),
          'email': FirebaseAuth.instance.currentUser?.email,
        },
        SetOptions(merge: true),
      );
      return true;
    } catch (e) {
      debugPrint('Error joining home: $e');
      return false;
    }
  }

  Future<void> updateUserProfile(String uid,
      {String? displayName, String? photoUrl}) async {
    try {
      final data = <String, dynamic>{};
      if (displayName != null) data['displayName'] = displayName;
      if (photoUrl != null) data['photoUrl'] = photoUrl;
      if (data.isEmpty) return;
      await _db.collection('users').doc(uid).set(
          data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating user profile: $e');
    }
  }

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

  // Returns all homeIds the user belongs to
  Future<List<String>> getAllHomeIds() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null) return [];
      // Support both old single homeId and new homeIds array
      final homeIds = List<String>.from(data['homeIds'] ?? []);
      final legacyHomeId = data['homeId'] as String?;
      if (legacyHomeId != null && !homeIds.contains(legacyHomeId)) {
        homeIds.add(legacyHomeId);
      }
      return homeIds;
    } catch (e) {
      debugPrint('Error getting homeIds: $e');
      return [];
    }
  }

  Future<String?> getHomeName(String homeId) async {
    try {
      final doc = await _homeDoc(homeId).get();
      return doc.data()?['displayName'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, String>>> getHomeMembers(String homeId) async {
    try {
      final homeDoc = await _homeDoc(homeId).get();
      final uids = List<String>.from(homeDoc.data()?['members'] ?? []);
      final ownerUid = homeDoc.data()?['ownerUid'] as String? ?? '';
      final results = <Map<String, String>>[];
      for (final uid in uids) {
        final userDoc = await _db.collection('users').doc(uid).get();
        final email = userDoc.data()?['email'] as String? ?? uid;
        final name = userDoc.data()?['displayName'] as String? ??
            (email.contains('@') ? email.split('@').first : email);
        results.add({'uid': uid, 'name': name, 'isOwner': uid == ownerUid ? '1' : '0'});
      }
      return results;
    } catch (e) {
      debugPrint('Error getting home members: $e');
      return [];
    }
  }

  Future<void> removeMember(String homeId, String memberUid) async {
    try {
      await _homeDoc(homeId).update({
        'members': FieldValue.arrayRemove([memberUid]),
      });
      await _db.collection('users').doc(memberUid).set(
        {
          'homeIds': FieldValue.arrayRemove([homeId]),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Error removing member: $e');
    }
  }

  // Save permissions: deviceKeys the member is allowed to control
  Future<void> savePermissions(String homeId, String memberUid, List<String> allowedDeviceKeys) async {
    try {
      await _homeDoc(homeId).collection('permissions').doc(memberUid).set({
        'allowedDeviceKeys': allowedDeviceKeys,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving permissions: $e');
    }
  }

  // Load permissions for a member — returns null if owner (full access)
  Future<List<String>?> loadPermissions(String homeId, String memberUid, String ownerUid) async {
    if (memberUid == ownerUid) return null; // owner has full access
    try {
      final doc = await _homeDoc(homeId).collection('permissions').doc(memberUid).get();
      if (!doc.exists) return []; // no permissions set = no access
      return List<String>.from(doc.data()?['allowedDeviceKeys'] ?? []);
    } catch (e) {
      debugPrint('Error loading permissions: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DEVICE OWNERSHIP (MAC-based)
  // ══════════════════════════════════════════════════════════════════════════

  Future<String?> getDeviceOwnerHomeId(String mac) async {
    try {
      final normalizedMac = mac.toUpperCase().replaceAll('-', ':');
      final snap = await _db
          .collectionGroup('registeredDevices')
          .where('mac', isEqualTo: normalizedMac)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data()['homeId'] as String?;
    } catch (e) {
      debugPrint('Error checking device ownership: $e');
      return null;
    }
  }

  Future<void> registerDevice(String homeId, String mac) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final normalizedMac = mac.toUpperCase().replaceAll('-', ':');
      await _homeDoc(homeId)
          .collection('registeredDevices')
          .doc(normalizedMac.replaceAll(':', '_'))
          .set({
        'mac':          normalizedMac,
        'homeId':       homeId,
        'ownerUid':     uid,
        'registeredAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error registering device: $e');
    }
  }

  Future<void> unregisterDevice(String homeId, String mac) async {
    try {
      final normalizedMac = mac.toUpperCase().replaceAll('-', ':');
      await _homeDoc(homeId)
          .collection('registeredDevices')
          .doc(normalizedMac.replaceAll(':', '_'))
          .delete();
    } catch (e) {
      debugPrint('Error unregistering device: $e');
    }
  }

  Future<List<String>> getRegisteredMacs(String homeId) async {
    try {
      final snap = await _homeDoc(homeId).collection('registeredDevices').get();
      return snap.docs
          .map((d) => (d.data()['mac'] as String? ?? '').toUpperCase())
          .where((m) => m.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Error getting registered MACs: $e');
      return [];
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
          final iconCode = (dd['iconCode'] as num?)?.toInt() ??
              Icons.devices.codePoint;
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
      result.sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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

  Future<void> updateChannelState(
      String homeId, String channelName, bool isOn) async {
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
      final devSnap =
          await channels.doc(channelName).collection('devices').get();
      for (final d in devSnap.docs) await d.reference.delete();
      await channels.doc(channelName).delete();
    } catch (e) {
      debugPrint('Error deleting channel: $e');
    }
  }

  Future<void> clearChannelDevices(
      String homeId, String channelName) async {
    try {
      final devSnap = await _channelsFor(homeId)
          .doc(channelName)
          .collection('devices')
          .get();
      for (final d in devSnap.docs) await d.reference.delete();
    } catch (e) {
      debugPrint('Error clearing devices: $e');
    }
  }

  Future<void> renameChannel(
      String homeId, String oldName, ChannelItem updated) async {
    try {
      final channels = _channelsFor(homeId);
      final devSnap =
          await channels.doc(oldName).collection('devices').get();
      await channels.doc(updated.name).set({
        'name':       updated.name,
        'room':       updated.room,
        'totalPlugs': updated.totalPlugs,
        'isOn':       updated.isOn,
        'createdAt':  FieldValue.serverTimestamp(),
      });
      for (final d in devSnap.docs) {
        final dd = d.data();
        final devId = _deviceId(
            (dd['name'] as String?) ?? '', (dd['plug'] as String?) ?? '');
        await channels
            .doc(updated.name)
            .collection('devices')
            .doc(devId)
            .set(dd);
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

  Future<void> addDevice(
      String homeId, String channelName, DeviceItem device) async {
    try {
      final devId = _deviceId(device.name, device.plug);
      await _channelsFor(homeId)
          .doc(channelName)
          .collection('devices')
          .doc(devId)
          .set({
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

  Future<void> deleteDevice(
      String homeId, String channelName, DeviceItem device) async {
    try {
      final devId = _deviceId(device.name, device.plug);
      await _channelsFor(homeId)
          .doc(channelName)
          .collection('devices')
          .doc(devId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting device: $e');
    }
  }

  Future<void> renameDevice(String homeId, String channelName,
      DeviceItem oldDevice, String newName) async {
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

  Future<void> updateDeviceState(String homeId, String channelName,
      DeviceItem device, bool isOn) async {
    try {
      final devId = _deviceId(device.name, device.plug);
      await _channelsFor(homeId)
          .doc(channelName)
          .collection('devices')
          .doc(devId)
          .set({
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
          name:                (data['name'] as String?) ?? doc.id,
          deviceCount:         (data['deviceCount'] as num?)?.toInt() ?? 0,
          isOn:                (data['isOn'] as bool?) ?? false,
          deviceKeys:          List<String>.from(data['deviceKeys'] ?? []),
          timerMinutes:        (data['timerMinutes'] as num?)?.toInt() ?? 0,
          scheduleStartHour:   (data['scheduleStartHour'] as num?)?.toInt(),
          scheduleStartMinute: (data['scheduleStartMinute'] as num?)?.toInt(),
          scheduleEndHour:     (data['scheduleEndHour'] as num?)?.toInt(),
          scheduleEndMinute:   (data['scheduleEndMinute'] as num?)?.toInt(),
          scheduleDays:        List<int>.from(data['scheduleDays'] ?? []),
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
        'name':                scene.name,
        'deviceCount':         scene.deviceCount,
        'isOn':                scene.isOn,
        'deviceKeys':          scene.deviceKeys,
        'timerMinutes':        scene.timerMinutes,
        'scheduleStartHour':   scene.scheduleStartHour,
        'scheduleStartMinute': scene.scheduleStartMinute,
        'scheduleEndHour':     scene.scheduleEndHour,
        'scheduleEndMinute':   scene.scheduleEndMinute,
        'scheduleDays':        scene.scheduleDays,
        'createdAt':           FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding scene: $e');
    }
  }

  Future<void> updateSceneState(
      String homeId, String sceneName, bool isOn) async {
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

// ── Invite result helper ───────────────────────────────────────────────────
class _InviteResult {
  final bool ok;
  final String? homeId;
  final String? errorMessage;
  const _InviteResult._({required this.ok, this.homeId, this.errorMessage});
  factory _InviteResult.success(String homeId) =>
      _InviteResult._(ok: true, homeId: homeId);
  factory _InviteResult.error(String msg) =>
      _InviteResult._(ok: false, errorMessage: msg);
}
