import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/track_sorter.dart';
import '../models/audio_track.dart';

class StoredPlaybackState {
  const StoredPlaybackState({
    required this.playlistPaths,
    required this.currentTrackPath,
    required this.positionMs,
    required this.isPlaying,
    required this.playedTrackPaths,
  });

  final List<String> playlistPaths;
  final String? currentTrackPath;
  final int positionMs;
  final bool isPlaying;
  final List<String> playedTrackPaths;
}

class LibraryRepository {
  static const _settingsTable = 'settings';
  static const _tracksTable = 'tracks';
  static const _playlistPathsKey = 'active_playlist_paths_json';
  static const _currentTrackPathKey = 'active_playlist_current_path';
  static const _positionMsKey = 'active_playlist_position_ms';
  static const _isPlayingKey = 'active_playlist_is_playing';
  static const _playedTrackPathsKey = 'active_playlist_played_paths_json';
  Database? _db;

  Future<void> init() async {
    final databasePath = await getDatabasesPath();
    final path = p.join(databasePath, 'player.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tracksTable (
            path TEXT PRIMARY KEY,
            title TEXT,
            artist TEXT,
            album TEXT,
            duration_ms INTEGER,
            art_uri TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE $_settingsTable (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
    );
  }

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('Database not initialized');
    }
    return db;
  }

  Future<List<AudioTrack>> getAllTracks() async {
    final rows = await _database.query(_tracksTable);
    final tracks = rows.map(AudioTrack.fromMap).toList(growable: false);
    return sortTracksByFolder(tracks);
  }

  Future<void> upsertTracks(List<AudioTrack> tracks) async {
    if (tracks.isEmpty) return;
    final batch = _database.batch();
    for (final track in tracks) {
      batch.insert(
        _tracksTable,
        track.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> removeTrack(String path) async {
    await _database.delete(_tracksTable, where: 'path = ?', whereArgs: [path]);
  }

  Future<void> removeTracks(List<String> paths) async {
    if (paths.isEmpty) return;
    final batch = _database.batch();
    for (final path in paths) {
      batch.delete(_tracksTable, where: 'path = ?', whereArgs: [path]);
    }
    await batch.commit(noResult: true);
  }

  Future<int> removeTracksBelowDuration(int minDurationMs) async {
    if (minDurationMs <= 0) {
      return _database.delete(
        _tracksTable,
        where: 'duration_ms <= 0',
      );
    }
    return _database.delete(
      _tracksTable,
      where: 'duration_ms <= 0 OR duration_ms < ?',
      whereArgs: [minDurationMs],
    );
  }

  Future<PlayerSettings> getSettings() async {
    final rows = await _database.query(_settingsTable);
    final values = <String, String>{};
    for (final row in rows) {
      values[row['key'] as String] = row['value'] as String;
    }

    return PlayerSettings(
      skipStartSec: int.tryParse(values['skip_start_sec'] ?? '') ?? 0,
      skipEndSec: int.tryParse(values['skip_end_sec'] ?? '') ?? 0,
      minScanDurationSec:
          int.tryParse(values['min_scan_duration_sec'] ?? '') ?? 0,
      repeatMode: _parseRepeatMode(values['repeat_mode']),
    );
  }

  Future<void> saveSettings(PlayerSettings settings) async {
    final batch = _database.batch();

    void put(String key, String value) {
      batch.insert(
        _settingsTable,
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    put('skip_start_sec', settings.skipStartSec.toString());
    put('skip_end_sec', settings.skipEndSec.toString());
    put('min_scan_duration_sec', settings.minScanDurationSec.toString());
    put('repeat_mode', settings.repeatMode.name);
    await batch.commit(noResult: true);
  }

  Future<StoredPlaybackState?> getStoredPlaybackState() async {
    final rows = await _database.query(_settingsTable);
    final values = <String, String>{};
    for (final row in rows) {
      values[row['key'] as String] = row['value'] as String;
    }

    final rawPlaylist = values[_playlistPathsKey];
    if (rawPlaylist == null || rawPlaylist.isEmpty) return null;

    return StoredPlaybackState(
      playlistPaths: (jsonDecode(rawPlaylist) as List<dynamic>)
          .map((item) => item as String)
          .toList(growable: false),
      currentTrackPath: values[_currentTrackPathKey],
      positionMs: int.tryParse(values[_positionMsKey] ?? '') ?? 0,
      isPlaying: (values[_isPlayingKey] ?? '0') == '1',
      playedTrackPaths:
          ((jsonDecode(values[_playedTrackPathsKey] ?? '[]')) as List<dynamic>)
              .map((item) => item as String)
              .toList(growable: false),
    );
  }

  Future<void> saveStoredPlaybackState(StoredPlaybackState state) async {
    final batch = _database.batch();

    void put(String key, String value) {
      batch.insert(
        _settingsTable,
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    put(_playlistPathsKey, jsonEncode(state.playlistPaths));
    put(_currentTrackPathKey, state.currentTrackPath ?? '');
    put(_positionMsKey, state.positionMs.toString());
    put(_isPlayingKey, state.isPlaying ? '1' : '0');
    put(_playedTrackPathsKey, jsonEncode(state.playedTrackPaths));
    await batch.commit(noResult: true);
  }

  Future<void> clearStoredPlaybackState() async {
    await _database.delete(
      _settingsTable,
      where: 'key IN (?, ?, ?, ?, ?)',
      whereArgs: [
        _playlistPathsKey,
        _currentTrackPathKey,
        _positionMsKey,
        _isPlayingKey,
        _playedTrackPathsKey,
      ],
    );
  }

  RepeatModeType _parseRepeatMode(String? raw) {
    return RepeatModeType.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => RepeatModeType.listLoop,
    );
  }
}
