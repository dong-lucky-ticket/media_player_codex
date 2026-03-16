import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/player_controller.dart';
import '../../models/audio_track.dart';
import '../widgets/app_snack_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.bottomOverlayHeight = 0,
  });

  final double bottomOverlayHeight;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _minDurationController = TextEditingController();

  int? _lastSkipStartSec;
  int? _lastSkipEndSec;
  int? _lastMinScanDurationSec;

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _minDurationController.dispose();
    super.dispose();
  }

  void _syncControllersWithSettings(PlayerSettings settings) {
    if (_lastSkipStartSec != settings.skipStartSec) {
      _startController.text = settings.skipStartSec.toString();
      _lastSkipStartSec = settings.skipStartSec;
    }
    if (_lastSkipEndSec != settings.skipEndSec) {
      _endController.text = settings.skipEndSec.toString();
      _lastSkipEndSec = settings.skipEndSec;
    }
    if (_lastMinScanDurationSec != settings.minScanDurationSec) {
      _minDurationController.text = settings.minScanDurationSec.toString();
      _lastMinScanDurationSec = settings.minScanDurationSec;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlayerController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    _syncControllersWithSettings(controller.settings);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        16 + widget.bottomOverlayHeight,
      ),
      children: [
        _buildSectionCard(
          context,
          icon: Icons.skip_next_rounded,
          title: '跳过设置',
          subtitle: '控制音频开始和结束时自动跳过的秒数。',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildNumberField(
                      context,
                      controller: _startController,
                      label: '开头跳过',
                      hint: '0',
                      suffixText: '秒',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildNumberField(
                      context,
                      controller: _endController,
                      label: '结尾跳过',
                      hint: '0',
                      suffixText: '秒',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    final start =
                        int.tryParse(_startController.text.trim()) ?? 0;
                    final end = int.tryParse(_endController.text.trim()) ?? 0;
                    await controller.updateSkipSettings(
                      skipStartSec: start.clamp(0, 3600),
                      skipEndSec: end.clamp(0, 3600),
                    );
                    if (!mounted) return;
                    showAppSnackBar(
                      context,
                      message: '跳过设置已保存。',
                      isError: false,
                    );
                  },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('保存跳过设置'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    elevation: 0,
                    backgroundColor: scheme.secondaryContainer.withOpacity(0.6),
                    foregroundColor: scheme.onSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          context,
          icon: Icons.filter_alt_outlined,
          title: '扫描过滤',
          subtitle: '扫描时忽略时长低于阈值的音频文件。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNumberField(
                context,
                controller: _minDurationController,
                label: '最小时长',
                hint: '0',
                suffixText: '秒',
              ),
              const SizedBox(height: 8),
              Text(
                '设为 0 表示不过滤。系统媒体库扫描和手动导入都会按这个阈值过滤音频。',
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.45,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    final seconds =
                        int.tryParse(_minDurationController.text.trim()) ?? 0;
                    await controller
                        .updateMinScanDuration(seconds.clamp(0, 3600));
                    if (!mounted) return;
                    showAppSnackBar(
                      context,
                      message: '扫描过滤已保存。',
                      isError: false,
                    );
                  },
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('保存过滤设置'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    elevation: 0,
                    backgroundColor: scheme.secondaryContainer.withOpacity(0.6),
                    foregroundColor: scheme.onSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          context,
          icon: Icons.repeat_rounded,
          title: '循环模式',
          subtitle: '选择播放列表默认的循环方式。',
          child: DropdownButtonFormField<RepeatModeType>(
            value: controller.settings.repeatMode,
            decoration: InputDecoration(
              filled: true,
              fillColor: scheme.surfaceVariant.withOpacity(0.28),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: scheme.outlineVariant.withOpacity(0.28),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: scheme.primary.withOpacity(0.55),
                ),
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: RepeatModeType.listLoop,
                child: Text('列表循环'),
              ),
              DropdownMenuItem(
                value: RepeatModeType.single,
                child: Text('单曲循环'),
              ),
              DropdownMenuItem(
                value: RepeatModeType.shuffle,
                child: Text('随机播放'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                controller.updateRepeatMode(value);
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildHintCard(context),
      ],
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    String? suffixText,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffixText,
        filled: true,
        fillColor: scheme.surfaceVariant.withOpacity(0.28),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withOpacity(0.28),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.primary.withOpacity(0.55),
          ),
        ),
      ),
    );
  }

  Widget _buildHintCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.tips_and_updates_outlined,
              size: 18,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '跳过设置会在播放时自动生效。扫描过滤只影响新的扫描和导入，不会自动移除已在列表中的音频。',
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.45,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
