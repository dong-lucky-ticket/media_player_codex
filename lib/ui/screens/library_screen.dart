import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/player_controller.dart';
import '../../core/formatters.dart';
import '../../core/track_sorter.dart';
import '../../models/audio_track.dart';
import '../widgets/app_snack_bar.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.onOpenPermissionGuide});

  final VoidCallback onOpenPermissionGuide;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  static const _scrollToTopThreshold = 320.0;

  int _lastNoticeToken = 0;
  late final ScrollController _scrollController;
  bool _showScrollToTopButton = false;
  List<AudioTrack>? _lastTracksSource;
  List<_TrackGroup>? _lastTrackGroups;
  List<AudioTrack>? _lastAllTracksSource;
  List<_TrackGroup>? _lastAllTrackGroups;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final shouldShow = _scrollController.offset >= _scrollToTopThreshold;
    if (shouldShow == _showScrollToTopButton) return;
    setState(() {
      _showScrollToTopButton = shouldShow;
    });
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<PlayerController>();
    final notice = context.select((PlayerController c) => c.notice);
    final tracks = context.select((PlayerController c) => c.tracks);
    final allTracks = context.select((PlayerController c) => c.allTracks);
    final scanInProgress =
        context.select((PlayerController c) => c.scanInProgress);
    final isWorking = context.select((PlayerController c) => c.isWorking);
    final scanStatusText =
        context.select((PlayerController c) => c.scanStatusText);
    final permissionState =
        context.select((PlayerController c) => c.permissionState);
    final currentMediaId =
        context.select((PlayerController c) => c.currentMediaItem?.id);
    final _ = context.select((PlayerController c) => c.unplayableVersion);

    final groups = _groupTracksCached(tracks, useAllTracksCache: false);
    final allGroups = _groupTracksCached(allTracks, useAllTracksCache: true);
    final allGroupsByName = {
      for (final group in allGroups) group.name: group.tracks,
    };

    if (notice != null && notice.token != _lastNoticeToken) {
      _lastNoticeToken = notice.token;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final isPermissionNotice = !permissionState.scanAvailable &&
            notice.message == permissionState.summary;
        if (isPermissionNotice) return;
        showAppSnackBar(
          context,
          message: notice.message,
          isError: notice.isError,
        );
      });
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: SizedBox(
            height: 42,
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText:
                    '搜索歌曲名称或路径',
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.35),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
                  icon: scanInProgress
                      ? Icons.stop_circle_outlined
                      : Icons.blur_circular,
                  label: scanInProgress
                      ? '停止自动扫描'
                      : '自动扫描',
                  onPressed: scanInProgress
                      ? controller.stopScan
                      : (isWorking ? null : controller.runAutoScan),
                  isDanger: scanInProgress,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.folder_outlined,
                  label: '导入文件夹',
                  onPressed:
                      isWorking ? null : controller.importFromFolder,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.audio_file_outlined,
                  label: '导入文件',
                  onPressed:
                      isWorking ? null : controller.importFiles,
                ),
              ),
            ],
          ),
        ),
        if (scanStatusText != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(
              children: [
                Icon(
                  scanInProgress
                      ? Icons.sync_rounded
                      : Icons.info_outline_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    scanStatusText,
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
        if (isWorking)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: LinearProgressIndicator(
              minHeight: 3,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        const SizedBox(height: 10),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: tracks.isEmpty
                    ? Padding(
                        padding: EdgeInsets.only(
                          bottom: permissionState.scanAvailable
                              ? 0
                              : 124,
                        ),
                        child: const Center(
                            child: Text(
                                '暂无音频，请先扫描或导入')),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          12,
                          0,
                          12,
                          permissionState.scanAvailable ? 12 : 136,
                        ),
                        itemCount: groups.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) => _buildGroupSection(
                          context,
                          controller,
                          groups[index],
                          allGroupsByName,
                          currentMediaId,
                        ),
                      ),
              ),
              if (_showScrollToTopButton)
                Positioned(
                  right: 16,
                  bottom: permissionState.scanAvailable ? 16 : 140,
                  child: FloatingActionButton.small(
                    heroTag: 'library_scroll_to_top',
                    onPressed: _scrollToTop,
                    child: const Icon(Icons.keyboard_arrow_up_rounded),
                  ),
                ),
              if (!permissionState.scanAvailable)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _buildPermissionFloatingCard(
                    context,
                    summary: permissionState.summary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<_TrackGroup> _groupTracksCached(
    List<AudioTrack> tracks, {
    required bool useAllTracksCache,
  }) {
    final cachedSource =
        useAllTracksCache ? _lastAllTracksSource : _lastTracksSource;
    final cachedGroups =
        useAllTracksCache ? _lastAllTrackGroups : _lastTrackGroups;
    if (identical(cachedSource, tracks) && cachedGroups != null) {
      return cachedGroups;
    }

    final groups = _groupTracks(tracks);
    if (useAllTracksCache) {
      _lastAllTracksSource = tracks;
      _lastAllTrackGroups = groups;
    } else {
      _lastTracksSource = tracks;
      _lastTrackGroups = groups;
    }
    return groups;
  }

  List<_TrackGroup> _groupTracks(List<AudioTrack> tracks) {
    final map = <String, List<AudioTrack>>{};
    for (final track in tracks) {
      final folderName = folderNameForTrackPath(track.path);
      map.putIfAbsent(folderName, () => <AudioTrack>[]).add(track);
    }

    final entries = map.entries.toList(growable: false)
      ..sort((a, b) => compareNaturalText(a.key, b.key));

    return entries
        .map(
          (entry) => _TrackGroup(
            name: entry.key,
            tracks: sortTracksByFolder(entry.value),
          ),
        )
        .toList(growable: false);
  }

  Widget _buildGroupSection(
    BuildContext context,
    PlayerController controller,
    _TrackGroup group,
    Map<String, List<AudioTrack>> allGroupsByName,
    String? currentMediaId,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final folderTracks = allGroupsByName[group.name] ?? group.tracks;
    final playIndexByPath = <String, int>{
      for (var i = 0; i < folderTracks.length; i++) folderTracks[i].path: i,
    };

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
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${folderTracks.length} 个音频',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '追加到播放列表末尾',
                    onPressed: () =>
                        controller.appendFolderTracks(group.name, folderTracks),
                    icon: Icon(
                      Icons.playlist_add_rounded,
                      size: 20,
                      color: scheme.primary.withOpacity(0.82),
                    ),
                    visualDensity: VisualDensity.compact,
                    splashRadius: 20,
                  ),
                  IconButton(
                    tooltip: '删除此文件夹下全部音频',
                    onPressed: () =>
                        _handleRemoveGroup(context, controller, group),
                    icon: Icon(
                      Icons.delete_sweep_rounded,
                      size: 20,
                      color: scheme.error.withOpacity(0.82),
                    ),
                    visualDensity: VisualDensity.compact,
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            ...group.tracks.asMap().entries.map((entry) {
              final track = entry.value;
              final isLast = entry.key == group.tracks.length - 1;
              final serial = entry.key + 1;
              final playIndex = playIndexByPath[track.path] ?? -1;
              final isCurrent = currentMediaId == track.path;
              final isUnplayable = controller.isTrackUnplayable(track.path);
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                child: Dismissible(
                  key: ValueKey(track.path),
                  direction: DismissDirection.endToStart,
                  background: _buildDismissBackground(context),
                  onDismissed: (_) =>
                      _handleRemoveTrack(context, controller, track),
                  child: _buildTrackTile(
                    context,
                    track: track,
                    index: serial,
                    isCurrent: isCurrent,
                    isUnplayable: isUnplayable,
                    onTap: playIndex < 0
                        ? null
                        : () =>
                            controller.playFolderTrack(folderTracks, playIndex),
                    onLongPress: () =>
                        _showTrackDetailsDialog(context, track, serial),
                    onRemove: () =>
                        _handleRemoveTrack(context, controller, track),
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

    showAppSnackBar(
      context,
      message: '已移除 ${track.title}',
      isError: false,
      actionLabel: '撤销',
      onAction: () {
        controller.restoreTrack(track);
      },
    );
  }

  Future<void> _handleRemoveGroup(
    BuildContext context,
    PlayerController controller,
    _TrackGroup group,
  ) async {
    final removedTracks = List<AudioTrack>.from(group.tracks);
    await controller.removeTracks(removedTracks);
    if (!mounted) return;

    showAppSnackBar(
      context,
      message:
          '已移除 ${group.name} 下的 ${removedTracks.length} 项',
      isError: false,
      actionLabel: '撤销',
      onAction: () {
        controller.restoreTracks(removedTracks);
      },
    );
  }

  Future<void> _showTrackDetailsDialog(
    BuildContext context,
    AudioTrack track,
    int index,
  ) async {
    final duration =
        track.durationMs > 0 ? Duration(milliseconds: track.durationMs) : null;
    final folder = folderNameForTrackPath(track.path);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('音频详情 #$index'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('标题', track.title),
                _buildDetailRow('时长', formatDuration(duration)),
                _buildDetailRow('艺术家', track.artist),
                _buildDetailRow('专辑', track.album),
                _buildDetailRow('文件夹', folder),
                _buildDetailRow('路径', track.path),
                if (track.artUri != null && track.artUri!.isNotEmpty)
                  _buildDetailRow('封面 URI', track.artUri!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          SelectableText(value),
        ],
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
          foregroundColor:
              isDanger ? scheme.onErrorContainer : scheme.onSurface,
          side: BorderSide(
            color: isDanger
                ? scheme.error.withOpacity(0.35)
                : scheme.outlineVariant.withOpacity(0.45),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
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
    required bool isUnplayable,
    required VoidCallback? onTap,
    required VoidCallback onLongPress,
    required VoidCallback onRemove,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final duration =
        track.durationMs > 0 ? Duration(milliseconds: track.durationMs) : null;

    return Container(
      decoration: BoxDecoration(
        color: isCurrent
            ? scheme.primaryContainer.withOpacity(0.55)
            : scheme.surfaceVariant.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isCurrent ? scheme.primary.withOpacity(0.7) : Colors.transparent,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrent
                ? scheme.primary.withOpacity(0.16)
                : Colors.black.withOpacity(0.04),
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
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                _buildTrackIndex(
                  context,
                  index: index,
                  isCurrent: isCurrent,
                ),
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
                      if (isUnplayable) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: scheme.error.withOpacity(0.24),
                            ),
                          ),
                          child: Text(
                            '已移除',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                      if (duration != null) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surface.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: scheme.outlineVariant.withOpacity(0.35),
                            ),
                          ),
                          child: Text(
                            formatDuration(duration),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isUnplayable
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
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
                    side: BorderSide(
                      color: scheme.outlineVariant.withOpacity(0.35),
                    ),
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
          color: isCurrent
              ? scheme.primary.withOpacity(0.15)
              : scheme.outlineVariant.withOpacity(0.5),
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

  Widget _buildPermissionFloatingCard(
    BuildContext context, {
    required String summary,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6F1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8CFC1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE6D8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 20,
                color: Color(0xFF9A4F2B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '自动扫描不可用',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF7D3E1F),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.4,
                      color: const Color(0xFF8D5A43),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonalIcon(
              onPressed: widget.onOpenPermissionGuide,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('前往设置'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                elevation: 0,
                backgroundColor: scheme.surface,
                foregroundColor: const Color(0xFF7D3E1F),
                side: const BorderSide(color: Color(0xFFE8CFC1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }
}

class _TrackGroup {
  const _TrackGroup({required this.name, required this.tracks});

  final String name;
  final List<AudioTrack> tracks;
}
