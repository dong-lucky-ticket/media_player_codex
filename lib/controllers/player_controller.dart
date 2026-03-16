import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import '../models/audio_track.dart';
import '../repositories/library_repository.dart';
import '../services/audio_import_service.dart';
import '../services/player_audio_handler.dart';

class UiNotice {
  const UiNotice({
    required this.token,
    required this.message,
    required this.isError,
  });

  final int token;
  final String message;
  final bool isError;
}

class PlayerController extends ChangeNotifier {
  PlayerController({
    required LibraryRepository repository,
    required PlayerAudioHandler audioHandler,
    required AudioImportService importService,
  })  : _repository = repository,
        _audioHandler = audioHandler,
        _importService = importService;

  final LibraryRepository _repository;
  final PlayerAudioHandler _audioHandler;
  final AudioImportService _importService;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  List<AudioTrack> _tracks = const [];
  List<AudioTrack> _activePlaylist = const [];
  String _searchText = '';
  bool _isBusy = false;
  bool _scanInProgress = false;
  bool _scanCancelRequested = false;
  String? _scanStatusText;
  int _scanTaskId = 0;
  final Set<String> _unplayablePaths = <String>{};
  final Set<String> _playedPlaylistPaths = <String>{};
  int _unplayableVersion = 0;
  int _playedPlaylistVersion = 0;
  PlayerSettings _settings = const PlayerSettings();
  MediaItem? _currentMediaItem;
  PlaybackState _playbackState = PlaybackState();
  Duration _position = Duration.zero;
  PermissionGuideState _permissionState = const PermissionGuideState(
    missingPermissions: [],
    scanAvailable: true,
    summary: '',
  );
  UiNotice? _notice;
  int _noticeToken = 0;
  String? _pendingRestoreTrackPath;
  int _pendingRestorePositionMs = 0;
  Timer? _playbackStateSaveTimer;
  DateTime? _lastPlaybackStateSavedAt;
  Future<void>? _initFuture;
  bool _audioStreamsBound = false;

  static const _playbackStateSaveInterval = Duration(seconds: 2);

  List<AudioTrack> get tracks {
    if (_searchText.trim().isEmpty) return _tracks;
    final keyword = _searchText.toLowerCase();
    return _tracks
        .where((track) =>
            track.title.toLowerCase().contains(keyword) ||
            track.path.toLowerCase().contains(keyword))
        .toList(growable: false);
  }

  List<AudioTrack> get allTracks => _tracks;
  List<AudioTrack> get activePlaylist => _activePlaylist;

  bool get isBusy => _isBusy;
  bool get scanInProgress => _scanInProgress;
  bool get canStopScan => _scanInProgress;
  bool get isWorking => _isBusy || _scanInProgress;
  String? get scanStatusText => _scanStatusText;
  PlayerSettings get settings => _settings;
  PlaybackState get playbackState => _playbackState;
  MediaItem? get currentMediaItem => _currentMediaItem;
  Duration get position => _position;
  double get playbackSpeed =>
      _playbackState.speed <= 0 ? 1.0 : _playbackState.speed;
  PermissionGuideState get permissionState => _permissionState;
  UiNotice? get notice => _notice;
  int get unplayableVersion => _unplayableVersion;
  int get playedPlaylistVersion => _playedPlaylistVersion;

  bool isTrackUnplayable(String path) => _unplayablePaths.contains(path);
  bool isTrackPlayedInActivePlaylist(String path) =>
      _playedPlaylistPaths.contains(path);

  int? get currentIndex {
    final currentId = _currentMediaItem?.id;
    if (currentId == null) return null;
    final index = _tracks.indexWhere((track) => track.path == currentId);
    return index == -1 ? null : index;
  }

  int? get currentPlaylistIndex {
    final currentId = _currentMediaItem?.id;
    if (currentId == null) return null;
    final index =
        _activePlaylist.indexWhere((track) => track.path == currentId);
    return index == -1 ? null : index;
  }

  AudioTrack? get currentTrack {
    final index = currentIndex;
    if (index == null || index < 0 || index >= _tracks.length) return null;
    return _tracks[index];
  }

