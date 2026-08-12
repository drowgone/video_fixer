import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'ffmpeg_runner.dart';
import 'security_service.dart';

class ThumbnailCache {
  static final Map<String, Uint8List> _cache = {};
  static final Queue<String> _queue = Queue();
  static const int maxCache = 50; // max 50 thumbnail

  static Future<Uint8List?> get(String videoPath, int seconds) async {
    final key = '$videoPath:$seconds';

    // LRU Cache hit
    if (_cache.containsKey(key)) {
      _queue.remove(key);
      _queue.add(key);
      return _cache[key];
    }

    // Cache miss - generate thumb via Mutex-safe FFmpegRunner
    final thumb = await _generateThumb(videoPath, seconds);
    if (thumb != null) {
      if (_cache.length >= maxCache) {
        final oldestKey = _queue.removeFirst();
        _cache.remove(oldestKey);
      }
      _cache[key] = thumb;
      _queue.add(key);
    }
    return thumb;
  }

  static Future<Uint8List?> _generateThumb(String videoPath, int seconds) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbPath = p.join(
        tempDir.path,
        'thumb_${videoPath.hashCode}_${seconds}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final durationStr = _formatDuration(seconds);
      // Timeline thumbnail 100x56px is perfect & lightweight
      final command = '-y -ss $durationStr -i "$videoPath" -vframes 1 -s 100x56 "$thumbPath"';
      
      final success = await FFmpegRunner.execute(command);
      if (success) {
        final file = File(thumbPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          await file.delete(); // Delete temp file immediately
          return bytes;
        }
      }
    } catch (e) {
      secureLog('Error generating thumbnail: $e');
    }
    return null;
  }

  static String _formatDuration(int totalSeconds) {
    final int hours = (totalSeconds / 3600).floor();
    final int minutes = ((totalSeconds % 3600) / 60).floor();
    final int seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
