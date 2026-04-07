import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/app_store.dart';
import '../services/firestore_service.dart';

class ManageSceneScreen extends StatefulWidget {
  const ManageSceneScreen({super.key});
  @override
  State<ManageSceneScreen> createState() => _ManageSceneScreenState();
}

class _ManageSceneScreenState extends State<ManageSceneScreen> {
  final _store = AppStore.instance;
  int _tabIndex = 0;
  final _nameCtrl = TextEditingController();
  int _timerMinutes = 0;
  int _selectedChannelIdx = 0;
  final Map<String, bool> _deviceSelections = {};
  final List<bool> _selectedDays = List.filled(7, false);
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final sceneName = ModalRoute.of(context)?.settings.arguments as String?;
    if (sceneName != null) {
      _nameCtrl.text = sceneName;
      // Pre-populate selections from existing scene
      final scene = _store.scenes.value.firstWhere(
        (s) => s.name == sceneName,
        orElse: () => SceneItem(name: sceneName),
      );
      for (final key in scene.deviceKeys) {
        _deviceSelections[key] = true;
      }
      _timerMinutes = scene.timerMinutes;
      // Pre-populate schedule
      if (scene.hasSchedule) {
        _tabIndex = 2;
        _startTime = TimeOfDay(hour: scene.scheduleStartHour!, minute: scene.scheduleStartMinute!);
        _endTime   = TimeOfDay(hour: scene.scheduleEndHour!,   minute: scene.scheduleEndMinute!);
        for (final d in scene.scheduleDays) {
          if (d >= 0 && d < 7) _selectedDays[d] = true;
        }
      } else if (scene.timerMinutes > 0) {
        _tabIndex = 1;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _deviceKey(String channelName, int deviceIndex) =>
      '$channelName|||$deviceIndex';

  @override
  Widget build(BuildContext context) {
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
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.nightlight_round, color: AppColors.primaryDark, size: 20),
                          SizedBox(width: 6),
                          Text('Manage Scene', style: TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Scene name — always visible
                        const Text('Scene Name', style: TextStyle(color: AppColors.textLight, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameCtrl,
                          style: const TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            hintText: 'e.g. Party, Night, Morning',
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.lightGrey)),
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Tab bar
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFECEBFF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(children: [
                            _tabBtn('Manual', 0),
                            _tabBtn('Timer', 1),
                            _tabBtn('Schedule', 2),
                          ]),
                        ),
                        const SizedBox(height: 20),

                        // ── Device selector (shown in all tabs)
                        if (channels.isEmpty)
                          const Text('No channels yet. Add a channel first.',
                              style: TextStyle(color: AppColors.textLight, fontSize: 13))
                        else
                          _buildDeviceSelector(channels),

                        const SizedBox(height: 20),

                        // ── Tab-specific content
                        if (_tabIndex == 1) _timerContent(),
                        if (_tabIndex == 2) _scheduleContent(),

                        const SizedBox(height: 20),
                        GradientButton(text: 'Save Scene', onPressed: _saveScene),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 16, right: 16, bottom: 14,
              child: Row(children: [
                _navBtn(Icons.home, AppColors.primaryDark,
                    () => Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(String label, int idx) {
    final isSelected = _tabIndex == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? AppColors.primaryDark : AppColors.textLight,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              )),
        ),
      ),
    );
  }

