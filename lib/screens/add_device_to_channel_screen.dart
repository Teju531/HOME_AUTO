import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/app_store.dart';

class AddDeviceToChannelScreen extends StatefulWidget {
  const AddDeviceToChannelScreen({super.key});
  @override
  State<AddDeviceToChannelScreen> createState() => _AddDeviceToChannelScreenState();
}

class _AddDeviceToChannelScreenState extends State<AddDeviceToChannelScreen> {
  final _store = AppStore.instance;
  final _nameCtrl = TextEditingController();
  int _selectedPlug = 1;
  int _selectedChannelIdx = 0;
  IconData _selectedIcon = Icons.lightbulb_outline;

  static const List<IconData> _icons = [
    Icons.lightbulb_outline, Icons.air, Icons.desktop_windows, Icons.tv,
    Icons.kitchen, Icons.hot_tub, Icons.microwave, Icons.blender,
    Icons.local_laundry_service, Icons.speaker,
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    String? preselectedChannel = args is String ? args : null;

    return ValueListenableBuilder<List<ChannelItem>>(
      valueListenable: _store.channels,
      builder: (context, channels, _) {
        if (channels.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Add device to Channel')),
            body: const Center(child: Text('No channels available. Add a channel first.')),
          );
        }

        if (preselectedChannel != null) {
          final idx = channels.indexWhere((c) => c.name == preselectedChannel);
          if (idx != -1) _selectedChannelIdx = idx;
        }

        final selectedChannel = channels[_selectedChannelIdx];

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    // ── App Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primaryDark, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Expanded(
                            child: Text('Add device to Channel', textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.primaryDark, fontSize: 17, fontWeight: FontWeight.w700)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Done', style: TextStyle(color: AppColors.primaryDark, fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'You can add more than one device at a time, just choose the channel, provide device name, choose device icon and save it.',
                              style: TextStyle(color: AppColors.textLight, fontSize: 12, fontStyle: FontStyle.italic, height: 1.4),
                            ),
                            const SizedBox(height: 20),

                            // ── Device Name + Icon
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Provide Device Name',
                                          style: TextStyle(color: AppColors.textLight, fontSize: 14)),
                                      TextField(
                                        controller: _nameCtrl,
                                        style: const TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w600),
                                        decoration: const InputDecoration(
                                          hintText: 'Fan',
                                          hintStyle: TextStyle(color: AppColors.grey),
                                          border: UnderlineInputBorder(),
                                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.lightGrey)),
                                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                GestureDetector(
                                  onTap: _pickIcon,
                                  child: Container(
                                    width: 60, height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.primary, width: 1.5),
                                    ),
                                    child: Icon(_selectedIcon, color: AppColors.primary, size: 28),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // ── Channel + Plug dropdowns
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Choose Channel',
                                          style: TextStyle(color: AppColors.textLight, fontSize: 14)),
                                      DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: _selectedChannelIdx,
                                          isExpanded: true,
                                          style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600),
                                          items: List.generate(channels.length, (i) =>
                                              DropdownMenuItem(value: i, child: Text(channels[i].name))),
                                          onChanged: (v) => setState(() { _selectedChannelIdx = v!; _selectedPlug = 1; }),
                                        ),
                                      ),
                                      const Divider(color: AppColors.lightGrey, height: 1),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Choose Plug',
                                          style: TextStyle(color: AppColors.textLight, fontSize: 14)),
                                      DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: _selectedPlug,
                                          isExpanded: true,
                                          style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600),
                                          items: List.generate(4, (i) {
                                            final plugLabel = 'Plug ${i + 1}';
                                            final count = channels[_selectedChannelIdx].devices
                                                .where((d) => d.plug == plugLabel).length;
                                            final isFull = count >= 2;
                                            return DropdownMenuItem(
                                              value: i + 1,
                                              child: Row(children: [
                                                Text('Plug ${i + 1}'),
                                                const SizedBox(width: 6),
                                                Text(
                                                  isFull ? '(full)' : '($count/2)',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isFull ? AppColors.red : AppColors.textLight,
                                                  ),
                                                ),
                                              ]),
                                            );
                                          }),
                                          onChanged: (v) => setState(() => _selectedPlug = v!),
                                        ),
                                      ),
                                      const Divider(color: AppColors.lightGrey, height: 1),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // ── Save button
                            GradientButton(text: 'Save', onPressed: _save),
                            const SizedBox(height: 28),

                            // ── Devices list
                            Row(
                              children: [
                                const Icon(Icons.power, color: AppColors.primaryDark, size: 18),
                                const SizedBox(width: 6),
                                Text('Devices in ${selectedChannel.name}',
                                    style: const TextStyle(color: AppColors.primaryDark, fontSize: 15, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('List of all devices in this channel. Slide left to remove device.',
                                style: const TextStyle(color: AppColors.textLight, fontSize: 12, fontStyle: FontStyle.italic)),
                            const SizedBox(height: 12),
                            if (selectedChannel.devices.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: Text('No devices yet. Add one above.',
                                      style: TextStyle(color: AppColors.textLight, fontSize: 13)),
                                ),
                              )
                            else
                              ...selectedChannel.devices.asMap().entries.map((e) =>
                                  _dismissibleDevice(e.value, e.key, selectedChannel.name)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dismissibleDevice(DeviceItem d, int idx, String channelName) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key('${channelName}_${d.plug}'),
        background: Container(
          decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(14)),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 16),
          child: const Icon(Icons.edit, color: Colors.white),
        ),
        secondaryBackground: Container(
          decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(14)),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (dir) {
          if (dir == DismissDirection.endToStart) {
            final list = List<ChannelItem>.from(_store.channels.value);
            final ci = list.indexWhere((c) => c.name == channelName);
            if (ci != -1) {
              final devs = List<DeviceItem>.from(list[ci].devices)..removeAt(idx);
              list[ci] = list[ci].copyWith(devices: devs);
              _store.channels.value = list;
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 4)],
          ),
          child: Row(
            children: [
              Icon(d.icon, color: AppColors.primaryMid, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(d.name, style: const TextStyle(color: AppColors.primaryMid, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      PlugTag(d.plug),
                    ]),
                    const SizedBox(height: 2),
                    const Text('Slide left to delete, slide right to edit.',
                        style: TextStyle(color: AppColors.textLight, fontSize: 11, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a device name')));
      return;
    }
    final channels = _store.channels.value;
    final ch = channels[_selectedChannelIdx];
    final plugLabel = 'Plug $_selectedPlug';

    // Rule 1: same name + same plug not allowed
    if (ch.devices.any((d) => d.name.toLowerCase() == name.toLowerCase() && d.plug == plugLabel)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$name" already exists on $plugLabel.'), backgroundColor: AppColors.red));
      return;
    }

    // Rule 2: max 2 devices per plug
    final devicesOnPlug = ch.devices.where((d) => d.plug == plugLabel).length;
    if (devicesOnPlug >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$plugLabel already has 2 devices. Max 2 per plug.'), backgroundColor: AppColors.red));
      return;
    }

    _store.addDeviceToChannel(ch.name, DeviceItem(
      name: name, channelName: ch.name, plug: plugLabel, icon: _selectedIcon,
    ));
    _nameCtrl.clear();
    setState(() => _selectedPlug = 1);
  }

  void _pickIcon() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 12, crossAxisSpacing: 12),
          itemCount: _icons.length,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () { setState(() => _selectedIcon = _icons[i]); Navigator.pop(context); },
            child: Container(
              decoration: BoxDecoration(
                color: _selectedIcon == _icons[i] ? AppColors.primary.withOpacity(0.1) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _selectedIcon == _icons[i] ? AppColors.primary : AppColors.lightGrey),
              ),
              child: Icon(_icons[i], color: AppColors.primaryMid, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
