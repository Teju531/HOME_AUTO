import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_constants.dart';
import '../models/app_store.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _store = AppStore.instance;
  late List<MemberItem> _members;

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
  void initState() {
    super.initState();
    _members = List.from(_store.members);
  }

  @override
  Widget build(BuildContext context) {
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
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_none, color: AppColors.primaryDark, size: 24),
                            onPressed: () {},
                          ),
                          Positioned(
                            right: 8, top: 8,
                            child: Container(
                              width: 16, height: 16,
                              decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                              child: Center(child: Text('${_members.length}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Summary card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.primaryMid,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 4))],
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(_greeting(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(_displayName(), style: const TextStyle(color: Colors.white, fontSize: 14)),
                              ])),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                const Text('Total Members', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text('${_members.length}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                              ]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Header
                        Row(
                          children: [
                            const Row(children: [
                              Icon(Icons.people, color: AppColors.primaryDark, size: 18),
                              SizedBox(width: 6),
                              Text('Members', style: TextStyle(color: AppColors.primaryDark, fontSize: 16, fontWeight: FontWeight.w700)),
                            ]),
                            const Spacer(),
                            OutlinedButton.icon(
                              onPressed: _showAddMemberDialog,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primary, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.add, color: AppColors.primary, size: 16),
                              label: const Text('Add More Members', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('List of all members in the home',
                            style: TextStyle(color: AppColors.textLight, fontSize: 12, fontStyle: FontStyle.italic)),
                        const SizedBox(height: 16),

                        // ── Members grid
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 1.0),
                          itemCount: _members.length,
                          itemBuilder: (_, i) => _memberCard(_members[i], i),
                        ),
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
                _navBtn(Icons.nightlight_round, AppColors.primaryDark, () => Navigator.pushNamed(context, '/my-scenes')),
                const SizedBox(width: 10),
                _navBtn(Icons.grid_view_rounded, AppColors.primaryDark, () => Navigator.pushNamed(context, '/my-channels')),
                const SizedBox(width: 10),
                _navBtn(Icons.power_outlined, AppColors.primaryDark, () => Navigator.pushNamed(context, '/my-devices')),
                const SizedBox(width: 10),
                _navBtn(Icons.people_outline, AppColors.primaryDark, () {}),
                const Spacer(),
                _navBtn(Icons.close, AppColors.red, () => Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberCard(MemberItem member, int idx) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 6)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 29,
            backgroundColor: AppColors.primary.withOpacity(0.15),
            child: Text(member.name[0].toUpperCase(),
                style: const TextStyle(color: AppColors.primary, fontSize: 21, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 7),
          Text(member.name, style: const TextStyle(color: AppColors.primaryDark, fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 7),
          OutlinedButton(
            onPressed: () => _showMemberOptions(member, idx),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary, width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              minimumSize: const Size(double.infinity, 27),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              visualDensity: VisualDensity.compact,
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              Text('Manage ', style: TextStyle(color: AppColors.primary, fontSize: 11)),
              Icon(Icons.settings, color: AppColors.primary, size: 11),
            ]),
          ),
        ],
      ),
    );
  }

  void _showMemberOptions(MemberItem member, int idx) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.lightGrey, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          _sheetItem('Permissions to access devices', () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/user-permissions', arguments: member);
          }),
          _sheetItem('Delete user', () {
            Navigator.pop(context);
            setState(() => _members.removeAt(idx));
          }, isDestructive: true),
          _sheetItem('Cancel', () => Navigator.pop(context)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sheetItem(String label, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      title: Text(label, style: TextStyle(color: isDestructive ? AppColors.red : AppColors.primary, fontSize: 15)),
      onTap: onTap,
    );
  }

  void _showAddMemberDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Member', style: TextStyle(color: AppColors.primaryDark, fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Enter name', border: UnderlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) setState(() => _members.add(MemberItem(name: name)));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
