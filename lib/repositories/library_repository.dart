import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/audio_track.dart';

class LibraryRepository {
  static const _settingsTable = 'settings';
  static const _tracksTable = 'tracks';
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
    final rows = await _database.query(_tracksTable, orderBy: 'title COLLATE NOCASE');
    return rows.map(AudioTrack.fromMap).toList();
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

  Future<PlayerSettings> getSettings() async {
    final rows = await _database.query(_settingsTable);
    final values = <String, String>{};
    for (final row in rows) {
      values[row['key'] as String] = row['value'] as String;
    }

    return PlayerSettings(
      skipStartSec: int.tryParse(values['skip_start_sec'] ?? '') ?? 0,
      skipEndSec: int.tryParse(values['skip_end_sec'] ?? '') ?? 0,
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
    put('repeat_mode', settings.repeatMode.name);
    await batch.commit(noResult: true);
  }

  RepeatModeType _parseRepeatMode(String? raw) {
    return RepeatModeType.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => RepeatModeType.listLoop,
    );
  }
}

