import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../constants/app_constants.dart';
import '../models/app_store.dart';
import '../services/firestore_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _store = AppStore.instance;

  @override
  void initState() {
    super.initState();
    // Ensure listener is running (in case screen opened before home loaded)
    AppStore.instance.startMembersListener();
  }

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

  // ── Generate invite token and show QR ──────────────────────────────────────
  Future<void> _showInviteQR() async {
    final homeId = _store.homeId;
    if (homeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No home found. Please set up your home first.')));
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final token = await FirestoreService.instance.createInviteToken(homeId);
    if (!mounted) return;
    Navigator.pop(context);

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate invite. Try again.'),
              backgroundColor: AppColors.red));
      return;
    }

    final qrData = 'INVITE:$token';

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Icon(Icons.qr_code, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                const Text('Invite Member',
                    style: TextStyle(color: AppColors.primaryDark,
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    // Reload members after closing invite dialog
                    _store.loadMembers();
                  },
                  child: const Icon(Icons.close, color: AppColors.textLight, size: 20),
                ),
              ]),
              const SizedBox(height: 8),
              const Text(
                'Ask the family member to open the app → Home Setup → "Join with QR" and scan this code.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightGrey),
                  boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 6)],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.primaryDark,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Or share this code manually:',
                  style: TextStyle(color: AppColors.textLight, fontSize: 11)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECEBFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Expanded(
                    child: Text(token,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.primaryMid,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 4)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: AppColors.primary, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: token));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Code copied to clipboard!')));
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.access_time, color: AppColors.orange, size: 14),
                  SizedBox(width: 6),
                  Text('Expires in 24 hours · One use only',
                      style: TextStyle(color: AppColors.orange,
                          fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMemberOptions(MemberItem member) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isSelf = member.uid == currentUid;
    final isOwner = member.isOwner;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.lightGrey,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        // Permissions — only owner can manage others, or viewing self
        if (!isSelf)
          _sheetItem('Permissions to access devices', () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/user-permissions', arguments: member);
          }),
        // Owner viewing their own card → both Leave and Delete
        if (isSelf && isOwner) ...[
          _sheetItem('Leave Home', () {
            Navigator.pop(context);
            _confirmLeaveHome();
          }, isDestructive: false, color: AppColors.orange),
          _sheetItem('Delete Home', () {
            Navigator.pop(context);
            _confirmDeleteHome();
          }, isDestructive: true),
        ],
        // Member viewing their own card → Leave only
        if (isSelf && !isOwner)
          _sheetItem('Leave Home', () {
            Navigator.pop(context);
            _confirmLeaveHome();
          }, isDestructive: false, color: AppColors.orange),
        // Owner removing another member
        if (!isSelf && !member.isOwner)
          _sheetItem('Remove from home', () {
            Navigator.pop(context);
            _confirmRemoveMember(member);
          }, isDestructive: true),
        _sheetItem('Cancel', () => Navigator.pop(context)),
        const SizedBox(height: 20),
      ]),
    );
  }

  void _confirmRemoveMember(MemberItem member) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Member',
            style: TextStyle(color: AppColors.primaryDark,
                fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Remove ${member.name} from your home?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _store.removeMember(member.uid);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveHome() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Home',
            style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
        content: const Text(
          'You will be removed from this home. You can join or create a new one.',
          style: TextStyle(color: AppColors.textLight),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _store.leaveHome(targetHomeId: _store.homeId);
              if (!mounted) return;
              final remaining = _store.allHomeIds.value;
              if (remaining.isNotEmpty) {
                await _store.switchHome(remaining.first);
                if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
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

  void _confirmDeleteHome() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 22),
          SizedBox(width: 8),
          Text('Delete Home',
              style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
        ]),
        content: const Text(
          'This will permanently delete the home and remove ALL members. This cannot be undone.',
          style: TextStyle(color: AppColors.textLight),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _store.deleteHome(targetHomeId: _store.homeId);
              if (!mounted) return;
              final remaining = _store.allHomeIds.value;
              if (remaining.isNotEmpty) {
                await _store.switchHome(remaining.first);
                if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
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

  Widget _sheetItem(String label, VoidCallback onTap,
      {bool isDestructive = false, Color? color}) {
    return ListTile(
      title: Text(label, style: TextStyle(
          color: color ?? (isDestructive ? AppColors.red : AppColors.primary),
          fontSize: 15)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<MemberItem>>(
      valueListenable: _store.members,
      builder: (context, members, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _miniBtn(Icons.home, '/home', false, () => Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false)),
                  _miniBtn(Icons.nightlight_round, '/my-scenes', false, () => Navigator.pushNamed(context, '/my-scenes')),
                  _miniBtn(Icons.grid_view_rounded, '/my-channels', false, () => Navigator.pushNamed(context, '/my-channels')),
                  _miniBtn(Icons.power_outlined, '/my-devices', false, () => Navigator.pushNamed(context, '/my-devices')),
                  _miniBtn(Icons.people_outline, '/users', true, () {}),
                  _miniBtn(Icons.logout, '', false, () async {
                    await FirebaseAuth.instance.signOut();
                    if (!mounted) return;
                    Navigator.pushReplacementNamed(context, '/login');
                  }),
                ],
              ),
            ),
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Column(
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
                          child: Text('Users', textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.primaryDark,
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/my-account'),
                          child: Builder(builder: (_) {
                            final user = FirebaseAuth.instance.currentUser;
                            final photo = user?.photoURL;
                            final initial = ((user?.displayName?.isNotEmpty == true
                                ? user!.displayName![0]
                                : user?.email?[0]) ?? '?').toUpperCase();
                            return CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.primary.withOpacity(0.15),
                              backgroundImage: photo != null ? NetworkImage(photo) : null,
                              child: photo == null
                                  ? Text(initial, style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 14, fontWeight: FontWeight.w700))
                                  : null,
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                      ]),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Summary card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.primaryMid,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: const [BoxShadow(
                                    color: Color(0x26000000),
                                    blurRadius: 8, offset: Offset(0, 4))],
                              ),
                              child: Row(children: [
                                Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_greeting(), style: const TextStyle(
                                          color: Colors.white, fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text(_displayName(), style: const TextStyle(
                                          color: Colors.white, fontSize: 14)),
                                    ])),
                                Column(crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Total Members', style: TextStyle(
                                          color: Colors.white, fontSize: 14,
                                          fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text('${members.length}', style: const TextStyle(
                                          color: Colors.white, fontSize: 18,
                                          fontWeight: FontWeight.w700)),
                                    ]),
                              ]),
                            ),
                            const SizedBox(height: 16),

                            // ── Invite banner
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECEBFF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.primary, width: 1.5),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.qr_code,
                                      color: AppColors.primary, size: 26),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Invite a Family Member',
                                          style: TextStyle(color: AppColors.primaryDark,
                                              fontSize: 14, fontWeight: FontWeight.w700)),
                                      SizedBox(height: 2),
                                      Text('Generate a QR code · Expires in 24h',
                                          style: TextStyle(color: AppColors.textLight,
                                              fontSize: 11)),
                                    ])),
                                ElevatedButton(
                                  onPressed: _showInviteQR,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                  ),
                                  child: const Text('Invite',
                                      style: TextStyle(color: Colors.white,
                                          fontSize: 13, fontWeight: FontWeight.w600)),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 20),

                            // ── Members header
                            const Row(children: [
                              Icon(Icons.people, color: AppColors.primaryDark, size: 18),
                              SizedBox(width: 6),
                              Text('Members', style: TextStyle(
                                  color: AppColors.primaryDark, fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                            ]),
                            const SizedBox(height: 4),
                            const Text('List of all members in the home',
                                style: TextStyle(color: AppColors.textLight,
                                    fontSize: 12, fontStyle: FontStyle.italic)),
                            const SizedBox(height: 16),

                            // ── Members grid
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: 0.9),
                              itemCount: members.length,
                              itemBuilder: (_, i) => _memberCard(members[i]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // ── Bottom nav removed
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _memberCard(MemberItem member) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 6)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 29,
              backgroundColor: AppColors.primary.withOpacity(0.15),
              child: Text(
                  member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.primary,
                      fontSize: 21, fontWeight: FontWeight.w700)),
            ),
            if (member.isOwner)
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.star, color: Colors.white, size: 10),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(member.name,
            style: const TextStyle(color: AppColors.primaryDark,
                fontSize: 13, fontWeight: FontWeight.w700),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        if (member.isOwner)
          const Text('Owner',
              style: TextStyle(color: AppColors.primary, fontSize: 10)),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: () => _showMemberOptions(member),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.primary, width: 1),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            minimumSize: const Size(double.infinity, 26),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            visualDensity: VisualDensity.compact,
          ),
          child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Manage ',
                    style: TextStyle(color: AppColors.primary, fontSize: 11)),
                Icon(Icons.settings, color: AppColors.primary, size: 11),
              ]),
        ),
      ]),
    );
  }

  Widget _miniBtn(IconData icon, String route, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isActive ? AppColors.primary : AppColors.primaryDark,
          size: isActive ? 28 : 24,
        ),
      ),
    );
  }
}
