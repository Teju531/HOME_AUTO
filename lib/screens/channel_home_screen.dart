import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/app_store.dart';

// ─── Channel Home Screen ──────────────────────────────────────────────────────
class ChannelHomeScreen extends StatefulWidget {
  const ChannelHomeScreen({super.key});
  @override
  State<ChannelHomeScreen> createState() => _ChannelHomeScreenState();
}

class _ChannelHomeScreenState extends State<ChannelHomeScreen> {
  final _store = AppStore.instance;
  String _channelName = 'Migro_CH1';

  ChannelItem? get _channel {
    final list = _store.channels.value;
    try {
      return list.firstWhere((c) => c.name == _channelName);
    } catch (_) {
      return list.isNotEmpty ? list.first : null;
    }
  }

  void _showAddDeviceDialog() {
    final ch = _channel;
    if (ch == null) return;

    final ctrl = TextEditingController(text: 'Light Bulb');
    String selectedPlug = 'Plug 1';
    showDialog<void>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setDState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Stack(clipBehavior: Clip.none, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Add Device to Channel', style: TextStyle(color: AppColors.primaryMid, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primaryMid, width: 2)), child: const Icon(Icons.lightbulb_outline, color: AppColors.primaryMid, size: 36)),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  style: const TextStyle(color: AppColors.primaryMid, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'Device name',
                    isDense: true,
                    contentPadding: EdgeInsets.only(bottom: 6),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCCCCCC))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedPlug,
                  style: const TextStyle(color: AppColors.primaryMid, fontSize: 16),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.only(bottom: 6),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCCCCCC))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                  ),
                  items: ['Plug 1', 'Plug 2', 'Plug 3', 'Plug 4'].map((p) {
                    final devicesOnPlug = ch.devices.where((d) => d.plug == p).length;
                    final isFull = devicesOnPlug >= 2;
                    return DropdownMenuItem(
                      value: p,
                      child: Row(children: [
                        Text(p),
                        const SizedBox(width: 8),
                        Text(
                          isFull ? '(full)' : '($devicesOnPlug/2)',
                          style: TextStyle(
                            fontSize: 11,
                            color: isFull ? AppColors.red : AppColors.textLight,
                          ),
                        ),
                      ]),
                    );
                  }).toList(),
                  onChanged: (v) { if (v != null) setDState(() => selectedPlug = v); },
                ),
                const SizedBox(height: 24),
                GradientButton(
                  text: 'Save',
                  onPressed: () {
                    final name = ctrl.text.trim();
                    if (name.isEmpty) return;
                    final targetChannel = ch.name;

                    // Rule 1: same name + same plug not allowed
                    if (ch.devices.any((d) => d.name.toLowerCase() == name.toLowerCase() && d.plug == selectedPlug)) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('"$name" already exists on $selectedPlug.'),
                            backgroundColor: AppColors.red));
                      return;
                    }

                    // Rule 2: max 2 devices per plug
                    final devicesOnPlug = ch.devices.where((d) => d.plug == selectedPlug).length;
                    if (devicesOnPlug >= 2) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('$selectedPlug already has 2 devices. Max 2 per plug.'),
                            backgroundColor: AppColors.red));
                      return;
                    }

                    _store.addDeviceToChannel(targetChannel, DeviceItem(
                      name: name,
                      channelName: targetChannel,
                      plug: selectedPlug,
                      icon: Icons.lightbulb_outline,
                      isOn: false,
                    ));
                    setState(() {});
                    Navigator.pop(dCtx);
                  },
                  height: 52,
                ),
              ]),
            ),
            Positioned(right: -10, top: -10, child: GestureDetector(
              onTap: () => Navigator.pop(dCtx),
              child: Container(width: 36, height: 36, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 20)),
            )),
          ]),
        ),
      ),
    );
  }

  void _showManageSheet() {
    final ch = _channel;
    final activeChannelName = ch?.name ?? _channelName;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _act(ctx, 'Add electronic device to this channel', () { Navigator.pop(ctx); _showAddDeviceDialog(); }),
            const SizedBox(height: 18),
            _act(ctx, 'Remove all electronic devices from channel', () { Navigator.pop(ctx); _confirmRemoveAllDevices(activeChannelName); }),
            const SizedBox(height: 18),
            _act(ctx, 'Delete the channel', () { Navigator.pop(ctx); _confirmDeleteChannel(activeChannelName); }),
            const SizedBox(height: 18),
            _act(ctx, 'Edit channel name', () { Navigator.pop(ctx); _editChannelName(activeChannelName); }),
            const SizedBox(height: 18),
            GestureDetector(onTap: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textPurple, fontSize: 16))),
          ]),
        ),
      ),
    );
  }

  Widget _act(BuildContext ctx, String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Text(label, style: const TextStyle(color: AppColors.textPurple, fontSize: 15, fontWeight: FontWeight.w500)),
  );

  Future<void> _confirmRemoveAllDevices(String channelName) async {
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All devices removed from channel')));
    setState(() {});
  }

  Future<void> _confirmDeleteChannel(String channelName) async {
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Channel deleted')));
    Navigator.pushReplacementNamed(context, '/my-channels');
  }

  Future<void> _editChannelName(String oldName) async {
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
      if (!mounted) return;
      setState(() => _channelName = newName);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Channel name updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ChannelItem>>(
      valueListenable: _store.channels,
      builder: (context, channels, _) {
        final ch = _channel;
        final devices = ch?.devices ?? [];

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Stack(children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.primaryMid), onPressed: () => Navigator.pop(context)),
                    const Icon(Icons.grid_view_rounded, color: AppColors.primaryMid, size: 22),
                    const SizedBox(width: 6),
                    Expanded(child: Text(ch?.name ?? _channelName, style: const TextStyle(color: AppColors.primaryMid, fontSize: 18, fontWeight: FontWeight.w700))),
                    const Icon(Icons.notifications_none, color: AppColors.primaryMid, size: 24),
                  ]),
                  const SizedBox(height: 14),
                  SummaryCard(rightLabel: 'Total Devices', rightValue: '${devices.length}/${ch?.totalPlugs ?? 4}'),
                  const SizedBox(height: 20),
                  Row(children: [
                    const Icon(Icons.power, color: AppColors.primaryDark, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Devices in ${ch?.name ?? _channelName}', style: const TextStyle(color: AppColors.primaryDark, fontSize: 16, fontWeight: FontWeight.w700))),
                    if (_store.allowedDeviceKeys == null)
                    OutlinedButton.icon(
                      onPressed: _showAddDeviceDialog,
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.textPurple, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                      icon: const Icon(Icons.add, color: AppColors.textPurple, size: 16),
                      label: const Text('Add Device', style: TextStyle(color: AppColors.textPurple, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  const Text('List of all devices in this channel.\nSlide left to remove device, slide right to edit.', style: TextStyle(color: AppColors.textLight, fontSize: 12, fontStyle: FontStyle.italic, height: 1.4)),
                  if (ch != null && devices.length < ch.totalPlugs) ...[
                    const SizedBox(height: 6),
                    Text('You can add ${ch.totalPlugs - devices.length} more electronic devices in this Channel.', style: const TextStyle(color: AppColors.orange, fontSize: 12)),
                  ],
                  if (ch != null) Text('This channel is setup in: ${ch.room}', style: const TextStyle(color: AppColors.orange, fontSize: 12)),
                  const SizedBox(height: 16),
                  if (devices.isEmpty)
                    Column(children: [
                      const SizedBox(height: 20),
                      const Text('There are no devices in this channel yet, you can add upto 4 devices in this channel.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textLight, fontSize: 14, height: 1.4)),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: _showAddDeviceDialog,
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), minimumSize: const Size(180, 46)),
                        icon: const Icon(Icons.add, color: AppColors.primary, size: 18),
                        label: const Text('Add Devices', style: TextStyle(color: AppColors.primary, fontSize: 14)),
                      ),
                    ])
                  else
                    ...devices.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DeviceRow(
                        device: e.value,
                        channelName: ch?.name ?? _channelName,
                        isOwner: _store.allowedDeviceKeys == null,
                        onToggle: () { _store.toggleDevice(ch?.name ?? _channelName, e.key); setState(() {}); },
                        onDelete: () async {
                          await _store.deleteDevice(ch?.name ?? _channelName, e.value);
                          setState(() {});
                        },
                        onRename: () => _renameDevice(ch?.name ?? _channelName, e.value),
                      ),
                    )),
                ]),
              ),
              Positioned(left: 16, right: 16, bottom: 14, child: Row(children: [
                _nb(Icons.home, AppColors.primaryDark, () => Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false)),
                const Spacer(),
                if (_store.allowedDeviceKeys == null)
                  _nb(Icons.add, AppColors.red, _showAddDeviceDialog),
              ])),
              if (_store.allowedDeviceKeys == null)
                Positioned(top: 12, right: 70, child: TextButton(onPressed: _showManageSheet, child: const Text('Manage', style: TextStyle(color: AppColors.textPurple)))),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _renameDevice(String channelName, DeviceItem device) async {
    final ctrl = TextEditingController(text: device.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Device'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Device name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == device.name) return;
    await _store.renameDevice(channelName, device, newName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device renamed')));
    setState(() {});
  }

  Widget _nb(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(width: 52, height: 52, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 26)),
  );
}

