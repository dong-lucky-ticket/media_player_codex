String formatDuration(Duration? duration) {
  if (duration == null) return '--:--';
  final totalSeconds = duration.inSeconds;
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  final hours = totalSeconds ~/ 3600;
  if (hours > 0) {
    final mm = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    return '$hours:$mm:$seconds';
  }
  return '$minutes:$seconds';
}

