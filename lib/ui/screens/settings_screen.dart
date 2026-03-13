import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/player_controller.dart';
import '../../models/audio_track.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlayerController>();

    if (!_initialized) {
      _initialized = true;
      _startController.text = controller.settings.skipStartSec.toString();
      _endController.text = controller.settings.skipEndSec.toString();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('跳过设置', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: _startController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '跳过开头秒数',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _endController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '跳过结尾秒数',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            final start = int.tryParse(_startController.text.trim()) ?? 0;
            final end = int.tryParse(_endController.text.trim()) ?? 0;
            await controller.updateSkipSettings(
              skipStartSec: start.clamp(0, 3600),
              skipEndSec: end.clamp(0, 3600),
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('设置已保存')));
          },
          child: const Text('保存跳过配置'),
        ),
        const SizedBox(height: 24),
        Text('循环模式', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        DropdownButtonFormField<RepeatModeType>(
          value: controller.settings.repeatMode,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: RepeatModeType.listLoop, child: Text('列表循环')),
            DropdownMenuItem(value: RepeatModeType.single, child: Text('单曲循环')),
            DropdownMenuItem(value: RepeatModeType.shuffle, child: Text('随机播放')),
          ],
          onChanged: (value) {
            if (value != null) {
              controller.updateRepeatMode(value);
            }
          },
        ),
      ],
    );
  }
}

