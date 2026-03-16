import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/audio_track.dart';

class PlayerAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  static final Uri _fallbackArtUri =
      Uri.parse('android.resource://com.example.player/mipmap/ic_launcher');

  PlayerAudioHandler._(this._player) {
    _player.playbackEventStream.listen((_) => _broadcastState());
    _player.currentIndexStream.listen(_handleCurrentIndexChanged);
    _player.durationStream.listen(_updateDurationForCurrent);
    _player.positionStream.listen((position) async {
      _lastObservedPosition = position;
      try {
        await _handlePositionTick(position);
      } catch (_) {
        // Keep playback alive if auto-advance fails on malformed media.
      }
    });
  }

  final AudioPlayer _player;
  final StreamController<String> _completedTrackController =
      StreamController<String>.broadcast();
  int _skipStartSec = 5;
  int _skipEndSec = 3;
  RepeatModeType _repeatMode = RepeatModeType.listLoop;
  bool _isAutoAdvancing = false;
  bool _suppressImplicitSelection = false;
  String? _lastCompletedTrackId;
  Duration _lastObservedPosition = Duration.zero;

  static Future<PlayerAudioHandler> init() async {
    final handler = PlayerAudioHandler._(AudioPlayer());
    await AudioService.init(
      builder: () => handler,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.player.channel.playback',
        androidNotificationChannelName: 'Playback',
        androidNotificationIcon: 'drawable/ic_stat_music_note',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    return handler;
  }

  Stream<String> get completedTrackStream => _completedTrackController.stream;

  Future<void> setTracks(
    List<AudioTrack> tracks, {
    bool preserveIndex = true,
    bool selectFirstWhenIdle = false,
    String? restoredTrackId,
    Duration? restoredPosition,
    bool? restoredPlaying,
  }) async {
    final wasPlaying = _player.playing;
    final previousPosition = _player.position;

    final items = tracks
        .map(
          (track) => MediaItem(
            id: track.path,
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: track.durationMs > 0
                ? Duration(milliseconds: track.durationMs)
                : null,
            artUri: _mediaArtUriForTrack(track),
            extras: {'path': track.path},
          ),
        )
        .toList(growable: false);

    final targetTrackId =
        restoredTrackId ?? (preserveIndex ? mediaItem.value?.id : null);
    final locatedIndex = targetTrackId == null
        ? -1
        : items.indexWhere((item) => item.id == targetTrackId);
    final hasRestorableSelection = locatedIndex >= 0;
    final initialIndex = items.isEmpty
        ? 0
        : (hasRestorableSelection
            ? locatedIndex.clamp(0, items.length - 1)
            : 0);
    final shouldRestorePreviousPosition =
        restoredTrackId == null && hasRestorableSelection && preserveIndex;
    final initialPosition = shouldRestorePreviousPosition
        ? previousPosition
        : restoredPosition ?? Duration(seconds: _skipStartSec);
    final shouldResumePlayback = restoredPlaying ?? wasPlaying;

    _suppressImplicitSelection = !shouldResumePlayback &&
        !hasRestorableSelection &&
        !selectFirstWhenIdle;
    queue.add(items);

    if (items.isEmpty) {
      _lastCompletedTrackId = null;
      _suppressImplicitSelection = false;
      await _player.stop();
      mediaItem.add(null);
      return;
    }

    final source = ConcatenatingAudioSource(
      children: items
          .map((item) => AudioSource.uri(Uri.file(item.id), tag: item))
          .toList(growable: false),
      useLazyPreparation: true,
    );

    await _player.setAudioSource(
      source,
      initialIndex: initialIndex,
      initialPosition: initialPosition,
    );

    if (_repeatMode == RepeatModeType.shuffle) {
      await _player.shuffle();
    }

    if (_suppressImplicitSelection) {
      mediaItem.add(null);
      _broadcastState();
    } else {
      _publishCurrentSelectionFromPlayer();
    }

    if (shouldResumePlayback) {
      await play();
    }
  }

  Uri _mediaArtUriForTrack(AudioTrack track) {
    final rawArtUri = track.artUri?.trim();
    if (rawArtUri == null || rawArtUri.isEmpty) return _fallbackArtUri;

    return Uri.tryParse(rawArtUri) ?? _fallbackArtUri;
  }

  Future<void> applySettings(PlayerSettings settings) async {
    _skipStartSec = settings.skipStartSec;
    _skipEndSec = settings.skipEndSec;
    _repeatMode = settings.repeatMode;
    await _syncRepeatMode();
    _broadcastState();
  }

  @override
  Future<void> play() {
    _suppressImplicitSelection = false;
    _publishCurrentSelectionFromPlayer();
    return _player.play();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await _player.setSpeed(speed);
    _broadcastState();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  Future<bool> playFromIndex(int index) async {
    final previousIndex = _player.currentIndex;
    final previousPosition = _player.position;
    final wasPlaying = _player.playing;

    _suppressImplicitSelection = false;
    try {
      await _player.seek(Duration(seconds: _skipStartSec), index: index);
      _publishCurrentSelectionFromPlayer();
      await _player.play();
      return true;
    } catch (_) {
      await _recoverFromPlaybackFailure(
        failedIndex: index,
        previousIndex: previousIndex,
        previousPosition: previousPosition,
        wasPlaying: wasPlaying,
      );
      return false;
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await playFromIndex(index);
  }

  @override
  Future<void> skipToNext() async {
    final queueLength = queue.value.length;
    if (queueLength == 0) return;

    final nextIndex = _player.nextIndex;
    if (_player.hasNext &&
        nextIndex != null &&
        nextIndex >= 0 &&
        nextIndex < queueLength) {
      await _safeSeekAndPlay(nextIndex);
      return;
    }

    if (_repeatMode == RepeatModeType.listLoop ||
        _repeatMode == RepeatModeType.shuffle) {
      await _safeSeekAndPlay(0);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final queueLength = queue.value.length;
    if (queueLength == 0) return;

    final previousIndex = _player.previousIndex;
    if (_player.hasPrevious &&
        previousIndex != null &&
        previousIndex >= 0 &&
        previousIndex < queueLength) {
      await _safeSeekAndPlay(previousIndex);
      return;
    }

    await _safeSeekAndPlay(0);
  }

  Future<void> _syncRepeatMode() async {
    switch (_repeatMode) {
      case RepeatModeType.listLoop:
        await _player.setLoopMode(LoopMode.all);
        await _player.setShuffleModeEnabled(false);
        break;
      case RepeatModeType.single:
        await _player.setLoopMode(LoopMode.one);
        await _player.setShuffleModeEnabled(false);
        break;
      case RepeatModeType.shuffle:
        await _player.setLoopMode(LoopMode.all);
        await _player.setShuffleModeEnabled(true);
        await _player.shuffle();
        break;
    }
  }

  void _broadcastState() {
    final isPlaying = _player.playing;

    playbackState.add(
      PlaybackState(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          isPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _transformProcessingState(_player.processingState),
        playing: isPlaying,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _player.currentIndex,
        repeatMode: _repeatMode == RepeatModeType.single
            ? AudioServiceRepeatMode.one
            : AudioServiceRepeatMode.all,
        shuffleMode: _repeatMode == RepeatModeType.shuffle
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      ),
    );
  }

  AudioProcessingState _transformProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  void _handleCurrentIndexChanged(int? index) {
    final previousItem = mediaItem.value;
    if (previousItem != null &&
        _didReachCompletionPoint(previousItem, _lastObservedPosition)) {
      _emitCompletedTrack(previousItem.id);
    }
    _updateCurrentMediaItem(index);
  }

  void _updateCurrentMediaItem(int? index) {
    if (index == null || index < 0 || index >= queue.value.length) return;
    final nextItem = queue.value[index];
    if (mediaItem.value?.id != nextItem.id) {
      _lastCompletedTrackId = null;
      _lastObservedPosition = Duration.zero;
    }
    if (_suppressImplicitSelection && !_player.playing) {
      _broadcastState();
      return;
    }
    mediaItem.add(queue.value[index]);
    _broadcastState();
  }

  void _updateDurationForCurrent(Duration? duration) {
    if (duration == null) return;
    final index = _player.currentIndex;
    if (index == null || index < 0 || index >= queue.value.length) return;

    final current = queue.value[index];
    if (current.duration == duration) return;

    final updated = current.copyWith(duration: duration);
    final newQueue = [...queue.value]..[index] = updated;
    queue.add(newQueue);
    mediaItem.add(updated);
  }

  Future<void> _handlePositionTick(Duration position) async {
    if (_isAutoAdvancing || !_player.playing || _skipEndSec <= 0) return;
    if (_player.processingState != ProcessingState.ready) return;

    final currentDuration = mediaItem.value?.duration ?? _player.duration;
    if (currentDuration == null || currentDuration.inSeconds <= _skipEndSec) {
      return;
    }

    final endLimit = currentDuration - Duration(seconds: _skipEndSec);
    if (position < endLimit) return;

    _isAutoAdvancing = true;
    try {
      _emitCompletedCurrentTrack();
      if (_repeatMode == RepeatModeType.single) {
        await _player.seek(Duration(seconds: _skipStartSec));
        await _player.play();
      } else {
        await skipToNext();
      }
    } finally {
      _isAutoAdvancing = false;
    }
  }

  Future<void> _safeSeekAndPlay(int index) async {
    final queueLength = queue.value.length;
    if (queueLength == 0) return;
    if (index < 0 || index >= queueLength) return;

    try {
      _suppressImplicitSelection = false;
      await _player.seek(Duration(seconds: _skipStartSec), index: index);
      _publishCurrentSelectionFromPlayer();
      await _player.play();
    } catch (_) {
      // Ignore transition errors to avoid app crash on bad files.
    }
  }

  Future<void> _recoverFromPlaybackFailure({
    required int failedIndex,
    required int? previousIndex,
    required Duration previousPosition,
    required bool wasPlaying,
  }) async {
    final queueLength = queue.value.length;
    if (previousIndex != null &&
        previousIndex >= 0 &&
        previousIndex < queueLength &&
        previousIndex != failedIndex) {
      try {
        await _player.seek(previousPosition, index: previousIndex);
        _publishCurrentSelectionFromPlayer();
        if (wasPlaying) {
          await _player.play();
        } else {
          await _player.pause();
        }
        return;
      } catch (_) {
        // Fall through to hard reset below.
      }
    }

    try {
      await _player.stop();
    } catch (_) {
      // Ignore stop errors during recovery.
    }
    mediaItem.add(null);
    _broadcastState();
  }

  bool _didReachCompletionPoint(MediaItem item, Duration position) {
    final duration = item.duration ?? _player.duration;
    if (duration == null || duration <= Duration.zero) return false;

    if (_skipEndSec > 0) {
      final threshold = duration - Duration(seconds: _skipEndSec);
      if (threshold > Duration.zero) return position >= threshold;
    }

    return position >= duration * 0.98;
  }

  void _emitCompletedTrack(String? trackId) {
    if (trackId == null || _lastCompletedTrackId == trackId) return;
    _lastCompletedTrackId = trackId;
    _completedTrackController.add(trackId);
  }

  void _emitCompletedCurrentTrack() {
    _emitCompletedTrack(mediaItem.value?.id);
  }

  void _publishCurrentSelectionFromPlayer() {
    final index = _player.currentIndex;
    if (index == null || index < 0 || index >= queue.value.length) return;
    mediaItem.add(queue.value[index]);
    _broadcastState();
  }

  Duration get position => _player.position;
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Future<void> stop() async {
    _lastCompletedTrackId = null;
    _lastObservedPosition = Duration.zero;
    await _player.stop();
    await super.stop();
  }
}
