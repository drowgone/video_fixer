import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'ffmpeg_runner.dart';
import 'db_helper.dart';
import 'security_service.dart';
import '../models/history_item.dart';

enum ProcessState { idle, picking, processing, uploading, done, error }

enum ProcessMode {
  /// Native vertical video — fix audio/video compliance for YouTube Shorts
  verticalCompliance,
  /// Horizontal video converted to 9:16 Shorts format
  horizontalToShorts,
  /// Horizontal video — fix audio only, keep original aspect ratio
  horizontalDirectUpload,
}

class VideoProcessingProvider extends ChangeNotifier {
  ProcessState _processingState = ProcessState.idle;
  String? _selectedVideoPath;
  String? _videoName;
  String? _videoSizeMB;
  double _videoDurationSecs = 0.0;
  double _progress = 0.0;
  String _progressText = '';
  String _statusText = 'Video tanlang va YouTube uchun audio formatini tuzating';
  String? _outputPath;
  bool _isShortsMode = false;
  ProcessMode _processMode = ProcessMode.horizontalDirectUpload;
  String? _videoThumbnailPath;
  VideoFormatInfo? _inputFormatInfo;

  // Shorts Configuration
  String _shortsStyle = 'blur';
  int _trimDuration = 0;
  bool _needsTrim = false;
  double _volume = 1.0;

  // Getters
  ProcessState get processingState => _processingState;
  String? get selectedVideoPath => _selectedVideoPath;
  String? get videoName => _videoName;
  String? get videoSizeMB => _videoSizeMB;
  double get videoDurationSecs => _videoDurationSecs;
  double get progress => _progress;
  String get progressText => _progressText;
  String get statusText => _statusText;
  String? get outputPath => _outputPath;
  bool get isShortsMode => _isShortsMode;
  ProcessMode get processMode => _processMode;
  String? get videoThumbnailPath => _videoThumbnailPath;
  VideoFormatInfo? get inputFormatInfo => _inputFormatInfo;

  String get shortsStyle => _shortsStyle;
  int get trimDuration => _trimDuration;
  bool get needsTrim => _needsTrim;
  double get volume => _volume;

  // Setters
  void setShortsStyle(String style) {
    _shortsStyle = style;
    notifyListeners();
  }

  void setTrimDuration(int duration) {
    _trimDuration = duration;
    notifyListeners();
  }

  void setNeedsTrim(bool needs) {
    _needsTrim = needs;
    notifyListeners();
  }

  void setVolume(double vol) {
    _volume = vol;
    notifyListeners();
  }

  void setInputFormatInfo(VideoFormatInfo? info) {
    _inputFormatInfo = info;
    notifyListeners();
  }

  void selectVideo(String path, {String? sizeMB, double? durationSecs, String? thumbPath}) {
    _selectedVideoPath = path;
    _videoName = p.basename(path);
    _videoSizeMB = sizeMB ?? (File(path).lengthSync() / (1024 * 1024)).toStringAsFixed(1);
    _videoDurationSecs = durationSecs ?? 0.0;
    _videoThumbnailPath = thumbPath;
    _processingState = ProcessState.idle;
    notifyListeners();
  }

  void reset() {
    _processingState = ProcessState.idle;
    _selectedVideoPath = null;
    _videoName = null;
    _videoSizeMB = null;
    _videoDurationSecs = 0.0;
    _progress = 0.0;
    _progressText = '';
    _statusText = 'Video tanlang va YouTube uchun audio formatini tuzating';
    _outputPath = null;
    _videoThumbnailPath = null;
    _inputFormatInfo = null;
    _processMode = ProcessMode.horizontalDirectUpload;
    notifyListeners();
  }

  bool _isVerticalVideo(VideoFormatInfo info) {
    if (info.width <= 0 || info.height <= 0) return false;
    return (info.height / info.width - 16 / 9).abs() < 0.25;
  }

  int _targetBitrate(double inputBitrate) {
    if (inputBitrate <= 0) return 6000000;
    if (inputBitrate < 4000000) return 4000000;
    if (inputBitrate > 8000000) return 8000000;
    return inputBitrate.toInt();
  }

