import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'security_service.dart';

class VideoFormatInfo {
  final String videoCodec;
  final String audioCodec;
  final int width;
  final int height;
  final double fps;
  final int sampleRate;
  final int channels;
  final double durationSeconds;
  final double bitrate;

  const VideoFormatInfo({
    required this.videoCodec,
    required this.audioCodec,
    required this.width,
    required this.height,
    required this.fps,
    required this.sampleRate,
    required this.channels,
    required this.durationSeconds,
    required this.bitrate,
  });

  bool get isVertical => height > width;
  bool get isHorizontal => width >= height;
  bool get needsAudioFix =>
      !audioCodec.contains('aac') || sampleRate != 44100 || channels != 2;
}

class FFmpegRunner {
  static final List<Completer<void>> _lockCompleterQueue = [];
  static bool _isExecuting = false;

  static Future<void> _acquireLock() async {
    if (!_isExecuting) {
      _isExecuting = true;
      return;
    }
    final completer = Completer<void>();
    _lockCompleterQueue.add(completer);
    await completer.future;
  }

  static void _releaseLock() {
    if (_lockCompleterQueue.isNotEmpty) {
      final next = _lockCompleterQueue.removeAt(0);
      next.complete();
    } else {
      _isExecuting = false;
    }
  }

  static double _parseFps(String? fpsText) {
    if (fpsText == null || fpsText.isEmpty) return 0.0;
    if (fpsText.contains('/')) {
      final parts = fpsText.split('/');
      if (parts.length != 2) return 0.0;
      final num = double.tryParse(parts[0]) ?? 0.0;
      final den = double.tryParse(parts[1]) ?? 1.0;
      if (den <= 0) return 0.0;
      return num / den;
    }
    return double.tryParse(fpsText) ?? 0.0;
  }

  static Future<VideoFormatInfo?> probeVideo(String path) async {
    try {
      final mediaInfoSession = await FFprobeKit.getMediaInformation(path);
      final info = mediaInfoSession.getMediaInformation();
      if (info == null) return null;

      int width = 0;
      int height = 0;
      String videoCodec = '';
      String audioCodec = '';
      int sampleRate = 0;
      int channels = 0;
      double fps = 0.0;
      final durationSeconds = double.tryParse(info.getDuration() ?? '') ?? 0.0;
      final bitrate = double.tryParse(info.getBitrate() ?? '') ?? 0.0;

      for (final stream in info.getStreams()) {
        final type = stream.getType();
        if (type == 'video') {
          width = stream.getWidth() ?? width;
          height = stream.getHeight() ?? height;
          videoCodec = (stream.getCodec() ?? videoCodec).toLowerCase();
          fps = _parseFps(stream.getRealFrameRate());
          if (fps <= 0.0) {
            fps = _parseFps(stream.getAverageFrameRate());
          }
        } else if (type == 'audio') {
          audioCodec = (stream.getCodec() ?? audioCodec).toLowerCase();
          sampleRate = int.tryParse(stream.getSampleRate() ?? '') ?? sampleRate;
          final allProps = stream.getAllProperties();
          if (allProps != null && allProps['channels'] != null) {
            channels = int.tryParse(allProps['channels'].toString()) ?? channels;
          }
        }
      }

      return VideoFormatInfo(
        videoCodec: videoCodec,
        audioCodec: audioCodec,
        width: width,
        height: height,
        fps: fps,
        sampleRate: sampleRate,
        channels: channels,
        durationSeconds: durationSeconds,
        bitrate: bitrate,
      );
    } catch (e) {
      secureLog('FFprobe error on "$path": $e');
      return null;
    }
  }

  static bool isShortsVideoCompliant(VideoFormatInfo info) {
    final fpsOk = (info.fps - 30.0).abs() <= 0.5;
    final codecOk = info.videoCodec.contains('h264') || info.videoCodec.contains('avc');
    return info.width == 1080 && info.height == 1920 && fpsOk && codecOk;
  }

  static bool isShortsAudioCompliant(VideoFormatInfo info) {
    final codecOk = info.audioCodec.contains('aac');
    final sampleRateOk = info.sampleRate == 44100 || info.sampleRate == 48000;
    final channelsOk = info.channels == 2;
    return codecOk && sampleRateOk && channelsOk;
  }

  static bool isShortsCompliant(VideoFormatInfo info) {
    return isShortsVideoCompliant(info) && isShortsAudioCompliant(info);
  }

  /// Executes an FFmpeg command with a central mutex lock and optional cleanup.
  static Future<bool> execute(String command, {List<String>? tempFilesToCleanup}) async {
    await _acquireLock();
    try {
      final safeCommand = command.contains('-loglevel')
          ? command
          : '-hide_banner -loglevel error $command';
      final session = await FFmpegKit.execute(safeCommand);
      final code = await session.getReturnCode();
      final success = code != null && code.isValueSuccess();
      if (!success) {
        final failStackTrace = await session.getFailStackTrace();
        final logs = await session.getLogs();
        final logText = logs.map((l) => l.getMessage()).join('\n');
        debugPrint('--- FFmpeg Session Failed ---');
        debugPrint('Command: $safeCommand');
        debugPrint('Return Code: $code');
        debugPrint('Fail Stack Trace: $failStackTrace');
        debugPrint('Logs:\n$logText');
        debugPrint('-----------------------------');
      }

      // Clean up temporary files immediately
      if (tempFilesToCleanup != null) {
        for (final path in tempFilesToCleanup) {
          try {
            final file = File(path);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            secureLog('Error cleaning temporary file $path: $e');
          }
        }
      }

      return success;
    } catch (e) {
      secureLog('FFmpegRunner execution error: $e');
      return false;
    } finally {
      _releaseLock();
    }
  }
}
