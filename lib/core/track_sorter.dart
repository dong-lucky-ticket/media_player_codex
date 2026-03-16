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
  // Sort by folder first so imported albums/chapters stay visually grouped
  // 先按文件夹排序，让导入的专辑或章节在列表里保持聚合显示。
  // before falling back to filename, title and full path for stability.
  // 之后再退回到文件名、标题和完整路径比较，以保证排序稳定。
  final folderCompare = compareNaturalText(
    folderNameForTrackPath(a.path),
    folderNameForTrackPath(b.path),
  );
  if (folderCompare != 0) return folderCompare;

  final fileNameCompare = compareNaturalText(
    p.basenameWithoutExtension(a.path),
    p.basenameWithoutExtension(b.path),
  );
  if (fileNameCompare != 0) return fileNameCompare;

  final titleCompare = compareNaturalText(a.title, b.title);
  if (titleCompare != 0) return titleCompare;

  return compareNaturalText(a.path, b.path);
}

int compareNaturalText(String a, String b) {
  final left = a.trim().toLowerCase();
  final right = b.trim().toLowerCase();
  var leftIndex = 0;
  var rightIndex = 0;

  while (leftIndex < left.length && rightIndex < right.length) {
    final leftCode = left.codeUnitAt(leftIndex);
    final rightCode = right.codeUnitAt(rightIndex);
    final leftIsDigit = _isDigit(leftCode);
    final rightIsDigit = _isDigit(rightCode);

    if (leftIsDigit && rightIsDigit) {
      // Compare numeric runs by value instead of pure lexicographic order so
      // 数字段按数值比较，而不是按纯字典序比较，
      // names like 'track 2' sort before 'track 10'.
      // 这样像 'track 2' 就会排在 'track 10' 前面。
      final leftEnd = _consumeDigits(left, leftIndex);
      final rightEnd = _consumeDigits(right, rightIndex);
      final numberCompare = _compareNumericChunks(
        left.substring(leftIndex, leftEnd),
        right.substring(rightIndex, rightEnd),
      );
      if (numberCompare != 0) return numberCompare;
      leftIndex = leftEnd;
      rightIndex = rightEnd;
      continue;
    }

    if (leftCode != rightCode) return leftCode.compareTo(rightCode);
    leftIndex += 1;
    rightIndex += 1;
  }

  return left.length.compareTo(right.length);
}

int _consumeDigits(String value, int start) {
  var index = start;
  while (index < value.length && _isDigit(value.codeUnitAt(index))) {
    index += 1;
  }
  return index;
}

int _compareNumericChunks(String a, String b) {
  final normalizedA = a.replaceFirst(RegExp(r'^0+'), '');
  final normalizedB = b.replaceFirst(RegExp(r'^0+'), '');
  final digitsA = normalizedA.isEmpty ? '0' : normalizedA;
  final digitsB = normalizedB.isEmpty ? '0' : normalizedB;

  final lengthCompare = digitsA.length.compareTo(digitsB.length);
  if (lengthCompare != 0) return lengthCompare;

  final valueCompare = digitsA.compareTo(digitsB);
  if (valueCompare != 0) return valueCompare;

  return a.length.compareTo(b.length);
}

bool _isDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;
