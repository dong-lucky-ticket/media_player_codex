import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../models/audio_track.dart';

enum ImportActionType {
  autoScan,
  pickFolder,
  pickFiles,
}

class ImportResult {
  const ImportResult({
    required this.type,
    this.tracks = const [],
    this.message,
    this.cancelled = false,
    this.permissionDenied = false,
    this.failed = false,
  });

  final ImportActionType type;
  final List<AudioTrack> tracks;
  final String? message;
  final bool cancelled;
  final bool permissionDenied;
  final bool failed;
}

class ScanProgress {
  const ScanProgress({
    required this.processedCount,
    required this.foundCount,
    this.currentPath,
  });

  final int processedCount;
  final int foundCount;
  final String? currentPath;
}

class PermissionGuideState {
  const PermissionGuideState({
    required this.missingPermissions,
    required this.scanAvailable,
    required this.summary,
  });

  final List<Permission> missingPermissions;
  final bool scanAvailable;
  final String summary;
}

class AudioImportService {
  AudioImportService() : _audioQuery = OnAudioQuery();

  final OnAudioQuery _audioQuery;
  static const _extensions = <String>{'mp3', 'm4a', 'flac', 'wav', 'aac', 'ogg'};

  Future<ImportResult> autoScan({bool Function()? isCancelled}) async {
    try {
      final permission = await requestScanPermissions();
      if (!permission.scanAvailable) {
        return ImportResult(
          type: ImportActionType.autoScan,
          permissionDenied: true,
          message: permission.summary,
        );
      }
      if (isCancelled?.call() ?? false) {
        return const ImportResult(
          type: ImportActionType.autoScan,
          cancelled: true,
          message: '已停止扫描。',
        );
      }

      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      if (isCancelled?.call() ?? false) {
        return const ImportResult(
          type: ImportActionType.autoScan,
          cancelled: true,
          message: '已停止扫描。',
        );
      }

      final tracks = songs
          .where((song) => song.data.isNotEmpty)
          .map(_songToTrack)
          .toList(growable: false);

      if (tracks.isEmpty) {
        return const ImportResult(
          type: ImportActionType.autoScan,
          message: '扫描完成，未发现音频文件。',
        );
      }
      return ImportResult(
        type: ImportActionType.autoScan,
        tracks: tracks,
        message: '扫描完成，发现 ${tracks.length} 个音频文件。',
      );
    } catch (_) {
      return const ImportResult(
        type: ImportActionType.autoScan,
        failed: true,
        message: '扫描失败，请检查权限和系统媒体库状态后重试。',
      );
    }
  }

