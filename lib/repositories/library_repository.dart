import 'dart:convert';
import 'dart:io';

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
  static const _settingsBackupFileName = 'player_settings.json';
  static const _playlistPathsKey = 'active_playlist_paths_json';
  static const _currentTrackPathKey = 'active_playlist_current_path';
  static const _positionMsKey = 'active_playlist_position_ms';
  static const _isPlayingKey = 'active_playlist_is_playing';
  static const _playedTrackPathsKey = 'active_playlist_played_paths_json';
  Database? _db;
  late final String _settingsBackupPath;

  Future<void> init() async {
    final databasePath = await getDatabasesPath();
    final path = p.join(databasePath, 'player.db');
    _settingsBackupPath = p.join(databasePath, _settingsBackupFileName);

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await _ensureSchema(db);
      },
    );
    await _ensureSchema(_database);
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
    final values = await _readSettingsMap();
    if (values.isNotEmpty) {
      return _settingsFromValues(values);
    }

    final backupSettings = await _readSettingsBackup();
    if (backupSettings != null) {
      await saveSettings(backupSettings);
      return backupSettings;
    }

    return const PlayerSettings();
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
    await _writeSettingsBackup(settings);
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

  PlayerSettings _settingsFromValues(Map<String, String> values) {
    return PlayerSettings(
      skipStartSec: int.tryParse(values['skip_start_sec'] ?? '') ?? 0,
      skipEndSec: int.tryParse(values['skip_end_sec'] ?? '') ?? 0,
      minScanDurationSec:
          int.tryParse(values['min_scan_duration_sec'] ?? '') ?? 0,
      repeatMode: _parseRepeatMode(values['repeat_mode']),
    );
  }

  Future<Map<String, String>> _readSettingsMap() async {
    final rows = await _database.query(_settingsTable);
    final values = <String, String>{};
    for (final row in rows) {
      values[row['key'] as String] = row['value'] as String;
    }
    return values;
  }

  Future<PlayerSettings?> _readSettingsBackup() async {
    final file = File(_settingsBackupPath);
    if (!await file.exists()) return null;

    try {
      final raw = await file.readAsString();
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;

      return PlayerSettings(
        skipStartSec: (json['skipStartSec'] as num?)?.toInt() ?? 0,
        skipEndSec: (json['skipEndSec'] as num?)?.toInt() ?? 0,
        minScanDurationSec: (json['minScanDurationSec'] as num?)?.toInt() ?? 0,
        repeatMode: _parseRepeatMode(json['repeatMode'] as String?),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSettingsBackup(PlayerSettings settings) async {
    final file = File(_settingsBackupPath);
    final payload = jsonEncode({
      'skipStartSec': settings.skipStartSec,
      'skipEndSec': settings.skipEndSec,
      'minScanDurationSec': settings.minScanDurationSec,
      'repeatMode': settings.repeatMode.name,
    });
    await file.writeAsString(payload, flush: true);
  }

  Future<void> _ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tracksTable (
        path TEXT PRIMARY KEY,
        title TEXT,
        artist TEXT,
        album TEXT,
        duration_ms INTEGER,
        art_uri TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_settingsTable (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  RepeatModeType _parseRepeatMode(String? raw) {
    return RepeatModeType.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => RepeatModeType.listLoop,
    );
  }
}
