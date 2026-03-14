import 'package:path/path.dart' as p;

import '../models/audio_track.dart';

String folderNameForTrackPath(String path) {
  final normalized = path.trim();
  if (normalized.isEmpty) return '未分类';
  final directory = p.dirname(normalized);
  if (directory.isEmpty || directory == '.' || directory == normalized) {
    return '未分类';
  }
  final name = p.basename(directory);
  return name.isEmpty ? '未分类' : name;
}

List<AudioTrack> sortTracksByFolder(List<AudioTrack> tracks) {
  final sorted = List<AudioTrack>.from(tracks);
  sorted.sort(compareTracksByFolder);
  return sorted;
}

int compareTracksByFolder(AudioTrack a, AudioTrack b) {
  final folderCompare = folderNameForTrackPath(a.path).toLowerCase().compareTo(
        folderNameForTrackPath(b.path).toLowerCase(),
      );
  if (folderCompare != 0) return folderCompare;

  final titleCompare = a.title.toLowerCase().compareTo(b.title.toLowerCase());
  if (titleCompare != 0) return titleCompare;

  return a.path.toLowerCase().compareTo(b.path.toLowerCase());
}
