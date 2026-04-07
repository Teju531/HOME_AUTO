import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/app_store.dart';
import '../services/firestore_service.dart';

class UserPermissionsScreen extends StatefulWidget {
  const UserPermissionsScreen({super.key});
  @override
  State<UserPermissionsScreen> createState() => _UserPermissionsScreenState();
}

class _UserPermissionsScreenState extends State<UserPermissionsScreen> {
  final _store = AppStore.instance;
  final Map<String, bool> _channelEnabled = {};
  final Map<String, Map<int, bool>> _deviceEnabled = {};
  final Set<String> _expandedChannels = {};
  bool _nameEditing = false;
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    for (final ch in _store.channels.value) {
      _channelEnabled[ch.name] = false;
      _deviceEnabled[ch.name] = {};
      for (int i = 0; i < ch.devices.length; i++) {
        _deviceEnabled[ch.name]![i] = false;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingPermissions());
  }

  Future<void> _loadExistingPermissions() async {
    final member = ModalRoute.of(context)?.settings.arguments as MemberItem?;
    if (member == null) return;
    final homeId = _store.homeId;
    if (homeId == null) return;
    final homeMembers = await FirestoreService.instance.getHomeMembers(homeId);
    final ownerUid = homeMembers.firstWhere(
        (m) => m['isOwner'] == '1', orElse: () => {})['uid'] ?? '';
    final allowed = await FirestoreService.instance.loadPermissions(homeId, member.uid, ownerUid);
    if (allowed == null || !mounted) return; // null = owner, full access
    setState(() {
      for (final key in allowed) {
        final parts = key.split('|||');
        if (parts.length != 2) continue;
        final chName = parts[0];
        final devIdx = int.tryParse(parts[1]);
        if (devIdx == null) continue;
        _channelEnabled[chName] = true;
        _deviceEnabled[chName] ??= {};
        _deviceEnabled[chName]![devIdx] = true;
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final member = ModalRoute.of(context)?.settings.arguments as MemberItem?;
    if (member != null && _nameCtrl.text.isEmpty) {
      _nameCtrl.text = member.name;
    }
    final channels = _store.channels.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // ── AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primaryDark, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text('Users', textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      TextButton(
                        onPressed: _save,
                        child: const Text('Save', style: TextStyle(color: AppColors.primaryDark, fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ── Avatar
                        GestureDetector(
                          onTap: () {},
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 44,
                                backgroundColor: AppColors.primary.withOpacity(0.15),
                                child: Text(
                                  _nameCtrl.text.isEmpty ? '?' : _nameCtrl.text[0].toUpperCase(),
                                  style: const TextStyle(color: AppColors.primary, fontSize: 34, fontWeight: FontWeight.w700),
                                ),
                              ),
                              Positioned(
                                bottom: 2, right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                                  child: const Icon(Icons.edit, size: 14, color: AppColors.primaryMid),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // ── Name
                        if (_nameEditing)
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            SizedBox(
                              width: 160,
                              child: TextField(
                                controller: _nameCtrl,
                                autofocus: true,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline),
                                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                                onSubmitted: (_) => setState(() => _nameEditing = false),
                              ),
                            ),
                          ])
                        else
                          GestureDetector(
                            onTap: () => setState(() => _nameEditing = true),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(_nameCtrl.text.isEmpty ? 'Enter a name' : _nameCtrl.text,
                                  style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline)),
                              const SizedBox(width: 6),
                              const Icon(Icons.edit, size: 16, color: AppColors.primaryMid),
                            ]),
                          ),
                        const SizedBox(height: 20),

                        // ── Permissions section
                        Row(
                          children: [
                            const Text('Permissions', style: TextStyle(color: AppColors.primaryDark, fontSize: 15, fontWeight: FontWeight.w700)),
                            const Spacer(),
                            OutlinedButton.icon(
                              onPressed: _showCloneDialog,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primary, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.copy, color: AppColors.primary, size: 14),
                              label: const Text('Clone', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                            ),
                          ],
                        ),
                        const Text('List of all devices, this member has permission to',
                            style: TextStyle(color: AppColors.textLight, fontSize: 12, fontStyle: FontStyle.italic)),
                        const SizedBox(height: 14),

                        // ── Channels list
                        ...channels.map((ch) => _channelPermissionRow(ch, channels.indexOf(ch))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // ── Bottom nav
            Positioned(
              left: 16, right: 16, bottom: 14,
              child: Row(children: [
                _navBtn(Icons.home, AppColors.primaryDark, () => Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false)),
                const SizedBox(width: 10),
                _navBtn(Icons.nightlight_round, AppColors.primaryDark, () {}),
                const SizedBox(width: 10),
                _navBtn(Icons.grid_view_rounded, AppColors.primaryDark, () {}),
                const SizedBox(width: 10),
                _navBtn(Icons.view_in_ar, AppColors.primaryDark, () {}),
                const SizedBox(width: 10),
                _navBtn(Icons.people_outline, AppColors.primaryDark, () {}),
                const Spacer(),
                _navBtn(Icons.close, AppColors.red, () => Navigator.pop(context)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _channelPermissionRow(ChannelItem ch, int chIdx) {
    final isExpanded = _expandedChannels.contains(ch.name);
    final isEnabled = _channelEnabled[ch.name] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFECEBFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.grid_view_rounded, color: AppColors.primaryMid, size: 18),
                const SizedBox(width: 8),
                Text(ch.name, style: const TextStyle(color: AppColors.primaryMid, fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                Switch(
                  value: isEnabled,
                  onChanged: (v) => setState(() => _channelEnabled[ch.name] = v),
                  activeColor: AppColors.primaryDark,
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() {
                    if (isExpanded) _expandedChannels.remove(ch.name);
                    else _expandedChannels.add(ch.name);
                  }),
                  child: Icon(isExpanded ? Icons.keyboard_arrow_down : Icons.chevron_right, color: AppColors.primaryMid),
                ),
              ],
            ),
          ),
          if (isExpanded && ch.devices.isNotEmpty)
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Column(
                children: ch.devices.asMap().entries.map((e) {
                  final devEnabled = _deviceEnabled[ch.name]?[e.key] ?? false;
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.lightGrey, width: 0.5)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          Icon(e.value.icon, color: AppColors.primaryMid, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text(e.value.name, style: const TextStyle(color: AppColors.primaryMid, fontSize: 13, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 6),
                                  PlugTag(e.value.plug),
                                ]),
                              ],
                            ),
                          ),
                          Switch(
                            value: devEnabled,
                            onChanged: (v) => setState(() => _deviceEnabled[ch.name]![e.key] = v),
                            activeColor: AppColors.primaryDark,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  void _showCloneDialog() {
    final otherMembers = _store.members.value.where((m) => m.name != _nameCtrl.text).toList();
    String? selected;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Row(
            children: [
              const Text('Clone permission from...', style: TextStyle(color: AppColors.primaryDark, fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.red, size: 20),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...otherMembers.map((m) => RadioListTile<String>(
                value: m.name,
                groupValue: selected,
                onChanged: (v) => setDState(() => selected = v),
                title: Text(m.name, style: const TextStyle(color: AppColors.primaryDark, fontSize: 14)),
                activeColor: AppColors.primary,
                dense: true,
              )),
              const SizedBox(height: 12),
              GradientButton(
                text: 'Save',
                onPressed: () {
                  Navigator.pop(ctx);
                  if (selected != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cloned permissions from $selected')));
                  }
                },
                height: 46,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() async {
    final member = ModalRoute.of(context)?.settings.arguments as MemberItem?;
    if (member == null) return;
    final homeId = _store.homeId;
    if (homeId == null) return;

    // Build list of allowed device keys
    final allowedKeys = <String>[];
    for (final ch in _store.channels.value) {
      final chEnabled = _channelEnabled[ch.name] ?? false;
      if (!chEnabled) continue;
      for (int i = 0; i < ch.devices.length; i++) {
        final devEnabled = _deviceEnabled[ch.name]?[i] ?? false;
        if (devEnabled) allowedKeys.add('${ch.name}|||$i');
      }
    }

    await FirestoreService.instance.savePermissions(homeId, member.uid, allowedKeys);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions saved'), backgroundColor: AppColors.green));
    Navigator.pop(context);
  }

  Widget _navBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
