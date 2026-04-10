import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_constants.dart';
import '../models/app_store.dart';
import '../services/firestore_service.dart';
import 'qr_scanner_screen.dart';

class MyChannelsScreen extends StatefulWidget {
  const MyChannelsScreen({super.key});
  @override
  State<MyChannelsScreen> createState() => _MyChannelsScreenState();
}

class _MyChannelsScreenState extends State<MyChannelsScreen> {
  final _store = AppStore.instance;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning!';
    if (h < 17) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  String _displayName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }
    final email = user?.email ?? '';
    if (email.isEmpty) return 'User';
    final local = email.split('@').first.trim();
    return local.isEmpty ? 'User' : local[0].toUpperCase() + local.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ValueListenableBuilder<List<ChannelItem>>(
          valueListenable: _store.channels,
          builder: (context, _, _x) {
            final channels = _store.permittedChannels;
            return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Top bar
                  Row(children: [
                    IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.primaryMid), onPressed: () => Navigator.pop(context)),
                    const Spacer(),
                    const Row(children: [
                      Icon(Icons.grid_view_rounded, color: AppColors.primaryMid, size: 22),
                      SizedBox(width: 6),
                      Text('My Channels', style: TextStyle(color: AppColors.primaryMid, fontSize: 20, fontWeight: FontWeight.w700)),
                    ]),
                    const Spacer(),
                    Stack(clipBehavior: Clip.none, children: [
                      const ProfileAvatar(),
                    ]),
                  ]),
                  const SizedBox(height: 14),
                  SummaryCard(
                    leftLabel: _greeting(),
                    leftValue: _displayName(),
                    rightLabel: 'Total Channels',
                    rightValue: channels.length.toString(),
                  ),
                  const SizedBox(height: 20),
                  // Home switcher
                  ValueListenableBuilder<List<String>>(
                    valueListenable: _store.allHomeIds,
                    builder: (context, homeIds, _) {
                      return ValueListenableBuilder<Map<String, String>>(
                        valueListenable: _store.homeNames,
                        builder: (context, names, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.home_outlined, color: AppColors.primaryDark, size: 16),
                                const SizedBox(width: 6),
                                const Text('My Homes', style: TextStyle(color: AppColors.primaryDark, fontSize: 14, fontWeight: FontWeight.w700)),
                                const Spacer(),
                                // Join another home
                                GestureDetector(
                                  onTap: _showJoinOptions,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.primary, width: 1),
                                    ),
                                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                      Icon(Icons.add, color: AppColors.primary, size: 13),
                                      SizedBox(width: 3),
                                      Text('Join / Add', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                                    ]),
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 10),
                              if (homeIds.isEmpty)
                                const Text('No homes yet.', style: TextStyle(color: AppColors.textLight, fontSize: 12))
                              else
                                ...homeIds.map((id) {
                                  final isActive = id == _store.homeId;
                                  final name = names[id] ?? id.substring(0, id.length.clamp(0, 8));
                                  return _HomeRow(
                                    homeId: id,
                                    name: name,
                                    isActive: isActive,
                                    onSwitch: () async {
                                      if (isActive) return;
                                      await _store.switchHome(id);
                                      if (context.mounted) setState(() {});
                                    },
                                    onLeaveOrDelete: () => _showLeaveDeleteDialog(id, name),
                                  );
                                }),
                              const SizedBox(height: 16),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  // Header row
                  Row(children: [
                    const Icon(Icons.grid_view_rounded, color: AppColors.primaryMid, size: 18),
                    const SizedBox(width: 6),
                    const Text('My Channels', style: TextStyle(color: AppColors.primaryMid, fontSize: 17, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/add-channel-qr'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.textPurple, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.add, color: AppColors.textPurple, size: 16),
                      label: const Text('Add More Channels', style: TextStyle(color: AppColors.textPurple, fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  const Text('List of all channels in my home', style: TextStyle(color: AppColors.textLight, fontSize: 12, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.75),
                    itemCount: channels.length,
                    itemBuilder: (_, i) => _ChannelCard(
                      channel: channels[i],
                      index: i,
                      onToggle: () => _store.toggleChannel(i),
                      onManage: () => _showActions(context, channels[i]),
                      onLongPress: () => _showActions(context, channels[i]),
                    ),
                  ),
                ]),
              ),
              // Bottom nav removed - now in bottomNavigationBar
            ],
          );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _miniBtn(Icons.home, AppColors.primaryDark, () => Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false)),
              _miniBtn(Icons.nightlight_round, AppColors.primaryDark, () => Navigator.pushNamed(context, '/my-scenes')),
              _miniBtn(Icons.power_outlined, AppColors.primaryDark, () => Navigator.pushNamed(context, '/my-devices')),
              _miniBtn(Icons.people_outline, AppColors.primaryDark, () => Navigator.pushNamed(context, '/users')),
              _miniBtn(Icons.logout, AppColors.red, () => Navigator.pushReplacementNamed(context, '/login')),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context, ChannelItem channel) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _actionItem(ctx, 'Add electronic device to this channel', () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/add-device', arguments: channel.name);
            }),
            const SizedBox(height: 20),
            _actionItem(ctx, 'Remove all electronic devices from channel', () {
              Navigator.pop(ctx);
              _confirmRemoveAllDevices(context, channel.name);
            }),
            const SizedBox(height: 20),
            _actionItem(ctx, 'Delete the channel', () {
              Navigator.pop(ctx);
              _confirmDelete(context, channel.name);
            }),
            const SizedBox(height: 20),
            _actionItem(ctx, 'Edit channel name', () {
              Navigator.pop(ctx);
              _editChannelName(context, channel.name);
            }),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textPurple, fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Widget _actionItem(BuildContext ctx, String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Text(label, style: const TextStyle(color: AppColors.textPurple, fontSize: 16, fontWeight: FontWeight.w500)),
  );

  Future<void> _confirmRemoveAllDevices(BuildContext context, String channelName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove All Devices'),
        content: Text('Remove all devices from "$channelName"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await _store.clearDevicesInChannel(channelName);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All devices removed from channel')));
    }
  }

  Future<void> _confirmDelete(BuildContext context, String channelName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Channel'),
        content: Text('Delete "$channelName"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _store.deleteChannel(channelName);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Channel deleted')));
    }
  }

  Future<void> _editChannelName(BuildContext context, String oldName) async {
    final ctrl = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Channel Name'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Channel name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == oldName) return;
    try {
      await _store.renameChannel(oldName, newName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Channel name updated')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Widget _miniBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: color, size: 26),
    );
  }

  void _showJoinOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.lightGrey, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
            title: const Text('Scan Invite QR', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
            onTap: () { Navigator.pop(context); _scanAndJoinHome(); },
          ),
          ListTile(
            leading: const Icon(Icons.keyboard, color: AppColors.primary),
            title: const Text('Enter Invite Code', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
            onTap: () { Navigator.pop(context); _manualJoinHome(); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showLeaveDeleteDialog(String homeId, String homeName) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    bool isOwner = false;
    for (final m in _store.members.value) {
      if (m.uid == currentUid && m.isOwner) { isOwner = true; break; }
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.lightGrey, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(homeName, style: const TextStyle(color: AppColors.primaryDark, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          // Both owner and member can leave
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: AppColors.orange),
            title: const Text('Leave Home', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w600)),
            subtitle: const Text('You will be removed from this home'),
            onTap: () { Navigator.pop(context); _confirmLeaveHome(homeId, homeName); },
          ),
          // Only owner can delete
          if (isOwner)
            ListTile(
              leading: const Icon(Icons.delete_forever, color: AppColors.red),
              title: const Text('Delete Home', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
              subtitle: const Text('Permanently removes all members and data'),
              onTap: () { Navigator.pop(context); _confirmDeleteHome(homeId, homeName); },
            ),
          ListTile(
            leading: const Icon(Icons.close, color: AppColors.textLight),
            title: const Text('Cancel', style: TextStyle(color: AppColors.textLight)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _confirmLeaveHome(String homeId, String homeName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Home', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
        content: Text('Leave "$homeName"? You can rejoin later with an invite.', style: const TextStyle(color: AppColors.textLight)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _store.leaveHome(targetHomeId: homeId);
              if (!mounted) return;
              final remaining = _store.allHomeIds.value;
              if (remaining.isNotEmpty) {
                await _store.switchHome(remaining.first);
                if (mounted) setState(() {});
              } else {
                Navigator.pushNamedAndRemoveUntil(context, '/home-setup', (_) => false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteHome(String homeId, String homeName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 20),
          SizedBox(width: 8),
          Text('Delete Home', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
        ]),
        content: Text('Delete "$homeName"? This removes ALL members and data permanently.', style: const TextStyle(color: AppColors.textLight)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _store.deleteHome(targetHomeId: homeId);
              if (!mounted) return;
              final remaining = _store.allHomeIds.value;
              if (remaining.isNotEmpty) {
                await _store.switchHome(remaining.first);
                if (mounted) setState(() {});
              } else {
                Navigator.pushNamedAndRemoveUntil(context, '/home-setup', (_) => false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _scanAndJoinHome() async {
    final camStatus = await Permission.camera.request();
    if (!camStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission required.')));
      return;
    }
    if (!mounted) return;
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
    if (!mounted || result == null || result.trim().isEmpty) return;
    String token = result.trim();
    if (token.toUpperCase().startsWith('INVITE:')) token = token.substring(7).trim();
    await _redeemToken(token);
  }

  Future<void> _manualJoinHome() async {
    final ctrl = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Invite Code'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: AppColors.primaryMid, fontSize: 20,
              fontWeight: FontWeight.w700, letterSpacing: 4),
          decoration: const InputDecoration(hintText: 'XXXXXXXX'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Join')),
        ],
      ),
    );
    if (token == null || token.isEmpty) return;
    await _redeemToken(token);
  }

  Future<void> _redeemToken(String token) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Text('Joining home...'),
        ]),
      ),
    );

    final error = await _store.redeemInvite(token);
    if (!mounted) return;
    Navigator.pop(context); // close loading dialog

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.red));
      return;
    }
    // Reload everything including permissions for the new home
    await _store.loadFromFirestore();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully joined the home! Switch to it using the home selector above.'),
            backgroundColor: AppColors.green));
  }
}

