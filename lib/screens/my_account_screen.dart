import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_constants.dart';
import '../models/app_store.dart';
import '../services/firestore_service.dart';

class MyAccountScreen extends StatefulWidget {
  const MyAccountScreen({super.key});
  @override
  State<MyAccountScreen> createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyAccountScreen> {
  final _auth = FirebaseAuth.instance;
  final _nameCtrl    = TextEditingController();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _rePassCtrl  = TextEditingController();

  bool _showOld = false, _showNew = false, _showRe = false;
  bool _savingName = false, _savingPass = false, _uploadingPhoto = false;
  String? _localPhotoPath;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    _nameCtrl.text = user?.displayName ?? _emailToName(user?.email);
    _loadLocalPhoto();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _rePassCtrl.dispose();
    super.dispose();
  }

  String _emailToName(String? email) {
    if (email == null || email.isEmpty) return '';
    final local = email.split('@').first.trim();
    return local.isEmpty ? '' : local[0].toUpperCase() + local.substring(1);
  }

  Future<void> _loadLocalPhoto() async {
    // AppStore already loaded it — just mirror the value
    setState(() => _localPhotoPath = AppStore.instance.profilePhoto.value);
  }

  // ── Pick & save photo locally ─────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 70, maxWidth: 512);
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      await AppStore.instance.setProfilePhoto(picked.path);
      setState(() => _localPhotoPath = picked.path);
      _snack('Photo updated!', AppColors.green);
    } catch (e) {
      _snack('Failed to save photo.', AppColors.red);
    } finally {
      setState(() => _uploadingPhoto = false);
    }
  }

  // ── Save display name ─────────────────────────────────────────────────────
  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _savingName = true);
    try {
      await _auth.currentUser!.updateDisplayName(name);
      final uid = _auth.currentUser!.uid;
      await FirestoreService.instance.updateUserProfile(uid, displayName: name);
      _snack('Name updated!', AppColors.green);
    } catch (e) {
      _snack('Failed to update name.', AppColors.red);
    } finally {
      setState(() => _savingName = false);
    }
  }

  // ── Change password ───────────────────────────────────────────────────────
  Future<void> _changePassword() async {
    final old    = _oldPassCtrl.text.trim();
    final newP   = _newPassCtrl.text.trim();
    final repeat = _rePassCtrl.text.trim();

    if (old.isEmpty || newP.isEmpty || repeat.isEmpty) {
      _snack('Please fill all password fields.', AppColors.red); return;
    }
    if (newP.length < 8) {
      _snack('New password must be at least 8 characters.', AppColors.red); return;
    }
    if (newP != repeat) {
      _snack('Passwords do not match.', AppColors.red); return;
    }

    setState(() => _savingPass = true);
    try {
      final user = _auth.currentUser!;
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: old);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newP);
      _oldPassCtrl.clear(); _newPassCtrl.clear(); _rePassCtrl.clear();
      _snack('Password changed successfully!', AppColors.green);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        _snack('Current password is incorrect.', AppColors.red);
      } else {
        _snack(e.message ?? 'Failed to change password.', AppColors.red);
      }
    } finally {
      setState(() => _savingPass = false);
    }
  }

  // ── Leave Home ────────────────────────────────────────────────────────────
  void _showLeaveHomeDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Home',
            style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
        content: const Text(
          'You will be removed from your current home. You can join or create a new one.',
          style: TextStyle(color: AppColors.textLight),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _leaveHome();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveHome() async {
    final homeId = AppStore.instance.homeId;
    if (homeId == null) return;
    await AppStore.instance.leaveHome(targetHomeId: homeId);
    if (!mounted) return;
    final remaining = AppStore.instance.allHomeIds.value;
    if (remaining.isNotEmpty) {
      await AppStore.instance.switchHome(remaining.first);
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/home-setup', (_) => false);
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out',
            style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to log out?',
            style: TextStyle(color: AppColors.textLight)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              AppStore.instance.stopScheduleChecker();
              AppStore.instance.stopRealtime();
              await _auth.signOut();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final user    = _auth.currentUser;
    final email   = user?.email ?? '';
    final initial = (_nameCtrl.text.isNotEmpty
        ? _nameCtrl.text[0]
        : (email.isNotEmpty ? email[0] : '?')).toUpperCase();

    final ImageProvider? avatarImage = _localPhotoPath != null
        ? FileImage(File(_localPhotoPath!))
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: AppColors.primaryDark, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text('My Profile', textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.primaryDark,
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 48),
              ]),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Avatar
                    Center(
                      child: Stack(
                        children: [
                          _uploadingPhoto
                              ? Container(
                                  width: 96, height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withOpacity(0.1),
                                  ),
                                  child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2)),
                                )
                              : CircleAvatar(
                                  radius: 48,
                                  backgroundColor: AppColors.primary.withOpacity(0.15),
                                  backgroundImage: avatarImage,
                                  child: avatarImage == null
                                      ? Text(initial,
                                          style: const TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 38,
                                              fontWeight: FontWeight.w700))
                                      : null,
                                ),
                          Positioned(
                            bottom: 2, right: 2,
                            child: GestureDetector(
                              onTap: _pickPhoto,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary),
                                child: const Icon(Icons.camera_alt,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(email,
                          style: const TextStyle(
                              color: AppColors.textLight, fontSize: 12)),
                    ),
                    const SizedBox(height: 28),

                    // ── Display Name
                    const Text('Display Name',
                        style: TextStyle(color: AppColors.primaryDark,
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtrl,
                          style: const TextStyle(
                              color: AppColors.primaryMid, fontSize: 15),
                          decoration: const InputDecoration(
                            hintText: 'Your name',
                            hintStyle: TextStyle(color: AppColors.grey),
                            prefixIcon: Icon(Icons.person_outline,
                                color: AppColors.primary, size: 20),
                            enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppColors.lightGrey)),
                            focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppColors.primary)),
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _savingName
                          ? const SizedBox(width: 36, height: 36,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : ElevatedButton(
                              onPressed: _saveName,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                              child: const Text('Save',
                                  style: TextStyle(color: Colors.white, fontSize: 13)),
                            ),
                    ]),
                    const SizedBox(height: 28),

                    // ── Account Info
                    const Text('Account Info',
                        style: TextStyle(color: AppColors.primaryDark,
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [BoxShadow(
                            color: Color(0x10000000), blurRadius: 4)],
                      ),
                      child: Column(children: [
                        _infoRow(Icons.email_outlined, 'Email', email),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _infoRow(Icons.home_outlined, 'Home ID',
                            AppStore.instance.homeId ?? 'Not set'),
                      ]),
                    ),
                    const SizedBox(height: 28),

                    // ── Change Password
                    const Text('Change Password',
                        style: TextStyle(color: AppColors.primaryDark,
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    _passField('Current Password', _oldPassCtrl,
                        _showOld, () => setState(() => _showOld = !_showOld)),
                    const SizedBox(height: 16),
                    _passField('New Password', _newPassCtrl,
                        _showNew, () => setState(() => _showNew = !_showNew)),
                    const SizedBox(height: 4),
                    const Text('Must be at least 8 characters.',
                        style: TextStyle(color: AppColors.textLight, fontSize: 11)),
                    const SizedBox(height: 16),
                    _passField('Confirm New Password', _rePassCtrl,
                        _showRe, () => setState(() => _showRe = !_showRe)),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 48,
                      child: ElevatedButton(
                        onPressed: _savingPass ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryMid,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _savingPass
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Update Password',
                                style: TextStyle(color: Colors.white,
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Leave Home
                    SizedBox(
                      width: double.infinity, height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _showLeaveHomeDialog,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.orange, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.exit_to_app, color: AppColors.orange, size: 18),
                        label: const Text('Leave Home / Switch Home',
                            style: TextStyle(color: AppColors.orange,
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ── Logout
                    SizedBox(
                      width: double.infinity, height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _showLogoutDialog,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.red, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.logout, color: AppColors.red, size: 18),
                        label: const Text('Log Out',
                            style: TextStyle(color: AppColors.red,
                                fontSize: 15, fontWeight: FontWeight.w600)),
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

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(
            color: AppColors.textLight, fontSize: 13)),
        const Spacer(),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.primaryDark,
                  fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }

  Widget _passField(String label, TextEditingController ctrl,
      bool show, VoidCallback toggle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
          color: AppColors.textLight, fontSize: 14)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        obscureText: !show,
        style: const TextStyle(color: AppColors.primaryMid, fontSize: 14),
        decoration: InputDecoration(
          hintText: '••••••••',
          hintStyle: const TextStyle(color: AppColors.grey),
          prefixIcon: const Icon(Icons.lock_outline,
              color: AppColors.primary, size: 18),
          suffixIcon: GestureDetector(
            onTap: toggle,
            child: Icon(show ? Icons.visibility : Icons.visibility_off,
                color: AppColors.grey, size: 20),
          ),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.lightGrey)),
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary)),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    ]);
  }
}
