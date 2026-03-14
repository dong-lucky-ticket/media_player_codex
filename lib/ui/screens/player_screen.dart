import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/player_controller.dart';
import '../../core/formatters.dart';
import '../../core/track_sorter.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  static const _speedOptions = <double>[0.75, 1.0, 1.25, 1.5, 2.0];

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
        (track.durationMs > 0
            ? Duration(milliseconds: track.durationMs)
            : null);
    final max = duration?.inMilliseconds.toDouble() ?? 1;
    final value = progress.inMilliseconds.clamp(0, max.toInt()).toDouble();
    final isPlaying = controller.playbackState.playing;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        _buildHeaderCard(
          context,
          title: track.title,
          isPlaying: isPlaying,
          onShowDetails: () {
            _showDetailsSheet(
              context,
              title: track.title,
              album: track.album,
              folder: folderNameForTrackPath(track.path),
              path: track.path,
              duration: duration,
            );
          },
        ),
        const SizedBox(height: 12),
        _buildProgressCard(
          context,
          value: value,
          max: max,
          progress: progress,
          duration: duration,
          onChanged: (v) =>
              controller.seekTo(Duration(milliseconds: v.toInt())),
        ),
        const SizedBox(height: 10),
        _buildHintStrip(context),
        const SizedBox(height: 10),
        _buildControlsCard(
          context,
          controller,
          onShowDetails: () {
            _showDetailsSheet(
              context,
              title: track.title,
              album: track.album,
              folder: folderNameForTrackPath(track.path),
              path: track.path,
              duration: duration,
            );
          },
          onShowSpeed: () => _showSpeedSheet(context, controller),
          onShowPlaylist: () => _showPlaylistSheet(context, controller),
        ),
      ],
    );
  }

  Widget _buildHeaderCard(
    BuildContext context, {
    required String title,
    required bool isPlaying,
    required VoidCallback onShowDetails,
  }) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                    isPlaying
                        ? Icons.graphic_eq_rounded
                        : Icons.pause_circle_outline_rounded,
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: scheme.surfaceVariant.withOpacity(0.18),
                borderRadius: BorderRadius.circular(999),
                border:
                    Border.all(color: scheme.outlineVariant.withOpacity(0.22)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isPlaying ? '正在播放' : '当前已暂停',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
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

  Widget _buildHintStrip(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 17,
            color: scheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '可调整播放速率，也可以随时展开播放列表快速切歌。',
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.35,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsCard(
    BuildContext context,
    PlayerController controller, {
    required VoidCallback onShowDetails,
    required VoidCallback onShowSpeed,
    required VoidCallback onShowPlaylist,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final playing = controller.playbackState.playing;
    final speedText =
        '${controller.playbackSpeed.toStringAsFixed(controller.playbackSpeed % 1 == 0 ? 0 : 2)}x';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildControlButton(
                    context,
                    icon: Icons.speed_rounded,
                    label: speedText,
                    onPressed: onShowSpeed,
                  ),
                ),
                const SizedBox(width: 8),
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
                      playing
                          ? Icons.pause_circle_rounded
                          : Icons.play_circle_rounded,
                      size: 24,
                    ),
                    label: Text(playing ? '暂停播放' : '开始播放'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      elevation: 0,
                      backgroundColor:
                          scheme.secondaryContainer.withOpacity(0.72),
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
                const SizedBox(width: 8),
                Expanded(
                  child: _buildControlButton(
                    context,
                    icon: Icons.queue_music_rounded,
                    label: '列表',
                    onPressed: onShowPlaylist,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onShowDetails,
                icon: const Icon(Icons.info_outline_rounded, size: 18),
                label: const Text('查看当前音频详情'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  foregroundColor: scheme.onSurfaceVariant,
                  side: BorderSide(
                      color: scheme.outlineVariant.withOpacity(0.24)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSpeedSheet(
      BuildContext context, PlayerController controller) async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = controller.playbackSpeed;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final speed in _speedOptions)
                  ChoiceChip(
                    label: Text(
                        '${speed.toStringAsFixed(speed % 1 == 0 ? 0 : 2)}x'),
                    selected: (current - speed).abs() < 0.01,
                    onSelected: (_) {
                      controller.updatePlaybackSpeed(speed);
                      Navigator.of(context).pop();
                    },
                    labelStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: (current - speed).abs() < 0.01
                          ? scheme.onSecondaryContainer
                          : scheme.onSurface,
                    ),
                    selectedColor: scheme.secondaryContainer,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPlaylistSheet(
      BuildContext context, PlayerController controller) async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tracks = controller.activePlaylist;
    final currentPlaylistIndex = controller.currentPlaylistIndex;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.66,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        '播放列表',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${tracks.length} 首',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    itemCount: tracks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      final isCurrent = index == currentPlaylistIndex;
                      return Material(
                        color: isCurrent
                            ? scheme.primaryContainer.withOpacity(0.5)
                            : scheme.surfaceVariant.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            final navigator = Navigator.of(context);
                            await controller.playTrackAt(index);
                            navigator.pop();
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? scheme.primary
                                        : scheme.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isCurrent
                                          ? scheme.primary.withOpacity(0.15)
                                          : scheme.outlineVariant
                                              .withOpacity(0.35),
                                    ),
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: isCurrent
                                          ? scheme.onPrimary
                                          : scheme.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  formatDuration(
                                    track.durationMs > 0
                                        ? Duration(
                                            milliseconds: track.durationMs)
                                        : null,
                                  ),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
                _buildDetailRow(context,
                    label: '时长', value: formatDuration(duration)),
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
    final displayValue =
        value.trim().isEmpty || value == 'Unknown' ? '未知' : value;

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
}
