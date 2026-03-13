import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../controllers/player_controller.dart';
import '../../core/formatters.dart';
import '../../models/audio_track.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.onOpenPermissionGuide});

  final VoidCallback onOpenPermissionGuide;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _lastNoticeToken = 0;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlayerController>();
    final notice = controller.notice;
    final tracks = controller.tracks;
    final trackOrder = <String, int>{
      for (var i = 0; i < tracks.length; i++) tracks[i].path: i + 1,
    };
    final groups = _groupTracks(tracks);

    if (notice != null && notice.token != _lastNoticeToken) {
      _lastNoticeToken = notice.token;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final color = notice.isError
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.primaryContainer;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: color,
            content: Text(notice.message),
          ),
        );
      });
    }

    return Column(
      children: [
        if (!controller.permissionState.scanAvailable)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded),
                title: const Text('自动扫描不可用'),
                subtitle: Text(controller.permissionState.summary),
                trailing: FilledButton.tonal(
                  onPressed: widget.onOpenPermissionGuide,
                  child: const Text('去授权'),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: SizedBox(
            height: 42,
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: '搜索歌曲名称或路径',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: controller.setSearchText,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: controller.scanInProgress ? Icons.stop_circle_outlined : Icons.blur_circular,
                  label: controller.scanInProgress ? '停止扫描' : '扫描',
                  onPressed: controller.scanInProgress
                      ? controller.stopScan
                      : (controller.isWorking ? null : controller.runAutoScan),
                  isDanger: controller.scanInProgress,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.folder_outlined,
                  label: '文件夹',
                  onPressed: controller.isWorking ? null : controller.importFromFolder,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.audio_file_outlined,
                  label: '文件',
                  onPressed: controller.isWorking ? null : controller.importFiles,
                ),
              ),
            ],
          ),
        ),
        if (controller.scanStatusText != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(
              children: [
                Icon(
                  controller.scanInProgress ? Icons.sync_rounded : Icons.info_outline_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    controller.scanStatusText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
        if (controller.isWorking)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: LinearProgressIndicator(
              minHeight: 3,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        const SizedBox(height: 10),
        Expanded(
          child: tracks.isEmpty
              ? const Center(child: Text('暂无音频，请先扫描或导入'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: groups.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildGroupSection(
                    context,
                    controller,
                    groups[index],
                    trackOrder,
                  ),
                ),
        ),
      ],
    );
  }

  List<_TrackGroup> _groupTracks(List<AudioTrack> tracks) {
    final map = <String, List<AudioTrack>>{};
    for (final track in tracks) {
      final folderName = _folderName(track.path);
      map.putIfAbsent(folderName, () => <AudioTrack>[]).add(track);
    }
    return map.entries
        .map((entry) => _TrackGroup(name: entry.key, tracks: entry.value))
        .toList(growable: false);
  }

  String _folderName(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) return '未分类';
    final directory = p.dirname(normalized);
    if (directory.isEmpty || directory == '.' || directory == normalized) {
      return '未分类';
    }
    final name = p.basename(directory);
    return name.isEmpty ? '未分类' : name;
  }

  Widget _buildGroupSection(
    BuildContext context,
    PlayerController controller,
    _TrackGroup group,
    Map<String, int> trackOrder,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.folder_copy_outlined,
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
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${group.tracks.length} 个音频',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ...group.tracks.asMap().entries.map((entry) {
              final track = entry.value;
              final isLast = entry.key == group.tracks.length - 1;
              final serial = trackOrder[track.path] ?? 0;
              final isCurrent = controller.currentMediaItem?.id == track.path;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                child: Dismissible(
                  key: ValueKey(track.path),
                  direction: DismissDirection.endToStart,
                  background: _buildDismissBackground(context),
                  onDismissed: (_) => _handleRemoveTrack(context, controller, track),
                  child: _buildTrackTile(
                    context,
                    track: track,
                    index: serial,
                    isCurrent: isCurrent,
                    onTap: () => controller.playTrackAt(serial - 1),
                    onRemove: () => _handleRemoveTrack(context, controller, track),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRemoveTrack(
    BuildContext context,
    PlayerController controller,
    AudioTrack track,
  ) async {
    await controller.removeTrack(track.path);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('已移除 ${track.title}'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            controller.restoreTrack(track);
          },
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isDanger = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 38,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          elevation: 0,
          backgroundColor: isDanger
              ? scheme.errorContainer.withOpacity(0.9)
              : scheme.secondaryContainer.withOpacity(0.55),
          foregroundColor: isDanger ? scheme.onErrorContainer : scheme.onSurface,
          side: BorderSide(
            color: isDanger
                ? scheme.error.withOpacity(0.35)
                : scheme.outlineVariant.withOpacity(0.45),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildDismissBackground(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Icon(
        Icons.delete_sweep_rounded,
        color: scheme.onErrorContainer,
        size: 22,
      ),
    );
  }

  Widget _buildTrackTile(
    BuildContext context, {
    required AudioTrack track,
    required int index,
    required bool isCurrent,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final duration = track.durationMs > 0 ? Duration(milliseconds: track.durationMs) : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isCurrent ? scheme.primaryContainer.withOpacity(0.55) : scheme.surfaceVariant.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent ? scheme.primary.withOpacity(0.7) : Colors.transparent,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrent ? scheme.primary.withOpacity(0.16) : Colors.black.withOpacity(0.04),
            blurRadius: isCurrent ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                _buildTrackIndex(context, index: index, isCurrent: isCurrent),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                            color: isCurrent ? scheme.onSurface : null,
                          ),
                        ),
                      ),
                      if (duration != null) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: scheme.surface.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: scheme.outlineVariant.withOpacity(0.35)),
                          ),
                          child: Text(
                            formatDuration(duration),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '从列表移除',
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.surface.withOpacity(0.72),
                    side: BorderSide(color: scheme.outlineVariant.withOpacity(0.35)),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackIndex(
    BuildContext context, {
    required int index,
    required bool isCurrent,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isCurrent ? scheme.primary : scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? scheme.primary.withOpacity(0.15) : scheme.outlineVariant.withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$index',
        style: theme.textTheme.labelMedium?.copyWith(
          color: isCurrent ? scheme.onPrimary : scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TrackGroup {
  const _TrackGroup({required this.name, required this.tracks});

  final String name;
  final List<AudioTrack> tracks;
}