  String _buildAudioFilter() {
    final filters = <String>[
      'aresample=44100',
      'aformat=channel_layouts=stereo',
    ];
    if ((_volume - 1.0).abs() > 0.01) {
      filters.add('volume=$_volume');
    }
    return filters.join(',');
  }

  Future<void> startProcessing({required ProcessMode mode}) async {
    if (_selectedVideoPath == null) return;
    final inputPath = _selectedVideoPath!;

    _processMode = mode;
    final bool isShorts = mode != ProcessMode.horizontalDirectUpload;

    _processingState = ProcessState.processing;
    _isShortsMode = isShorts;
    _progress = 0.0;
    _progressText = 'Tahlil qilinmoqda...';
    _statusText = '⚙️ Video tahlil qilinmoqda...';
    notifyListeners();

    final inputInfo = await FFmpegRunner.probeVideo(inputPath);
    if (inputInfo == null) {
      _processingState = ProcessState.error;
      _statusText = '❌ Video tahlilida xatolik yuz berdi.';
      notifyListeners();
      return;
    }

    final outputDir = await _getOutputDirectory();
    final inputFileName = p.basenameWithoutExtension(inputPath);
    final outputFileName = mode == ProcessMode.horizontalDirectUpload
        ? '${inputFileName}_fixed.mp4'
        : '${inputFileName}_shorts.mp4';
    final outputFilePath = p.join(outputDir, outputFileName);
    
    // Guaranteed secure temporary paths for FFmpeg execution
    final tempDir = await getTemporaryDirectory();
    final tempOutputFilePath = p.join(tempDir.path, 'temp_out_${DateTime.now().millisecondsSinceEpoch}_$outputFileName');
    final tempThumbnailPath = p.join(tempDir.path, 'temp_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg');

    _outputPath = outputFilePath;

    final bool isVertical = _isVerticalVideo(inputInfo);
    final bool shortsVideoCompliant = FFmpegRunner.isShortsVideoCompliant(inputInfo);
    final bool shortsAudioCompliant = FFmpegRunner.isShortsAudioCompliant(inputInfo);
    final bool needsVolumeChange = (_volume - 1.0).abs() > 0.01;

    int trimToSeconds = 0;
    if (isShorts) {
      if (_needsTrim && _trimDuration > 0) {
        trimToSeconds = _trimDuration > 60 ? 60 : _trimDuration;
      } else if (inputInfo.durationSeconds > 60.1) {
        trimToSeconds = 60;
      }
    }

    final bool needsTrim = trimToSeconds > 0;
    final bool needsVideoTranscode = isShorts ? !shortsVideoCompliant : false;
    final bool needsAudioTranscode = isShorts
        ? (!shortsAudioCompliant || needsVolumeChange)
        : true;
    final trimOpt = needsTrim ? '-t $trimToSeconds' : '';
    final audioFilter = _buildAudioFilter();

    String command = '';
    String? fallbackCommand;
    bool success = false;

    final startTime = DateTime.now();
    final timer = Timer.periodic(const Duration(milliseconds: 200), (t) {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      _progressText = '${elapsed.toStringAsFixed(1)}s';
      final label = switch (mode) {
        ProcessMode.horizontalToShorts => '⚡ Shorts tayyorlanmoqda...',
        ProcessMode.verticalCompliance => '📱 Moslik tekshirilmoqda...',
        ProcessMode.horizontalDirectUpload => '🔄 Audio konvertatsiya qilinmoqda...',
      };
      _statusText = '$label (${elapsed.toStringAsFixed(1)}s)';
      notifyListeners();
    });

    try {
      if (!needsTrim && !needsVideoTranscode && !needsAudioTranscode) {
        await File(inputPath).copy(tempOutputFilePath);
        success = true;
      } else if (!needsVideoTranscode && !needsAudioTranscode && needsTrim) {
        command = '-y -ss 0 -i "$inputPath" $trimOpt -c copy -movflags +faststart "$tempOutputFilePath"';
        success = await FFmpegRunner.execute(command);
      } else if (!needsVideoTranscode && needsAudioTranscode) {
        command = '-y -i "$inputPath" $trimOpt -c:v copy -c:a aac -ar 44100 -ac 2 -b:a 128k -filter:a "$audioFilter" -movflags +faststart "$tempOutputFilePath"';
        success = await FFmpegRunner.execute(command);
      } else if (isShorts) {
        final targetBitrate = _targetBitrate(inputInfo.bitrate);
        final videoEncoder = Platform.isAndroid ? 'h264_mediacodec' : 'libx264';
        final encoderFlags = Platform.isAndroid
            ? '-b:v $targetBitrate -maxrate $targetBitrate -pix_fmt yuv420p'
            : '-preset ultrafast -crf 26 -pix_fmt yuv420p';

        final videoFilter = isVertical
            ? 'scale=1080:1920:flags=fast_bilinear,fps=30,format=yuv420p'
            : (_shortsStyle == 'crop'
                ? 'scale=1080:1920:force_original_aspect_ratio=increase:flags=fast_bilinear,crop=1080:1920,fps=30,format=yuv420p'
                : '[0:v]scale=108:192:flags=fast_bilinear,gblur=sigma=2,scale=1080:1920:flags=fast_bilinear[bg];[0:v]scale=1080:-2:flags=fast_bilinear[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2,fps=30,format=yuv420p');

        if (videoFilter.startsWith('[')) {
          command = '-y -i "$inputPath" $trimOpt -filter_complex "$videoFilter" -c:v $videoEncoder $encoderFlags -c:a aac -ar 44100 -ac 2 -b:a 128k -filter:a "$audioFilter" -movflags +faststart "$tempOutputFilePath"';
          if (Platform.isAndroid) {
            fallbackCommand = '-y -i "$inputPath" $trimOpt -filter_complex "$videoFilter" -c:v libx264 -preset ultrafast -crf 26 -pix_fmt yuv420p -c:a aac -ar 44100 -ac 2 -b:a 128k -filter:a "$audioFilter" -movflags +faststart "$tempOutputFilePath"';
          }
        } else {
          command = '-y -i "$inputPath" $trimOpt -vf "$videoFilter" -c:v $videoEncoder $encoderFlags -c:a aac -ar 44100 -ac 2 -b:a 128k -filter:a "$audioFilter" -movflags +faststart "$tempOutputFilePath"';
          if (Platform.isAndroid) {
            fallbackCommand = '-y -i "$inputPath" $trimOpt -vf "$videoFilter" -c:v libx264 -preset ultrafast -crf 26 -pix_fmt yuv420p -c:a aac -ar 44100 -ac 2 -b:a 128k -filter:a "$audioFilter" -movflags +faststart "$tempOutputFilePath"';
          }
        }
        success = await FFmpegRunner.execute(command);
        if (!success && fallbackCommand != null) {
          success = await FFmpegRunner.execute(fallbackCommand);
        }
      } else {
        command = '-y -i "$inputPath" -c:v copy -c:a aac -ar 44100 -ac 2 -b:a 128k -filter:a "$audioFilter" -movflags +faststart "$tempOutputFilePath"';
        success = await FFmpegRunner.execute(command);
      }
    } finally {
      timer.cancel();
    }

    if (success) {
      await FFmpegRunner.execute('-y -ss 00:00:00.500 -i "$tempOutputFilePath" -vframes 1 -q:v 5 "$tempThumbnailPath"');
      
      final file = File(tempOutputFilePath);
      final size = await file.length();

      // Sifat tekshiruvi: bitrateni aniqlaymiz
      double outputBitrate = 0.0;
      final outInfo = await FFmpegRunner.probeVideo(tempOutputFilePath);
      if (outInfo != null) {
        outputBitrate = outInfo.bitrate;
      }

      bool qualityDropped = false;
      if (inputInfo.bitrate > 0 && outputBitrate > 0) {
        final dropPercentage = (inputInfo.bitrate - outputBitrate) / inputInfo.bitrate;
        if (dropPercentage >= 0.3) {
          qualityDropped = true;
        }
      }

      // Copy to public target path or fallback safely to app secure storage
      String finalOutputPath = outputFilePath;
      String finalThumbnailPath = p.join(outputDir, '.thumb_${DateTime.now().millisecondsSinceEpoch}.jpg');

      try {
        final targetDir = Directory(outputDir);
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
        
        final testFile = File(p.join(outputDir, '.test_copy'));
        await testFile.writeAsString('test');
        await testFile.delete();

        // Successful public write capability check, proceed to copy
        final finalOutputFile = File(finalOutputPath);
        if (await finalOutputFile.exists()) {
          await finalOutputFile.delete();
        }
        await File(tempOutputFilePath).copy(finalOutputPath);
        await File(tempOutputFilePath).delete();

        final finalThumbFile = File(finalThumbnailPath);
        if (await finalThumbFile.exists()) {
          await finalThumbFile.delete();
        }
        await File(tempThumbnailPath).copy(finalThumbnailPath);
        await File(tempThumbnailPath).delete();
      } catch (e) {
        // Fallback to app's secure external storage directory or application documents directory
        final extDir = await getExternalStorageDirectory();
        final fallbackDir = Directory(p.join(extDir?.path ?? (await getApplicationDocumentsDirectory()).path, 'VideoFixer'));
        if (!await fallbackDir.exists()) {
          await fallbackDir.create(recursive: true);
        }

        finalOutputPath = p.join(fallbackDir.path, outputFileName);
        finalThumbnailPath = p.join(fallbackDir.path, '.thumb_${DateTime.now().millisecondsSinceEpoch}.jpg');

        final finalOutputFile = File(finalOutputPath);
        if (await finalOutputFile.exists()) {
          await finalOutputFile.delete();
        }
        await File(tempOutputFilePath).copy(finalOutputPath);
        await File(tempOutputFilePath).delete();

        final finalThumbFile = File(finalThumbnailPath);
        if (await finalThumbFile.exists()) {
          await finalThumbFile.delete();
        }
        await File(tempThumbnailPath).copy(finalThumbnailPath);
        await File(tempThumbnailPath).delete();
      }

      _outputPath = finalOutputPath;

      final historyFormat = switch (mode) {
        ProcessMode.horizontalDirectUpload => 'Normal',
        _ => 'Shorts',
      };
      final item = HistoryItem(
        videoName: p.basename(finalOutputPath),
        thumbnailPath: finalThumbnailPath,
        filePath: finalOutputPath,
        sizeBytes: size,
        format: historyFormat,
        date: DateTime.now(),
      );
      
      await DBHelper.instance.insertHistory(item);

      _processingState = ProcessState.done;
      _progress = 1.0;
      _progressText = '100%';
      if (qualityDropped) {
        _statusText = '⚠️ Sifat biroz tushdi ⚠️\nNatija bitrate originaldan 30% dan ko\'p past.';
      } else {
        _statusText = '✅ Sifat saqlandi ✅\nFayl muvaffaqiyatli saqlandi va Tarixga qo\'shildi.';
      }
      notifyListeners();
    } else {
      // Clean up temp files if failed
      try {
        final tempFile = File(tempOutputFilePath);
        if (await tempFile.exists()) await tempFile.delete();
        final tempThumb = File(tempThumbnailPath);
        if (await tempThumb.exists()) await tempThumb.delete();
      } catch (_) {}

      _processingState = ProcessState.error;
      _statusText = '❌ Videoga ishlov berishda xatolik yuz berdi.';
      notifyListeners();
    }
  }

  static Future<void> cleanupOrphanedTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cutoff = DateTime.now().subtract(const Duration(hours: 1));
      await for (final entity in tempDir.list()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.startsWith('temp_out_') && !name.startsWith('temp_thumb_')) {
          continue;
        }
        try {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete();
          }
        } catch (_) {}
      }
    } catch (e) {
      secureLog('cleanupOrphanedTempFiles error: $e');
    }
  }

  Future<String> _getOutputDirectory() async {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download/VideoFixer');
      try {
        if (!await dir.exists()) await dir.create(recursive: true);
        final testFile = File(p.join(dir.path, '.test_write'));
        await testFile.writeAsString('write_test');
        await testFile.delete();
      } catch (e) {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          dir = Directory(p.join(extDir.path, 'VideoFixer'));
        } else {
          final docs = await getApplicationDocumentsDirectory();
          dir = Directory(p.join(docs.path, 'VideoFixer'));
        }
        if (!await dir.exists()) await dir.create(recursive: true);
      }
    } else {
      final docs = await getApplicationDocumentsDirectory();
      dir = Directory(p.join(docs.path, 'VideoFixer'));
      if (!await dir.exists()) await dir.create(recursive: true);
    }
    return dir.path;
  }
}
