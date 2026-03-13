import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/player_controller.dart';
import '../../core/formatters.dart';

class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({
    super.key,
    required this.onOpenPlayer,
    required this.onClose,
  });

  final VoidCallback onOpenPlayer;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlayerController>();
    final item = controller.currentMediaItem;
    if (item == null) return const SizedBox.shrink();

    final duration = item.duration;
    final progress = controller.position;
    final max = (duration?.inMilliseconds ?? 1).toDouble();
    final value = progress.inMilliseconds.clamp(0, max.toInt()).toDouble();
    final scheme = Theme.of(context).colorScheme;

    ButtonStyle compactIconButtonStyle() {
      return IconButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(38, 38),
        padding: const EdgeInsets.all(3),
        iconSize: 22,
        foregroundColor: scheme.onSurface,
      );
    }

    return Material(
      elevation: 11,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: onOpenPlayer,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      IconButton(
                        tooltip: '播放/暂停',
                        style: compactIconButtonStyle(),
                        onPressed: controller.togglePlayPause,
                        icon: Icon(
                          controller.playbackState.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                      IconButton(
                        tooltip: '下一首',
                        style: compactIconButtonStyle(),
                        onPressed: controller.playNext,
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        style: compactIconButtonStyle(),
                        onPressed: onClose,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onOpenPlayer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2.6,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          ),
                          child: Slider(
                            min: 0,
                            max: max,
                            value: value,
                            onChanged: (v) =>
                                controller.seekTo(Duration(milliseconds: v.toInt())),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${formatDuration(progress)} / ${formatDuration(duration)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
