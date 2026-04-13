/// Shared formatting utilities.
/// Centralizes common formatting logic to avoid duplication across screens.
library;

/// Format byte count into human-readable string (B, KB, MB, GB).
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
}

/// Format duration in seconds to mm:ss string.
String formatDuration(int seconds) {
  final mins = seconds ~/ 60;
  final secs = seconds % 60;
  return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

/// Format a DateTime to dd/mm/yyyy string.
String formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}