class _DeviceRow extends StatelessWidget {
  final DeviceItem device;
  final String channelName;
  final bool isOwner;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  const _DeviceRow({
    required this.device,
    required this.channelName,
    required this.isOwner,
    required this.onToggle,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOwner) {
      // Member: no swipe actions, just toggle
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Row(children: [
          Icon(device.icon, color: AppColors.primaryMid, size: 26),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(device.name, style: const TextStyle(color: AppColors.primaryMid, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              PlugTag(device.plug),
            ]),
          ])),
          PowerButton(isOn: device.isOn, onTap: onToggle, size: 44),
        ]),
      );
    }
    return Dismissible(
      key: Key('${device.name}_${device.plug}'),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(children: [
          Icon(Icons.edit, color: Colors.white, size: 22),
          SizedBox(width: 6),
          Text('Rename', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          SizedBox(width: 6),
          Icon(Icons.delete, color: Colors.white, size: 22),
        ]),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Delete
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Device'),
              content: Text('Delete "${device.name}"?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
              ],
            ),
          );
          if (ok == true) { onDelete(); return true; }
          return false;
        } else {
          // Rename — don't dismiss, just trigger rename
          onRename();
          return false;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Row(children: [
          Icon(device.icon, color: AppColors.primaryMid, size: 26),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(device.name, style: const TextStyle(color: AppColors.primaryMid, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              PlugTag(device.plug),
            ]),
            const SizedBox(height: 4),
            const Text('← Rename  |  Delete →', style: TextStyle(color: AppColors.textLight, fontSize: 10, fontStyle: FontStyle.italic)),
          ])),
          PowerButton(isOn: device.isOn, onTap: onToggle, size: 44),
        ]),
      ),
    );
  }
}
