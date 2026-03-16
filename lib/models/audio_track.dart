class AudioTrack {
  const AudioTrack({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    this.artUri,
  });

  final String path;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String? artUri;

  factory AudioTrack.fromMap(Map<String, Object?> map) {
    return AudioTrack(
      path: map['path'] as String,
      title: (map['title'] as String?) ?? 'Unknown',
      artist: (map['artist'] as String?) ?? 'Unknown',
      album: (map['album'] as String?) ?? 'Unknown',
      durationMs: (map['duration_ms'] as int?) ?? 0,
      artUri: map['art_uri'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'path': path,
      'title': title,
      'artist': artist,
      'album': album,
      'duration_ms': durationMs,
      'art_uri': artUri,
    };
  }

  AudioTrack copyWith({
    String? title,
    String? artist,
    String? album,
    int? durationMs,
    String? artUri,
  }) {
    return AudioTrack(
      path: path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationMs: durationMs ?? this.durationMs,
      artUri: artUri ?? this.artUri,
    );
  }
}

enum RepeatModeType {
  listLoop,
  single,
  shuffle,
}

class PlayerSettings {
  const PlayerSettings({
    this.skipStartSec = 0,
    this.skipEndSec = 0,
    this.minScanDurationSec = 0,
    this.repeatMode = RepeatModeType.listLoop,
  });

  final int skipStartSec;
  final int skipEndSec;
  final int minScanDurationSec;
  final RepeatModeType repeatMode;

  PlayerSettings copyWith({
    int? skipStartSec,
    int? skipEndSec,
    int? minScanDurationSec,
    RepeatModeType? repeatMode,
  }) {
    return PlayerSettings(
      skipStartSec: skipStartSec ?? this.skipStartSec,
      skipEndSec: skipEndSec ?? this.skipEndSec,
      minScanDurationSec: minScanDurationSec ?? this.minScanDurationSec,
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }
}