  // Keep initialization idempotent so re-entering the bootstrap flow does not bind streams twice.
  // 保持初始化幂等，避免重新进入启动流程时重复绑定流。
  Future<void> init() {
    final pending = _initFuture;
    if (pending != null) return pending;

    final future = _initImpl();
    _initFuture = future;
    return future;
  }

  // Run the real startup sequence once and cache the resulting Future in init().
  // 真正的启动流程只执行一次，并由 init() 缓存返回的 Future。
  Future<void> _initImpl() async {
    try {
      _settings = await _repository.getSettings();
      _permissionState = await _importService.getPermissionGuideState();
      _tracks = await _repository.getAllTracks();

      if (_tracks.isEmpty && !_permissionState.scanAvailable) {
        _pushNotice(_permissionState.summary, isError: true);
      }

      await _audioHandler.applySettings(_settings);

      // Audio streams are wired once because they live for the entire app session.
      // 音频流只绑定一次，因为它们会贯穿整个应用会话。
      if (!_audioStreamsBound) {
        _audioStreamsBound = true;
        _subscriptions
          // Persist playback state from all three streams because each one can change
          // 需要同时监听这三个流并持久化播放状态，因为它们的变化彼此独立。
          // independently depending on how audio_service/just_audio emits updates.
          // 具体会怎么变化取决于 audio_service/just_audio 的事件发射方式。
          ..add(_audioHandler.mediaItem.listen((item) {
            _currentMediaItem = item;
            _schedulePlaybackStateSave();
            notifyListeners();
          }))
          ..add(_audioHandler.playbackState.listen((state) {
            _playbackState = state;
            _schedulePlaybackStateSave();
            notifyListeners();
          }))
          ..add(_audioHandler.positionStream.listen((position) {
            _position = position;
            _schedulePlaybackStateSave();
            notifyListeners();
          }))
          ..add(_audioHandler.completedTrackStream.listen((path) {
            if (_playedPlaylistPaths.add(path)) {
              _playedPlaylistVersion += 1;
              unawaited(_savePlaybackState(force: true));
            }
            notifyListeners();
          }));
      }

      try {
        // Restore is time-bounded so a malformed cached queue cannot block startup.
        // 恢复流程加上超时限制，避免损坏的缓存队列卡住启动过程。
        await _restoreStoredPlaybackState().timeout(const Duration(seconds: 3));
      } catch (_) {
        // Drop broken cached playback state instead of blocking the whole app launch.
        // 缓存播放状态损坏时直接丢弃，避免整个应用启动被卡住。
        _activePlaylist = const [];
        _pendingRestoreTrackPath = null;
        _pendingRestorePositionMs = 0;
        await _repository.clearStoredPlaybackState();
        await _audioHandler.setTracks(_activePlaylist, preserveIndex: false);
        _pushNotice('启动时恢复播放列表失败，已跳过缓存恢复。', isError: true);
      }
      notifyListeners();
    } catch (_) {
      // Allow a later retry if startup fails before the controller reaches a stable state.
      // 如果启动在进入稳定状态前失败，允许后续再次重试。
      _initFuture = null;
      rethrow;
    }
  }

  void setSearchText(String value) {
    _searchText = value;
    notifyListeners();
  }