  Widget _buildDeviceSelector(List<ChannelItem> channels) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select devices for this scene:',
            style: TextStyle(color: AppColors.primaryDark, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Toggle ON the devices you want this scene to control.',
            style: TextStyle(color: AppColors.textLight, fontSize: 12, fontStyle: FontStyle.italic)),
        const SizedBox(height: 12),
        ...channels.asMap().entries.map((e) => _channelSection(e.value, e.key)),
      ],
    );
  }

  Widget _channelSection(ChannelItem ch, int chIdx) {
    final isExpanded = _selectedChannelIdx == chIdx;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFECEBFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isExpanded ? AppColors.primary : Colors.transparent, width: 1.5),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.grid_view_rounded, color: AppColors.primaryMid, size: 18),
            title: Text(ch.name, style: const TextStyle(color: AppColors.primaryMid, fontSize: 14, fontWeight: FontWeight.w600)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${ch.devices.where((d) {
                final idx = ch.devices.indexOf(d);
                return _deviceSelections[_deviceKey(ch.name, idx)] == true;
              }).length}/${ch.devices.length}',
                  style: const TextStyle(color: AppColors.orange, fontSize: 11)),
              const SizedBox(width: 4),
              Icon(isExpanded ? Icons.keyboard_arrow_down : Icons.chevron_right, color: AppColors.primaryMid),
            ]),
            onTap: () => setState(() => _selectedChannelIdx = isExpanded ? -1 : chIdx),
          ),
          if (isExpanded) ...[
            if (ch.devices.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text('No devices in this channel.', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
              )
            else
              ...ch.devices.asMap().entries.map((e) => _deviceRow(e.value, ch.name, e.key)),
          ],
        ],
      ),
    );
  }

  Widget _deviceRow(DeviceItem d, String channelName, int dIdx) {
    final key = _deviceKey(channelName, dIdx);
    final isSelected = _deviceSelections[key] ?? false;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE0E0E0), width: 0.5)),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(d.icon, color: isSelected ? AppColors.green : AppColors.primaryMid, size: 18),
        title: Row(children: [
          Text(d.name, style: TextStyle(
              color: isSelected ? AppColors.green : AppColors.primaryMid,
              fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          PlugTag(d.plug),
        ]),
        subtitle: Text(
          isSelected ? 'Will be turned ON when scene activates' : 'Not included in scene',
          style: TextStyle(
              color: isSelected ? AppColors.green : AppColors.textLight,
              fontSize: 10, fontStyle: FontStyle.italic),
        ),
        trailing: Switch(
          value: isSelected,
          onChanged: (v) => setState(() => _deviceSelections[key] = v),
          activeColor: AppColors.primary,
        ),
      ),
    );
  }

  Widget _timerContent() {
    final options = [
      ('1 Min', 1), ('5 Min', 5), ('10 Min', 10),
      ('15 Min', 15), ('30 Min', 30), ('1 Hour', 60),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Text('Timer — auto turn OFF after:',
            style: TextStyle(color: AppColors.primaryDark, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: options.map((opt) {
            final selected = _timerMinutes == opt.$2;
            return GestureDetector(
              onTap: () => setState(() => _timerMinutes = selected ? 0 : opt.$2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : const Color(0xFFECEBFF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selected ? AppColors.primary : AppColors.lightGrey),
                ),
                child: Text(opt.$1, style: TextStyle(
                    color: selected ? Colors.white : AppColors.primaryMid,
                    fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            );
          }).toList(),
        ),
        if (_timerMinutes > 0) ...[
          const SizedBox(height: 10),
          Text('Devices will turn OFF automatically after $_timerMinutes minute${_timerMinutes == 1 ? '' : 's'}.',
              style: const TextStyle(color: AppColors.green, fontSize: 12, fontStyle: FontStyle.italic)),
        ],
      ],
    );
  }

  Widget _scheduleContent() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayShort = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Text('Schedule — auto activate by time:',
            style: TextStyle(color: AppColors.primaryDark, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),

        // Start time
        Row(children: [
          const Text('From:', style: TextStyle(color: AppColors.textLight, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _startTime);
              if (t != null) setState(() => _startTime = t);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_startTime.format(context),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          const SizedBox(width: 16),
          const Text('To:', style: TextStyle(color: AppColors.textLight, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _endTime);
              if (t != null) setState(() => _endTime = t);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryMid,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_endTime.format(context),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // Day selector
        const Text('Repeat on:', style: TextStyle(color: AppColors.textLight, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          ...List.generate(7, (i) => GestureDetector(
            onTap: () => setState(() => _selectedDays[i] = !_selectedDays[i]),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _selectedDays[i] ? AppColors.primary : const Color(0xFFECEBFF),
                border: Border.all(
                  color: _selectedDays[i] ? AppColors.primary : AppColors.lightGrey,
                ),
              ),
              child: Center(child: Text(dayShort[i], style: TextStyle(
                  color: _selectedDays[i] ? Colors.white : AppColors.primaryMid,
                  fontSize: 11, fontWeight: FontWeight.w700))),
            ),
          )),
        ]),
        const SizedBox(height: 6),
        Text(
          _selectedDays.every((d) => !d)
              ? 'Every day'
              : 'On: ${List.generate(7, (i) => _selectedDays[i] ? days[i] : null).whereType<String>().join(', ')}',
          style: const TextStyle(color: AppColors.textLight, fontSize: 11, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 12),

        // Preview
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.green.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.green.withOpacity(0.4)),
          ),
          child: Row(children: [
            const Icon(Icons.schedule, color: AppColors.green, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Scene will turn ON at ${_startTime.format(context)} and OFF at ${_endTime.format(context)}',
                style: const TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Future<void> _saveScene() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please provide a scene name')));
      return;
    }

    // Collect selected device keys
    final deviceKeys = _deviceSelections.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    final list = List<SceneItem>.from(_store.scenes.value);
    final existingIdx = list.indexWhere((s) => s.name.toLowerCase() == name.toLowerCase());

    // Collect selected days
    final selectedDayIndices = <int>[];
    for (var i = 0; i < _selectedDays.length; i++) {
      if (_selectedDays[i]) selectedDayIndices.add(i);
    }

    // Build schedule fields (only if Schedule tab is active)
    final hasSchedule = _tabIndex == 2;

    final newScene = SceneItem(
      name: name,
      deviceCount: deviceKeys.length,
      isOn: existingIdx >= 0 ? list[existingIdx].isOn : false,
      deviceKeys: deviceKeys,
      timerMinutes: _tabIndex == 1 ? _timerMinutes : 0,
      scheduleStartHour:   hasSchedule ? _startTime.hour   : null,
      scheduleStartMinute: hasSchedule ? _startTime.minute : null,
      scheduleEndHour:     hasSchedule ? _endTime.hour     : null,
      scheduleEndMinute:   hasSchedule ? _endTime.minute   : null,
      scheduleDays: hasSchedule ? selectedDayIndices : [],
    );

    if (existingIdx == -1) {
      await _store.addScene(newScene);
    } else {
      list[existingIdx] = newScene;
      _store.scenes.value = list;
      if (_store.homeId != null) {
        await FirestoreService.instance.addScene(_store.homeId!, newScene);
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scene saved'), backgroundColor: AppColors.green));
    Navigator.pop(context);
  }

  Widget _navBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
