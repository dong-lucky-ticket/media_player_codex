import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/player_controller.dart';
import '../../core/formatters.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlayerController>();
    final track = controller.currentTrack;

    if (track == null) {
      return const Center(child: Text('请选择要播放的音频'));
    }

    final progress = controller.position;
    final duration = controller.currentMediaItem?.duration ??
        (track.durationMs > 0 ? Duration(milliseconds: track.durationMs) : null);
    final max = duration?.inMilliseconds.toDouble() ?? 1;
    final value = progress.inMilliseconds.clamp(0, max.toInt()).toDouble();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.album, size: 120),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            track.title,
            style: Theme.of(context).textTheme.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            track.artist,
            style: Theme.of(context).textTheme.bodyLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Slider(
            min: 0,
            max: max,
            value: value,
            onChanged: (v) => controller.seekTo(Duration(milliseconds: v.toInt())),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatDuration(progress)),
              Text(formatDuration(duration)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 36,
                onPressed: controller.playPrevious,
                icon: const Icon(Icons.skip_previous),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: controller.togglePlayPause,
                child: Icon(
                  controller.playbackState.playing ? Icons.pause : Icons.play_arrow,
                  size: 36,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                iconSize: 36,
                onPressed: controller.playNext,
                icon: const Icon(Icons.skip_next),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