  Future<ImportResult> pickFolderAndScan({
    bool Function()? isCancelled,
    void Function(ScanProgress progress)? onProgress,
  }) async {
    try {
      final folderPath = await FilePicker.platform.getDirectoryPath(lockParentWindow: true);
      if (folderPath == null || folderPath.isEmpty) {
        return const ImportResult(
          type: ImportActionType.pickFolder,
          cancelled: true,
          message: '已取消文件夹选择。',
        );
      }

      final dir = Directory(folderPath);
      if (!await dir.exists()) {
        return const ImportResult(
          type: ImportActionType.pickFolder,
          failed: true,
          message: '所选文件夹不存在或不可访问。',
        );
      }

      var processedCount = 0;
      final tracks = <AudioTrack>[];
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (isCancelled?.call() ?? false) {
          return ImportResult(
            type: ImportActionType.pickFolder,
            tracks: tracks,
            cancelled: true,
            message: '已停止扫描，已发现 ${tracks.length} 个音频文件。',
          );
        }

        processedCount += 1;
        if (entity is! File) {
          if (processedCount % 50 == 0) {
            onProgress?.call(
              ScanProgress(
                processedCount: processedCount,
                foundCount: tracks.length,
                currentPath: entity.path,
              ),
            );
          }
          continue;
        }

        final ext = p.extension(entity.path).replaceAll('.', '').toLowerCase();
        if (_extensions.contains(ext)) {
          tracks.add(_fileToTrack(entity.path));
        }

        if (processedCount % 20 == 0) {
          onProgress?.call(
            ScanProgress(
              processedCount: processedCount,
              foundCount: tracks.length,
              currentPath: entity.path,
            ),
          );
        }
      }

      if (tracks.isEmpty) {
        return const ImportResult(
          type: ImportActionType.pickFolder,
          message: '该文件夹中未发现支持的音频格式。',
        );
      }
      return ImportResult(
        type: ImportActionType.pickFolder,
        tracks: tracks,
        message: '导入成功，新增 ${tracks.length} 个音频文件。',
      );
    } catch (_) {
      return const ImportResult(
        type: ImportActionType.pickFolder,
        failed: true,
        message: '导入文件夹失败，请重试。',
      );
    }
  }

  Future<ImportResult> pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: _extensions.toList(),
        withData: false,
        lockParentWindow: true,
      );

      if (result == null) {
        return const ImportResult(
          type: ImportActionType.pickFiles,
          cancelled: true,
          message: '已取消文件选择。',
        );
      }

      final tracks = result.files
          .where((file) => file.path != null)
          .map((file) => _fileToTrack(file.path!))
          .toList(growable: false);

      if (tracks.isEmpty) {
        return const ImportResult(
          type: ImportActionType.pickFiles,
          message: '未选中可用的音频文件。',
        );
      }
      return ImportResult(
        type: ImportActionType.pickFiles,
        tracks: tracks,
        message: '导入成功，新增 ${tracks.length} 个音频文件。',
      );
    } catch (_) {
      return const ImportResult(
        type: ImportActionType.pickFiles,
        failed: true,
        message: '导入文件失败，请重试。',
      );
    }
  }

  AudioTrack _songToTrack(SongModel song) {
    return AudioTrack(
      path: song.data,
      title: song.title,
      artist: song.artist ?? 'Unknown',
      album: song.album ?? 'Unknown',
      durationMs: song.duration ?? 0,
      artUri: 'content://media/external/audio/albumart/${song.albumId ?? 0}',
    );
  }

  AudioTrack _fileToTrack(String path) {
    final title = p.basenameWithoutExtension(path);
    return AudioTrack(
      path: path,
      title: title,
      artist: 'Unknown',
      album: 'Unknown',
      durationMs: 0,
      artUri: null,
    );
  }

  Future<PermissionGuideState> getPermissionGuideState() async {
    final android = await DeviceInfoPlugin().androidInfo;
    final sdk = android.version.sdkInt;
    final missing = <Permission>[];

    if (sdk >= 33) {
      final audioStatus = await Permission.audio.status;
      final notifStatus = await Permission.notification.status;
      if (!audioStatus.isGranted) {
        missing.add(Permission.audio);
      }
      if (!notifStatus.isGranted && !notifStatus.isLimited) {
        missing.add(Permission.notification);
      }
    } else if (sdk <= 32) {
      final storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        missing.add(Permission.storage);
      }
    }

    if (missing.isEmpty) {
      return const PermissionGuideState(
        missingPermissions: [],
        scanAvailable: true,
        summary: '媒体权限状态正常，可执行自动扫描。',
      );
    }
    return PermissionGuideState(
      missingPermissions: missing,
      scanAvailable: false,
      summary: '缺少媒体访问权限，请先授权后再扫描。',
    );
  }

  Future<PermissionGuideState> requestScanPermissions() async {
    final android = await DeviceInfoPlugin().androidInfo;
    final sdk = android.version.sdkInt;
    final missing = <Permission>[];

    if (sdk >= 33) {
      final audioStatus = await Permission.audio.request();
      final notifStatus = await Permission.notification.request();
      if (!audioStatus.isGranted) {
        missing.add(Permission.audio);
      }
      if (!notifStatus.isGranted && !notifStatus.isLimited) {
        missing.add(Permission.notification);
      }
    } else if (sdk <= 32) {
      final storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        missing.add(Permission.storage);
      }
    }

    if (missing.isEmpty) {
      return const PermissionGuideState(
        missingPermissions: [],
        scanAvailable: true,
        summary: '权限已授予。',
      );
    }
    return PermissionGuideState(
      missingPermissions: missing,
      scanAvailable: false,
      summary: '权限被拒绝，请在系统设置中开启后重试。',
    );
  }

  Future<bool> openPermissionSettings() async {
    return openAppSettings();
  }
}

