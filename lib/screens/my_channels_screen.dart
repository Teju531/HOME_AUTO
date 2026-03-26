import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/app_store.dart';

class MyChannelsScreen extends StatelessWidget {
  const MyChannelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ValueListenableBuilder<List<ChannelItem>>(
          valueListenable: store.channels,
          builder: (context, channels, _) => Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Top bar
                  Row(children: [
                    IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.primaryMid), onPressed: () => Navigator.pop(context)),
                    const Spacer(),
                    Row(children: const [
                      Icon(Icons.grid_view_rounded, color: AppColors.primaryMid, size: 22),
                      SizedBox(width: 6),
                      Text('My Channels', style: TextStyle(color: AppColors.primaryMid, fontSize: 20, fontWeight: FontWeight.w700)),
                    ]),
                    const Spacer(),
                    Stack(clipBehavior: Clip.none, children: [
                      const Icon(Icons.notifications_none, color: AppColors.primaryMid, size: 26),
                      Positioned(right: -4, top: -4, child: CircleAvatar(radius: 9, backgroundColor: const Color(0xFFE2AD73),
                          child: Text(channels.length.toString(), style: const TextStyle(color: Colors.white, fontSize: 10)))),
                    ]),
                  ]),
                  const SizedBox(height: 14),
                  SummaryCard(rightLabel: 'Total Channels', rightValue: channels.length.toString()),
                  const SizedBox(height: 20),
                  // Header row
                  Row(children: [
                    const Icon(Icons.grid_view_rounded, color: AppColors.primaryMid, size: 18),
                    const SizedBox(width: 6),
                    const Text('My Channels', style: TextStyle(color: AppColors.primaryMid, fontSize: 17, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/add-channel-qr'),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.textPurple, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), visualDensity: VisualDensity.compact),
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.75),
                    itemCount: channels.length,
                    itemBuilder: (_, i) => _ChannelCard(
                      channel: channels[i],
                      index: i,
                      onToggle: () => store.toggleChannel(i),
                      onManage: () => _showActions(context, store, channels[i]),
                      onLongPress: () => _showActions(context, store, channels[i]),
                    ),
                  ),
                ]),
              ),
              // Bottom nav
              Positioned(
                left: 16, right: 16, bottom: 14,
                child: Row(children: [
                  _nb(Icons.home, AppColors.primaryDark, () => Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false)),
                  const SizedBox(width: 10),
                  _nb(Icons.nightlight_round, AppColors.primaryDark, () => Navigator.pushNamed(context, '/my-scenes')),
                  const SizedBox(width: 10),
                  _nb(Icons.power_outlined, AppColors.primaryDark, () => Navigator.pushNamed(context, '/my-devices')),
                  const SizedBox(width: 10),
                  _nb(Icons.people_outline, AppColors.primaryDark, () => Navigator.pushNamed(context, '/users')),
                  const Spacer(),
                  _nb(Icons.close, AppColors.red, () => Navigator.pushReplacementNamed(context, '/login')),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context, AppStore store, ChannelItem channel) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _actionItem(
              ctx,
              'Add electronic device to this channel',
              () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/add-device', arguments: channel.name);
              },
            ),
            const SizedBox(height: 20),
            _actionItem(
              ctx,
              'Remove all electronic devices from channel',
              () {
                Navigator.pop(ctx);
                _confirmRemoveAllDevices(context, store, channel.name);
              },
            ),
            const SizedBox(height: 20),
            _actionItem(
              ctx,
              'Delete the channel',
              () {
                Navigator.pop(ctx);
                _confirmDelete(context, store, channel.name);
              },
            ),
            const SizedBox(height: 20),
            _actionItem(
              ctx,
              'Edit channel name',
              () {
                Navigator.pop(ctx);
                _editChannelName(context, store, channel.name);
              },
            ),
            const SizedBox(height: 20),
            GestureDetector(onTap: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textPurple, fontSize: 16, fontWeight: FontWeight.w500))),
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

  Future<void> _confirmRemoveAllDevices(BuildContext context, AppStore store, String channelName) async {
    final shouldRemove = await showDialog<bool>(
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

    if (shouldRemove != true) return;

    await store.clearDevicesInChannel(channelName);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All devices removed from channel')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, AppStore store, String channelName) async {
    final shouldDelete = await showDialog<bool>(
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

    if (shouldDelete != true) return;

    await store.deleteChannel(channelName);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Channel deleted')),
      );
    }
  }

  Future<void> _editChannelName(BuildContext context, AppStore store, String oldName) async {
    final ctrl = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Channel Name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Channel name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == oldName) return;

    try {
      await store.renameChannel(oldName, newName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Channel name updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Widget _nb(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(width: 46, height: 46, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 22)),
  );
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
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
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