  // Probe lightweight dependencies that should always respond when the app is healthy.
  // 探测健康状态下应该始终能响应的轻量依赖。
  Future<bool> performForegroundHealthCheck() async {
    try {
      await _repository.getSettings();
      await _audioHandler.performHealthCheck();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> runAutoScan() async {
    if (_scanInProgress || _isBusy) return;

    final taskId = ++_scanTaskId;
    _scanInProgress = true;
    _scanCancelRequested = false;
    _scanStatusText = '正在扫描系统媒体库...';
    notifyListeners();

    try {
      final result = await _importService.autoScan(
        isCancelled: () => _scanCancelRequested || taskId != _scanTaskId,
        minDurationMs: _settings.minScanDurationSec * 1000,
      );

      if (taskId != _scanTaskId || _scanCancelRequested || result.cancelled) {
        _pushNotice('已停止扫描。', isError: false);
        return;
      }

      if (result.tracks.isNotEmpty) {
        await _repository.upsertTracks(result.tracks);
      }
      await _repository
          .removeTracksBelowDuration(_settings.minScanDurationSec * 1000);
      await _reloadTracks();
      _permissionState = await _importService.getPermissionGuideState();
      if (result.message != null) {
        _pushNotice(result.message!,
            isError: result.failed || result.permissionDenied);
      }
    } catch (_) {
      _pushNotice('扫描失败，请稍后重试。', isError: true);
    } finally {
      if (taskId == _scanTaskId) {
        _scanInProgress = false;
        _scanCancelRequested = false;
        _scanStatusText = null;
        notifyListeners();
      }
    }
  }

  void stopScan() {
    if (!_scanInProgress) return;
    _scanCancelRequested = true;
    _scanTaskId += 1;
    _scanInProgress = false;
    _scanStatusText = null;
    _pushNotice('已停止扫描。', isError: false);
  }

  Future<void> importFromFolder() async {
    if (_scanInProgress) return;
    await _runBusyTask(() async {
      final result = await _importService.pickFolderAndScan(
        minDurationMs: _settings.minScanDurationSec * 1000,
        onProgress: (progress) {
          _scanStatusText =
              'Scanned ${progress.processedCount} items, found ${progress.foundCount} audio files.';
          notifyListeners();
        },
      );
      if (result.tracks.isNotEmpty) {
        await _repository.upsertTracks(result.tracks);
      }
      await _repository
          .removeTracksBelowDuration(_settings.minScanDurationSec * 1000);
      await _reloadTracks();
      if (result.message != null && !result.cancelled) {
        _pushNotice(result.message!,
            isError: result.failed || result.permissionDenied);
      }
    });
  }

  Future<void> importFiles() async {
    if (_scanInProgress) return;
    await _runBusyTask(() async {
      final result = await _importService.pickFiles(
        minDurationMs: _settings.minScanDurationSec * 1000,
      );
      if (result.tracks.isNotEmpty) {
        await _repository.upsertTracks(result.tracks);
      }
      await _repository
          .removeTracksBelowDuration(_settings.minScanDurationSec * 1000);
      await _reloadTracks();
      if (result.message != null && !result.cancelled) {
        _pushNotice(result.message!,
            isError: result.failed || result.permissionDenied);
      }
    });
  }

  Future<void> requestPermissionsFromGuide() async {
    await _runBusyTask(() async {
      _permissionState = await _importService.requestScanPermissions();
      _pushNotice(
        _permissionState.summary,
        isError: !_permissionState.scanAvailable,
      );
    });
  }

  Future<void> refreshPermissionState() async {
    _permissionState = await _importService.getPermissionGuideState();
    notifyListeners();
  }

  Future<void> openSystemSettings() async {
    final opened = await _importService.openPermissionSettings();
    _pushNotice(
      opened ? '已打开系统设置，请授权后返回应用并刷新状态。' : '无法打开系统设置，请手动前往设置授权。',
      isError: !opened,
    );
  }

  Future<void> removeTrack(String path) async {
    await _repository.removeTrack(path);
    await _reloadTracks();
  }

  Future<void> removeTracks(List<AudioTrack> tracks) async {
    if (tracks.isEmpty) return;
    await _repository.removeTracks(tracks.map((track) => track.path).toList());
    await _reloadTracks();
  }

  Future<void> restoreTrack(AudioTrack track) async {
    await _repository.upsertTracks([track]);
    await _reloadTracks();
  }

  Future<void> restoreTracks(List<AudioTrack> tracks) async {
    if (tracks.isEmpty) return;
    await _repository.upsertTracks(tracks);
    await _reloadTracks();
  }

  Future<void> playFolderTrack(List<AudioTrack> folderTracks, int index) async {
    if (index < 0 || index >= folderTracks.length) return;

    final playlist = List<AudioTrack>.unmodifiable(folderTracks);
    // Only rebuild the queue when the folder selection actually changed, so
    // 只有文件夹选择实际发生变化时才重建队列，
    // tapping another item in the same folder keeps the current queue intact.
    // 这样在同一文件夹里点其他条目时可以保留当前队列。
    final shouldResetQueue = !_isSamePlaylist(_activePlaylist, playlist);
    if (shouldResetQueue) {
      _activePlaylist = playlist;
      _pendingRestoreTrackPath = null;
      _pendingRestorePositionMs = 0;
      _resetPlayedPlaylistPaths();
      await _audioHandler.setTracks(_activePlaylist, preserveIndex: false);
      await _savePlaybackState(force: true);
    }

    await playTrackAt(index);
  }

  Future<void> appendFolderTracks(
    String folderName,
    List<AudioTrack> folderTracks,
  ) async {
    if (folderTracks.isEmpty) return;

    final existingPaths = _activePlaylist.map((track) => track.path).toSet();
    final appendedTracks = folderTracks.where((track) {
      return existingPaths.add(track.path);
    }).toList(growable: false);
    if (appendedTracks.isEmpty) {
      _pushNotice(
        '$folderName 中的音频已全部存在于播放列表中。',
        isError: false,
      );
      return;
    }

    _activePlaylist = List<AudioTrack>.unmodifiable([
      ..._activePlaylist,
      ...appendedTracks,
    ]);
    _pendingRestoreTrackPath = null;
    _pendingRestorePositionMs = 0;
    await _audioHandler.setTracks(
      _activePlaylist,
      selectFirstWhenIdle: true,
    );
    await _savePlaybackState(force: true);
    _pushNotice(
      '已将 ${appendedTracks.length} 首音频追加到 $folderName 播放列表末尾。',
      isError: false,
    );
  }

  Future<void> playTrackAt(int index) async {
    if (index < 0 || index >= _activePlaylist.length) return;

    final track = _activePlaylist[index];
    if (_unplayablePaths.contains(track.path)) {
      _pushNotice('该音频此前播放失败，请长按查看详情或移除该文件。', isError: true);
      return;
    }

    _pendingRestoreTrackPath = null;
    _pendingRestorePositionMs = 0;
    final ok = await _audioHandler.playFromIndex(index);
    if (ok) {
      if (_unplayablePaths.remove(track.path)) {
        _unplayableVersion += 1;
      }
      notifyListeners();
      return;
    }

    if (_unplayablePaths.add(track.path)) {
      _unplayableVersion += 1;
    }
    _pushNotice('该音频无法正常播放，可能文件已损坏或格式不受支持。', isError: true);
  }

  Future<void> removeTrackFromActivePlaylist(int index) async {
    if (index < 0 || index >= _activePlaylist.length) return;

    final removedTrack = _activePlaylist[index];
    final updatedPlaylist = List<AudioTrack>.from(_activePlaylist)
      ..removeAt(index);
    _activePlaylist = List<AudioTrack>.unmodifiable(updatedPlaylist);
    _pendingRestoreTrackPath = null;
    _pendingRestorePositionMs = 0;
    _clearPlayedPlaylistPath(removedTrack.path);
    await _audioHandler.setTracks(_activePlaylist);
    await _savePlaybackState(force: true);
    notifyListeners();
  }

  Future<void> clearActivePlaylist() async {
    _activePlaylist = const [];
    _pendingRestoreTrackPath = null;
    _pendingRestorePositionMs = 0;
    _resetPlayedPlaylistPaths();
    await _audioHandler.setTracks(_activePlaylist, preserveIndex: false);
    await _repository.clearStoredPlaybackState();
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_playbackState.playing) {
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
    await _savePlaybackState(force: true);
  }

  Future<void> seekTo(Duration position) async {
    await _audioHandler.seek(position);
    _position = position;
    notifyListeners();
    await _savePlaybackState(force: true);
  }

  Future<void> playNext() => _audioHandler.skipToNext();

  Future<void> playPrevious() => _audioHandler.skipToPrevious();

  Future<void> updatePlaybackSpeed(double speed) =>
      _audioHandler.setPlaybackSpeed(speed);

  Future<void> updateSkipSettings(
      {required int skipStartSec, required int skipEndSec}) async {
    final updated =
        _settings.copyWith(skipStartSec: skipStartSec, skipEndSec: skipEndSec);
    _settings = updated;
    await _repository.saveSettings(updated);
    await _audioHandler.applySettings(updated);
    notifyListeners();
  }

  Future<void> updateMinScanDuration(int seconds) async {
    final updated = _settings.copyWith(minScanDurationSec: seconds);
    _settings = updated;
    await _repository.saveSettings(updated);
    notifyListeners();
  }

  Future<void> updateRepeatMode(RepeatModeType mode) async {
    final updated = _settings.copyWith(repeatMode: mode);
    _settings = updated;
    await _repository.saveSettings(updated);
    await _audioHandler.applySettings(updated);
    notifyListeners();
  }

  Future<void> _reloadTracks() async {
    final previousCurrentTrackPath = _currentMediaItem?.id;
    final previousPlaylistIndex = currentPlaylistIndex;

    _tracks = await _repository.getAllTracks();
    final activePaths = _tracks.map((track) => track.path).toSet();
    final previousUnplayableCount = _unplayablePaths.length;
    _unplayablePaths.removeWhere((path) => !activePaths.contains(path));
    if (_unplayablePaths.length != previousUnplayableCount) {
      _unplayableVersion += 1;
    }

    String? preferredTrackPath;
    if (_activePlaylist.isNotEmpty) {
      // Rehydrate playlist entries from the latest library snapshot so title,
      // 鐢ㄦ渶鏂扮殑濯掍綋搴撳揩鐓ч噸鏂版槧灏勬挱鏀惧垪琛ㄩ」锛?
      // duration and artwork stay current after rescans or manual imports.
      // 杩欐牱閲嶆壂鎴栨墜鍔ㄥ鍏ュ悗锛屾爣棰樸€佹椂闀垮拰灏侀潰閮借兘淇濇寔鏈€鏂般€?
      final trackMap = {for (final track in _tracks) track.path: track};
      _activePlaylist = _activePlaylist
          .map((track) => trackMap[track.path])
          .whereType<AudioTrack>()
          .toList(growable: false);
      _playedPlaylistPaths.removeWhere(
        (path) => !_activePlaylist.any((track) => track.path == path),
      );

      if (previousCurrentTrackPath != null) {
        final currentStillExists = _activePlaylist
            .any((track) => track.path == previousCurrentTrackPath);
        if (currentStillExists) {
          preferredTrackPath = previousCurrentTrackPath;
        } else if (previousPlaylistIndex != null &&
            _activePlaylist.isNotEmpty) {
          final fallbackIndex =
              previousPlaylistIndex.clamp(0, _activePlaylist.length - 1);
          preferredTrackPath = _activePlaylist[fallbackIndex].path;
        }
      }
    }

    await _audioHandler.setTracks(
      _activePlaylist,
      restoredTrackId: preferredTrackPath,
    );
    await _savePlaybackState(force: true);
    notifyListeners();
  }

  void _resetPlayedPlaylistPaths() {
    if (_playedPlaylistPaths.isEmpty) return;
    _playedPlaylistPaths.clear();
    _playedPlaylistVersion += 1;
  }

  void _clearPlayedPlaylistPath(String path) {
    if (_playedPlaylistPaths.remove(path)) {
      _playedPlaylistVersion += 1;
    }
  }

  Future<void> _restoreStoredPlaybackState() async {
    final storedState = await _repository.getStoredPlaybackState();
    if (storedState == null || storedState.playlistPaths.isEmpty) {
      await _audioHandler.setTracks(_activePlaylist, preserveIndex: false);
      return;
    }

    // Cached playlist paths may reference files that were deleted after the
    // 缓存的播放列表路径可能指向上次会话后已经被删除的文件，
    // last session, so restore only entries that still exist in the library.
    // 因此恢复时只保留媒体库里仍然存在的条目。
    final trackMap = {for (final track in _tracks) track.path: track};
    final playlist = storedState.playlistPaths
        .map((path) => trackMap[path])
        .whereType<AudioTrack>()
        .toList(growable: false);
    if (playlist.isEmpty) {
      await _repository.clearStoredPlaybackState();
      await _audioHandler.setTracks(_activePlaylist, preserveIndex: false);
      return;
    }

    _activePlaylist = List<AudioTrack>.unmodifiable(playlist);
    _playedPlaylistPaths
      ..clear()
      ..addAll(
        storedState.playedTrackPaths.where(
          (path) => _activePlaylist.any((track) => track.path == path),
        ),
      );
    _playedPlaylistVersion += 1;
    _pendingRestoreTrackPath = storedState.currentTrackPath;
    _pendingRestorePositionMs = storedState.positionMs;
    await _audioHandler.setTracks(_activePlaylist, preserveIndex: false);
  }

  Future<void> restorePendingPlaybackForPlayerScreen() async {
    final targetTrackPath = _pendingRestoreTrackPath;
    if (targetTrackPath == null || _activePlaylist.isEmpty) return;
    if (!_activePlaylist.any((track) => track.path == targetTrackPath)) {
      _pendingRestoreTrackPath = null;
      _pendingRestorePositionMs = 0;
      return;
    }

    await _audioHandler.setTracks(
      _activePlaylist,
      preserveIndex: false,
      restoredTrackId: targetTrackPath,
      restoredPlaying: false,
    );
    if (_pendingRestorePositionMs > 0) {
      await _audioHandler
          .seek(Duration(milliseconds: _pendingRestorePositionMs));
    }
    _pendingRestoreTrackPath = null;
    _pendingRestorePositionMs = 0;
    notifyListeners();
  }

  void _schedulePlaybackStateSave() {
    if (_activePlaylist.isEmpty) return;
    final lastSavedAt = _lastPlaybackStateSavedAt;
    if (lastSavedAt == null ||
        DateTime.now().difference(lastSavedAt) >= _playbackStateSaveInterval) {
      unawaited(_savePlaybackState());
      return;
    }

    // Position updates are high-frequency, so collapse them into one deferred
    // 播放位置更新频率很高，因此要把它们合并成一次延迟写入，
    // write instead of thrashing SQLite on every playback tick.
    // 避免每次进度变化都去频繁写 SQLite。
    if (_playbackStateSaveTimer?.isActive ?? false) return;
    final delay =
        _playbackStateSaveInterval - DateTime.now().difference(lastSavedAt);
    _playbackStateSaveTimer = Timer(delay, () {
      _playbackStateSaveTimer = null;
      unawaited(_savePlaybackState());
    });
  }

  Future<void> _savePlaybackState({bool force = false}) async {
    _playbackStateSaveTimer?.cancel();
    _playbackStateSaveTimer = null;
    if (_activePlaylist.isEmpty) {
      await _repository.clearStoredPlaybackState();
      return;
    }

    final lastSavedAt = _lastPlaybackStateSavedAt;
    if (!force &&
        lastSavedAt != null &&
        DateTime.now().difference(lastSavedAt) < _playbackStateSaveInterval) {
      return;
    }

    // During app restore there may be no current MediaItem yet; keep the last
    // 应用恢复阶段当前可能还没有可用的 MediaItem，
    // intended track/position so PlayerScreen can finish restoration later.
    // 所以先保留目标曲目和位置，交给 PlayerScreen 后续补完恢复。
    final resolvedTrackPath = _currentMediaItem?.id ?? _pendingRestoreTrackPath;
    final resolvedPositionMs =
        _currentMediaItem?.id == null && _pendingRestoreTrackPath != null
            ? _pendingRestorePositionMs
            : (_position.inMilliseconds < 0 ? 0 : _position.inMilliseconds);

    await _repository.saveStoredPlaybackState(
      StoredPlaybackState(
        playlistPaths:
            _activePlaylist.map((track) => track.path).toList(growable: false),
        currentTrackPath: resolvedTrackPath,
        positionMs: resolvedPositionMs,
        isPlaying: _playbackState.playing,
        playedTrackPaths: _playedPlaylistPaths.toList(growable: false),
      ),
    );
    _lastPlaybackStateSavedAt = DateTime.now();
  }

  Future<void> _runBusyTask(Future<void> Function() task) async {
    if (_isBusy || _scanInProgress) return;
    _isBusy = true;
    notifyListeners();
    try {
      await task();
    } catch (_) {
      _pushNotice('操作失败，请稍后重试。', isError: true);
    } finally {
      _isBusy = false;
      _scanStatusText = null;
      notifyListeners();
    }
  }

  bool _isSamePlaylist(List<AudioTrack> a, List<AudioTrack> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].path != b[i].path) return false;
    }
    return true;
  }

  void _pushNotice(String message, {required bool isError}) {
    _noticeToken += 1;
    _notice = UiNotice(token: _noticeToken, message: message, isError: isError);
    notifyListeners();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
