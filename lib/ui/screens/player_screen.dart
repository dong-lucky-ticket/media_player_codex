import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../controllers/player_controller.dart';
import '../../core/formatters.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlayerController>();
    final track = controller.currentTrack;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (track == null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          decoration: BoxDecoration(
            color: scheme.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.library_music_rounded,
                  size: 30,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '还没有正在播放的音频',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '请先在音频列表中选择一首音频开始播放。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final progress = controller.position;
    final duration = controller.currentMediaItem?.duration ??
        (track.durationMs > 0 ? Duration(milliseconds: track.durationMs) : null);
    final max = duration?.inMilliseconds.toDouble() ?? 1;
    final value = progress.inMilliseconds.clamp(0, max.toInt()).toDouble();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        _buildHeaderCard(context, track.title, () {
          _showDetailsSheet(
            context,
            title: track.title,
            album: track.album,
            folder: _folderName(track.path),
            path: track.path,
            duration: duration,
          );
        }),
        const SizedBox(height: 12),
        _buildProgressCard(
          context,
          value: value,
          max: max,
          progress: progress,
          duration: duration,
          onChanged: (v) => controller.seekTo(Duration(milliseconds: v.toInt())),
        ),
        const SizedBox(height: 12),
        _buildControlsCard(context, controller),
      ],
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    String title,
    VoidCallback onShowDetails,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.secondaryContainer.withOpacity(0.72),
                    scheme.primaryContainer.withOpacity(0.58),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.graphic_eq_rounded,
                size: 26,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: '查看详情',
              onPressed: onShowDetails,
              style: IconButton.styleFrom(
                backgroundColor: scheme.surfaceVariant.withOpacity(0.24),
                side: BorderSide(
                  color: scheme.outlineVariant.withOpacity(0.24),
                ),
              ),
              icon: const Icon(Icons.info_outline_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(
    BuildContext context, {
    required double value,
    required double max,
    required Duration progress,
    required Duration? duration,
    required ValueChanged<double> onChanged,
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
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    size: 18,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '播放进度',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${formatDuration(progress)} / ${formatDuration(duration)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                min: 0,
                max: max,
                value: value,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsCard(BuildContext context, PlayerController controller) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final playing = controller.playbackState.playing;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Row(
          children: [
            Expanded(
              child: _buildControlButton(
                context,
                icon: Icons.skip_previous_rounded,
                label: '上一首',
                onPressed: controller.playPrevious,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FilledButton.tonalIcon(
                onPressed: controller.togglePlayPause,
                icon: Icon(
                  playing ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                  size: 24,
                ),
                label: Text(playing ? '暂停播放' : '开始播放'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  elevation: 0,
                  backgroundColor: scheme.secondaryContainer.withOpacity(0.72),
                  foregroundColor: scheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildControlButton(
                context,
                icon: Icons.skip_next_rounded,
                label: '下一首',
                onPressed: controller.playNext,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        elevation: 0,
        backgroundColor: scheme.surfaceVariant.withOpacity(0.32),
        foregroundColor: scheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withOpacity(0.28)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 3),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetailsSheet(
    BuildContext context, {
    required String title,
    required String album,
    required String folder,
    required String path,
    required Duration? duration,
  }) async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(context, label: '名称', value: title),
                const SizedBox(height: 12),
                _buildDetailRow(context, label: '时长', value: formatDuration(duration)),
                const SizedBox(height: 12),
                _buildDetailRow(context, label: '专辑', value: album),
                const SizedBox(height: 12),
                _buildDetailRow(context, label: '文件夹', value: folder),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceVariant.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: scheme.outlineVariant.withOpacity(0.24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '路径',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        path,
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayValue = value.trim().isEmpty || value == 'Unknown' ? '未知' : value;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant.withOpacity(0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayValue,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  String _folderName(String path) {
    final directory = p.dirname(path.trim());
    if (directory.isEmpty || directory == '.' || directory == path) {
      return '未分类';
    }
    final name = p.basename(directory);
    return name.isEmpty ? '未分类' : name;
  }
}