class _HomeRow extends StatelessWidget {
  final String homeId;
  final String name;
  final bool isActive;
  final VoidCallback onSwitch;
  final VoidCallback onLeaveOrDelete;

  const _HomeRow({
    required this.homeId,
    required this.name,
    required this.isActive,
    required this.onSwitch,
    required this.onLeaveOrDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.lightGrey,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4)],
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.home, size: 18, color: isActive ? Colors.white : AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(
              color: isActive ? AppColors.primaryDark : AppColors.textLight,
              fontSize: 13, fontWeight: FontWeight.w700)),
          if (isActive)
            const Text('Active', style: TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w600)),
        ])),
        if (!isActive)
          GestureDetector(
            onTap: onSwitch,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Switch', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onLeaveOrDelete,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.red.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.more_vert, color: AppColors.red, size: 16),
          ),
        ),
      ]),
    );
  }
}


class _ChannelCard extends StatelessWidget {
  final ChannelItem channel;
  final int index;
  final VoidCallback onToggle, onManage, onLongPress;

  const _ChannelCard({required this.channel, required this.index, required this.onToggle, required this.onManage, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 6, offset: Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.grid_view_rounded, color: AppColors.primaryMid, size: 20),
            const Spacer(),
            PowerButton(isOn: channel.isOn, onTap: onToggle, size: 40),
          ]),
          const SizedBox(height: 8),
          Text(channel.name, style: const TextStyle(color: AppColors.primaryMid, fontSize: 14, fontWeight: FontWeight.w700)),
          if (channel.room.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(channel.room, style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
          ],
          const SizedBox(height: 6),
          Text(channel.devicesLabel, style: const TextStyle(color: AppColors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          OutlinedButton(
            onPressed: onManage,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.textPurple, width: 1.5),
              visualDensity: VisualDensity.compact,
              minimumSize: const Size.fromHeight(36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Manage', style: TextStyle(color: AppColors.textPurple, fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(width: 4),
              Icon(Icons.settings, color: AppColors.textPurple, size: 14),
            ]),
          ),
        ]),
      ),
    );
  }
}
