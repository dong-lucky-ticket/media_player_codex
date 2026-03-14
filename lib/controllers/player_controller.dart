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

  Future<void> init() async {
    _settings = await _repository.getSettings();
    _permissionState = await _importService.getPermissionGuideState();
    _tracks = await _repository.getAllTracks();

    if (_tracks.isEmpty && !_permissionState.scanAvailable) {
      _pushNotice(_permissionState.summary, isError: true);
    }

    await _audioHandler.applySettings(_settings);
    await _audioHandler.setTracks(_activePlaylist, preserveIndex: false);

    _subscriptions
      ..add(_audioHandler.mediaItem.listen((item) {
        _currentMediaItem = item;
        notifyListeners();
      }))
      ..add(_audioHandler.playbackState.listen((state) {
        _playbackState = state;
        notifyListeners();
      }))
      ..add(_audioHandler.positionStream.listen((position) {
        _position = position;
        notifyListeners();
      }))
      ..add(_audioHandler.completedTrackStream.listen((path) {
        if (_playedPlaylistPaths.add(path)) {
          _playedPlaylistVersion += 1;
          notifyListeners();
        }
      }));

    notifyListeners();
  }

  void setSearchText(String value) {
    _searchText = value;
    notifyListeners();
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
              '已扫描 ${progress.processedCount} 项，发现 ${progress.foundCount} 个音频';
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
    final shouldResetQueue = !_isSamePlaylist(_activePlaylist, playlist);
    if (shouldResetQueue) {
      _activePlaylist = playlist;
      _resetPlayedPlaylistPaths();
      await _audioHandler.setTracks(_activePlaylist, preserveIndex: false);
    }

    await playTrackAt(index);
  }

  Future<void> appendFolderTracks(
    String folderName,
    List<AudioTrack> folderTracks,
  ) async {
    if (folderTracks.isEmpty) return;

    _activePlaylist = List<AudioTrack>.unmodifiable([
      ..._activePlaylist,
      ...folderTracks,
    ]);
    await _audioHandler.setTracks(_activePlaylist);
    _pushNotice(
      '已将 ${folderTracks.length} 首音频追加到 $folderName 播放列表末尾。',
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
    final updatedPlaylist = List<AudioTrack>.from(_activePlaylist)..removeAt(index);
    _activePlaylist = List<AudioTrack>.unmodifiable(updatedPlaylist);
    _clearPlayedPlaylistPath(removedTrack.path);
    await _audioHandler.setTracks(_activePlaylist);
    notifyListeners();
  }
  Future<void> clearActivePlaylist() async {
    _activePlaylist = const [];
    _resetPlayedPlaylistPaths();
    await _audioHandler.setTracks(_activePlaylist, preserveIndex: false);
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_playbackState.playing) {
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
  }

  Future<void> seekTo(Duration position) => _audioHandler.seek(position);

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
    _tracks = await _repository.getAllTracks();
    final activePaths = _tracks.map((track) => track.path).toSet();
    final previousUnplayableCount = _unplayablePaths.length;
    _unplayablePaths.removeWhere((path) => !activePaths.contains(path));
    if (_unplayablePaths.length != previousUnplayableCount) {
      _unplayableVersion += 1;
    }

    if (_activePlaylist.isNotEmpty) {
      final trackMap = {for (final track in _tracks) track.path: track};
      _activePlaylist = _activePlaylist
          .map((track) => trackMap[track.path])
          .whereType<AudioTrack>()
          .toList(growable: false);
      _playedPlaylistPaths.removeWhere(
        (path) => !_activePlaylist.any((track) => track.path == path),
      );
    }

    await _audioHandler.setTracks(_activePlaylist);
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




