import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import '../services/ffmpeg_runner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../services/video_processing_provider.dart';
import 'upload_screen.dart';
import 'video_editor_screen.dart';
import '../main.dart';
import '../services/security_service.dart';
import '../widgets/scale_button.dart';
import '../widgets/orientation_choice_dialog.dart';
import '../services/upload_queue_service.dart';
import '../services/db_helper.dart';
import '../models/history_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const _shareChannel = MethodChannel('com.videofixer.video_fixer/share');

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initShareIntentListener();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _initShareIntentListener() {
    _shareChannel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedVideo') {
        final path = call.arguments as String?;
        if (path != null) _handleSharedVideo(path);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkColdStartShare());
  }

  Future<void> _checkColdStartShare() async {
    try {
      final path = await _shareChannel.invokeMethod<String>('getSharedVideo');
      if (path != null) _handleSharedVideo(path);
    } catch (e) {
      secureLog('Error getting cold start shared video: $e');
    }
  }

  void _handleSharedVideo(String filePath) async {
    final fileName = p.basename(filePath);
    final sizeBytes = File(filePath).lengthSync();
    final sizeMB = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);

    MainTabScreen.onSwitchTab?.call(0);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.video_library, color: Color(0xFFFF0000), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Video qabul qilindi',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('$fileName • $sizeMB MB',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Nima qilmoqchisiz?',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A2A2A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _onSelectProcessSharedVideo(filePath);
                },
                icon: const Icon(Icons.movie_creation_outlined, color: Colors.white),
                label: const Text('Videoga ishlov berish',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0000),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _onSelectUploadSharedVideo(filePath);
                },
                icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white),
                label: const Text('YouTube ga yuklash',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Bekor qilish', style: TextStyle(color: Colors.white54, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSelectProcessSharedVideo(String filePath) async {
    double durationSecs = 0.0;
    try {
      final mediaInfo = await FFprobeKit.getMediaInformation(filePath);
      final info = mediaInfo.getMediaInformation();
      if (info != null) {
        durationSecs = double.tryParse(info.getDuration() ?? '') ?? 0.0;
      }
    } catch (e) {
      secureLog('Error checking duration: $e');
    }

    final sizeMB = (File(filePath).lengthSync() / (1024 * 1024)).toStringAsFixed(1);
    String? thumbPath;
    try {
      final tempDir = await getTemporaryDirectory();
      thumbPath = p.join(tempDir.path, 'home_video_thumb.jpg');
      await FFmpegRunner.execute('-y -ss 00:00:01 -i "$filePath" -vframes 1 -s 320x180 "$thumbPath"');
    } catch (e) {
      secureLog('Thumbnail generation failed: $e');
    }

    if (!mounted) return;
    final provider = Provider.of<VideoProcessingProvider>(context, listen: false);
    provider.selectVideo(filePath, sizeMB: sizeMB, durationSecs: durationSecs, thumbPath: thumbPath);
    provider.setInputFormatInfo(await FFmpegRunner.probeVideo(filePath));
    provider.setNeedsTrim(false);
    provider.setTrimDuration(0);

    final formatInfo = provider.inputFormatInfo;
    final defaultMode = (formatInfo != null && formatInfo.isVertical)
        ? ProcessMode.verticalCompliance
        : ProcessMode.horizontalToShorts;

    if (durationSecs <= 60.1) {
      provider.startProcessing(mode: defaultMode);
    } else {
      // If it is landscape, ask user first before forcing editor
      final formatInfo = await FFmpegRunner.probeVideo(filePath);
      if (formatInfo != null && !formatInfo.isVertical) {
        if (!mounted) return;
        final mode = await showOrientationChoiceSheet(context, formatInfo);
        if (mode == null) return;
        if (mode == ProcessMode.horizontalToShorts) {
          _showShortsOptionsBottomSheet(mode: ProcessMode.horizontalToShorts);
        } else {
          // Direct 16:9 upload flow -> no trim, proceed with direct processing
          provider.startProcessing(mode: ProcessMode.horizontalDirectUpload);
        }
        return;
      }

      if (!mounted) return;
      final String? trimmedPath = await Navigator.push(
        context,
        _slideUpRoute(VideoEditorScreen(filePath: filePath)),
      );
      if (trimmedPath != null) {
        double trimmedDuration = 0.0;
        try {
          final mediaInfo = await FFprobeKit.getMediaInformation(trimmedPath);
          final info = mediaInfo.getMediaInformation();
          if (info != null) trimmedDuration = double.tryParse(info.getDuration() ?? '') ?? 0.0;
        } catch (_) {}

        final trimmedSizeMB = (File(trimmedPath).lengthSync() / (1024 * 1024)).toStringAsFixed(1);
        String? trimmedThumbPath;
        try {
          final tempDir = await getTemporaryDirectory();
          trimmedThumbPath = p.join(tempDir.path, 'home_video_thumb_trimmed.jpg');
          await FFmpegRunner.execute('-y -ss 00:00:01 -i "$trimmedPath" -vframes 1 -s 320x180 "$trimmedThumbPath"');
        } catch (_) {}

        provider.selectVideo(trimmedPath, sizeMB: trimmedSizeMB, durationSecs: trimmedDuration, thumbPath: trimmedThumbPath);
        provider.setInputFormatInfo(await FFmpegRunner.probeVideo(trimmedPath));
        provider.setNeedsTrim(false);
        provider.setTrimDuration(0);
        provider.startProcessing(mode: defaultMode);
      }
    }
  }

  Future<void> _onSelectUploadSharedVideo(String filePath) async {
    double durationSecs = 0.0;
    try {
      final mediaInfo = await FFprobeKit.getMediaInformation(filePath);
      final info = mediaInfo.getMediaInformation();
      if (info != null) durationSecs = double.tryParse(info.getDuration() ?? '') ?? 0.0;
    } catch (e) {
      secureLog('Error checking duration: $e');
    }

    final sizeMB = (File(filePath).lengthSync() / (1024 * 1024)).toStringAsFixed(1);
    String? thumbPath;
    try {
      final tempDir = await getTemporaryDirectory();
      thumbPath = p.join(tempDir.path, 'home_video_thumb.jpg');
      await FFmpegRunner.execute('-y -ss 00:00:01 -i "$filePath" -vframes 1 -s 320x180 "$thumbPath"');
    } catch (e) {
      secureLog('Thumbnail generation failed: $e');
    }

    if (!mounted) return;
    final provider = Provider.of<VideoProcessingProvider>(context, listen: false);
    provider.selectVideo(filePath, sizeMB: sizeMB, durationSecs: durationSecs, thumbPath: thumbPath);
    provider.setInputFormatInfo(await FFmpegRunner.probeVideo(filePath));

    final formatInfoForUpload = await FFmpegRunner.probeVideo(filePath);
    final isLnd = formatInfoForUpload != null && !formatInfoForUpload.isVertical;

    if (isLnd) {
      // Landscape video can be uploaded directly as 16:9 non-Shorts or Shorts
      if (!mounted) return;
      final mode = await showOrientationChoiceSheet(context, formatInfoForUpload);
      if (mode == null) return;
      if (mode == ProcessMode.horizontalDirectUpload) {
        // Direct non-Shorts 16:9 flow -> no trim, proceed to UploadScreen as non-Shorts
        if (!mounted) return;
        Navigator.push(context, _slideUpRoute(UploadScreen(filePath: filePath, isShorts: false)));
        return;
      }
    }

    if (durationSecs <= 60.1) {
      if (!mounted) return;
      Navigator.push(context, _slideUpRoute(UploadScreen(filePath: filePath, isShorts: true)));
    } else {
      if (!mounted) return;
      final String? trimmedPath = await Navigator.push(context, _slideUpRoute(VideoEditorScreen(filePath: filePath)));
      if (trimmedPath != null) {
        double trimmedDuration = 0.0;
        try {
          final mediaInfo = await FFprobeKit.getMediaInformation(trimmedPath);
          final info = mediaInfo.getMediaInformation();
          if (info != null) trimmedDuration = double.tryParse(info.getDuration() ?? '') ?? 0.0;
        } catch (_) {}

        final trimmedSizeMB = (File(trimmedPath).lengthSync() / (1024 * 1024)).toStringAsFixed(1);
        String? trimmedThumbPath;
        try {
          final tempDir = await getTemporaryDirectory();
          trimmedThumbPath = p.join(tempDir.path, 'home_video_thumb_trimmed.jpg');
          await FFmpegRunner.execute('-y -ss 00:00:01 -i "$trimmedPath" -vframes 1 -s 320x180 "$trimmedThumbPath"');
        } catch (_) {}

        provider.selectVideo(trimmedPath, sizeMB: trimmedSizeMB, durationSecs: trimmedDuration, thumbPath: trimmedThumbPath);
        provider.setInputFormatInfo(await FFmpegRunner.probeVideo(trimmedPath));
        if (!mounted) return;
        Navigator.push(context, _slideUpRoute(UploadScreen(filePath: trimmedPath, isShorts: true)));
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: false);
      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null) return;

      final sizeMB = (File(path).lengthSync() / (1024 * 1024)).toStringAsFixed(1);
      double durationSecs = 0.0;

      final mediaInfo = await FFprobeKit.getMediaInformation(path);
      final info = mediaInfo.getMediaInformation();
      if (info != null) {
        durationSecs = double.tryParse(info.getDuration() ?? '') ?? 0.0;
      }

      String? thumbPath;
      try {
        final tempDir = await getTemporaryDirectory();
        thumbPath = p.join(tempDir.path, 'home_video_thumb.jpg');
        await FFmpegRunner.execute('-y -ss 00:00:01 -i "$path" -vframes 1 -s 320x180 "$thumbPath"');
      } catch (e) {
        secureLog('Thumbnail generation failed: $e');
      }

      if (!mounted) return;
      final provider = Provider.of<VideoProcessingProvider>(context, listen: false);
      if (durationSecs > 60.0) {
        provider.setNeedsTrim(true);
        provider.setTrimDuration(60);
      } else {
        provider.setNeedsTrim(false);
        provider.setTrimDuration(0);
      }
      provider.selectVideo(path, sizeMB: sizeMB, durationSecs: durationSecs, thumbPath: thumbPath);
      final formatInfo = await FFmpegRunner.probeVideo(path);
      if (!mounted) return;
      provider.setInputFormatInfo(formatInfo);
    } catch (e) {
      secureLog('Error picking video: $e');
    }
  }

  /// Entry point: detect orientation and route to the right flow.
  Future<void> _startProcessFlow() async {
    final provider = Provider.of<VideoProcessingProvider>(context, listen: false);
    final info = provider.inputFormatInfo;

    if (info == null || info.isVertical) {
      // Already portrait or unknown — skip the orientation dialog, go straight to compliance
      provider.startProcessing(mode: ProcessMode.verticalCompliance);
    } else {
      // Landscape video — ask the user what to do
      if (!mounted) return;
      final mode = await showOrientationChoiceSheet(context, info);
      if (mode == null || !mounted) return;

      if (mode == ProcessMode.horizontalToShorts) {
        _showShortsOptionsBottomSheet(mode: ProcessMode.horizontalToShorts);
      } else {
        // Direct horizontal 16:9 upload flow has no 60-second limit and doesn't trim
        provider.startProcessing(mode: ProcessMode.horizontalDirectUpload);
      }
    }
  }

  void _showShortsOptionsBottomSheet({ProcessMode mode = ProcessMode.horizontalToShorts}) {
    final provider = Provider.of<VideoProcessingProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Shorts Sozlamalari',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Gorizontal videoni moslashtirish usuli:',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                      value: 'blur', label: Text('Blur', style: TextStyle(color: Colors.white))),
                  ButtonSegment<String>(
                      value: 'crop', label: Text('Crop', style: TextStyle(color: Colors.white))),
                  ButtonSegment<String>(
                      value: 'black', label: Text('Qora fon', style: TextStyle(color: Colors.white))),
                ],
                selected: {provider.shortsStyle},
                onSelectionChanged: (selection) {
                  final style = selection.first;
                  setSheetState(() {});
                  provider.setShortsStyle(style);
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) return const Color(0xFFFF0000);
                    return const Color(0xFF2A2A2A);
                  }),
                ),
              ),
              if (provider.needsTrim) ...[
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Video 60 soniyadan uzun! Avtomatik 60 soniyaga qisqartiriladi.',
                        style: TextStyle(color: Colors.orangeAccent, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF0000),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    provider.startProcessing(mode: mode);
                  },
                  child: const Text('Boshlash',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reset() => Provider.of<VideoProcessingProvider>(context, listen: false).reset();

  PageRouteBuilder<T> _slideUpRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
        );
        final scale = Tween<double>(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
        );
        return SlideTransition(
            position: slide, child: ScaleTransition(scale: scale, child: child));
      },
    );
  }

  String _formatTime(double seconds) {
    final int m = (seconds / 60).floor();
    final int s = (seconds % 60).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<VideoProcessingProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              _buildHeader(),
              const SizedBox(height: 24),
              _buildStateCard(provider),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF0000).withValues(alpha: 0.35),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset('assets/logo.png', fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'VideoFixer',
          style: TextStyle(
              color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: 6),
        Text(
          'Shorts Converter',
          style:
              TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14, letterSpacing: 1.5),
        ),
      ],
    );
  }

  // ─── Unified state card ──────────────────────────────────────────────────

  Color _borderColor(ProcessState state) {
    if (state == ProcessState.processing || state == ProcessState.uploading) {
      return const Color(0xFFFF0000).withValues(alpha: 0.35);
    }
    if (state == ProcessState.done) return Colors.greenAccent.withValues(alpha: 0.3);
    if (state == ProcessState.error) return Colors.orange.withValues(alpha: 0.3);
    return Colors.white12;
  }

  Widget _buildStateCard(VideoProcessingProvider provider) {
    final state = provider.processingState;
    final inputPath = provider.selectedVideoPath;

    final String cardKey;
    if (state == ProcessState.idle && inputPath == null) {
      cardKey = 'pick';
    } else if (state == ProcessState.idle) {
      cardKey = 'selected';
    } else if (state == ProcessState.processing || state == ProcessState.uploading) {
      cardKey = 'processing';
    } else if (state == ProcessState.done) {
      cardKey = 'done';
    } else {
      cardKey = 'error';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
          ),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(cardKey),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _borderColor(state), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _borderColor(state).withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: switch (cardKey) {
          'pick' => _buildPickContent(),
          'selected' => _buildSelectedContent(provider),
          'processing' => _buildProcessingContent(provider),
          'done' => _buildDoneContent(provider),
          _ => _buildErrorContent(provider),
        },
      ),
    );
  }

  // ─── Pick state ──────────────────────────────────────────────────────────

  Widget _buildPickContent() {
    return Column(
      children: [
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) => Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFFF0000)
                  .withValues(alpha: 0.06 + 0.04 * _pulseAnimation.value),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF0000)
                      .withValues(alpha: 0.15 * _pulseAnimation.value),
                  blurRadius: 24 * _pulseAnimation.value,
                  spreadRadius: 4 * _pulseAnimation.value,
                ),
              ],
            ),
            child: const Icon(Icons.video_file_outlined,
                color: Color(0xFFFF0000), size: 52),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Video tanlash uchun bosing',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          'MP4, MOV, AVI va boshqalar',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
        ),
        const SizedBox(height: 28),
        ScaleButton(
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.video_library_outlined, color: Colors.white),
              label: const Text('Video Tanlash',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0000),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ─── Video selected state ─────────────────────────────────────────────────

  Widget _buildSelectedContent(VideoProcessingProvider provider) {
    final inputPath = provider.selectedVideoPath!;
    final info = provider.inputFormatInfo;
    final fileName = p.basename(inputPath);

    final videoOk = info != null && FFmpegRunner.isShortsVideoCompliant(info);
    final audioOk = info != null && FFmpegRunner.isShortsAudioCompliant(info);
    final durationOk = info == null || info.durationSeconds <= 60.1;

    Widget chip(String label, bool ok) {
      final color = ok ? Colors.greenAccent : Colors.orangeAccent;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ok ? Icons.check_circle : Icons.warning_rounded, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.video_library, color: Color(0xFFFF0000), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (provider.videoSizeMB != null)
                    Text(
                      '${provider.videoSizeMB} MB • ${_formatTime(provider.videoDurationSecs)}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (provider.videoThumbnailPath != null)
                  Image.file(File(provider.videoThumbnailPath!), fit: BoxFit.cover)
                else
                  Container(
                    color: Colors.black38,
                    child: const Center(
                        child: Icon(Icons.movie_creation, size: 48, color: Colors.white24)),
                  ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Format chips
        if (info != null) ...[
          const Text('Shorts Format Holati',
              style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [chip('Video', videoOk), chip('Audio', audioOk), chip('Davomiylik', durationOk)],
          ),
          const SizedBox(height: 4),
          Text(
            '${info.width}×${info.height} • ${info.fps.toStringAsFixed(0)}fps • ${info.videoCodec.toUpperCase()} / ${info.audioCodec.toUpperCase()}',
            style: const TextStyle(color: Colors.white30, fontSize: 11),
          ),
          const SizedBox(height: 14),
        ] else ...[
          const Row(
            children: [
              SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)),
              SizedBox(width: 8),
              Text('Format tahlil qilinmoqda...', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
        ],

        // Volume slider
        Row(
          children: [
            const Icon(Icons.volume_down_outlined, color: Colors.white38, size: 18),
            Expanded(
              child: Slider(
                value: provider.volume,
                min: 0.0,
                max: 3.0,
                divisions: 30,
                activeColor: const Color(0xFFFF0000),
                inactiveColor: Colors.white12,
                onChanged: (val) => provider.setVolume(val),
              ),
            ),
            const Icon(Icons.volume_up_outlined, color: Colors.white38, size: 18),
            const SizedBox(width: 6),
            SizedBox(
              width: 36,
              child: Text(
                '${provider.volume.toStringAsFixed(1)}x',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),

        const Divider(color: Colors.white10, height: 24),

        // Action buttons
        ScaleButton(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0000),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _startProcessFlow,
              icon: const Icon(Icons.bolt, color: Colors.amber),
              label: const Text('Videoni qayta ishlash',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ScaleButton(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C2C2C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () => Navigator.push(context, _slideUpRoute(VideoEditorScreen(filePath: inputPath))),
              icon: const Icon(Icons.movie_filter, color: Colors.white70),
              label: const Text('Video Editor',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh, color: Colors.white38, size: 16),
            label: const Text('Boshqa video tanlash',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  // ─── Processing state ─────────────────────────────────────────────────────

  Widget _buildProcessingContent(VideoProcessingProvider provider) {
    final state = provider.processingState;
    final progress = provider.progress;
    final progressText = provider.progressText;
    final statusText = provider.statusText;
    final inputPath = provider.selectedVideoPath;

    int activeStep = 0;
    if (statusText.toLowerCase().contains('tahlil')) {
      activeStep = 0;
    } else if (statusText.toLowerCase().contains('tayyorlanmoqda') ||
        statusText.toLowerCase().contains('tekshirilmoqda') ||
        statusText.toLowerCase().contains('konvertatsiya')) {
      activeStep = 1;
    } else if (statusText.toLowerCase().contains('saqlandi') ||
        statusText.toLowerCase().contains('sifat')) {
      activeStep = 2;
    } else {
      activeStep = 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mini file header
        if (inputPath != null) ...[
          Row(
            children: [
              if (provider.videoThumbnailPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(provider.videoThumbnailPath!),
                    width: 56,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  p.basename(inputPath),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // Progress bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Jarayon',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w500),
            ),
            Text(
              progressText.isEmpty ? '...' : progressText,
              style: const TextStyle(color: Color(0xFFFF4444), fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress == 0.0 || state == ProcessState.uploading ? null : progress,
            minHeight: 10,
            backgroundColor: const Color(0xFF2A2A2A),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
          ),
        ),

        // Processing Stepper (Analiz -> Konvertatsiya -> Saqlash)
        ProcessingStepper(activeIndex: activeStep),

        const SizedBox(height: 8),

        // Status text
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF4444)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8), fontSize: 13, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Done state ───────────────────────────────────────────────────────────

  Future<void> _addToUploadQueue(VideoProcessingProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    final outputPath = provider.outputPath;
    if (outputPath == null) return;

    final items = await DBHelper.instance.getAllHistory();
    final match = items.cast<HistoryItem?>().firstWhere(
          (i) => i?.filePath == outputPath,
          orElse: () => null,
        );
    if (match == null || match.id == null) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('Tarix yozuvini topib bo\'lmadi'),
        backgroundColor: Color(0xFF1E1E1E),
      ));
      return;
    }
    final success = await UploadQueueService.instance.addToQueue(match);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(success ? '✅ Navbatga qo\'shildi' : '❌ Xatolik yuz berdi'),
      backgroundColor: const Color(0xFF1E1E1E),
      duration: const Duration(seconds: 3),
    ));
  }

  Widget _buildDoneContent(VideoProcessingProvider provider) {
    final statusText = provider.statusText;
    final outputPath = provider.outputPath!;
    final isShortsMode = provider.isShortsMode;
    final isQualityDropped = statusText.contains('tushdi');

    return Column(
      children: [
        const SizedBox(height: 8),
        Icon(
          isQualityDropped ? Icons.warning_rounded : Icons.check_circle,
          size: 60,
          color: isQualityDropped ? Colors.orangeAccent : Colors.greenAccent,
        ),
        const SizedBox(height: 14),
        Text(
          isQualityDropped ? 'Sifat biroz tushdi' : 'Muvaffaqiyatli tayyor!',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          isQualityDropped
              ? 'Natija bitrate originaldan 30% dan ko\'proq past.'
              : 'Fayl saqlandi va Tarixga qo\'shildi.',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Output path
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📂 Downloads/VideoFixer/',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 4),
              Text(
                p.basename(outputPath),
                style:
                    const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Consumer<UploadQueueService>(
          builder: (context, queueService, child) {
            return Column(
              children: [
                ScaleButton(
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: queueService.isOnline
                          ? () => Navigator.push(
                                context,
                                _slideUpRoute(UploadScreen(
                                    filePath: outputPath, isShorts: isShortsMode)),
                              )
                          : null,
                      icon: const Icon(Icons.cloud_upload, color: Colors.white),
                      label: const Text("YouTube'ga yuklash",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        disabledBackgroundColor: Colors.white12,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                if (!queueService.isOnline) ...[
                  const SizedBox(height: 8),
                  ScaleButton(
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => _addToUploadQueue(provider),
                        icon:
                            const Icon(Icons.queue, color: Colors.white),
                        label: const Text("Navbatga qo'shish",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off,
                          size: 14,
                          color: Colors.orange.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text(
                        'Internet yo\'q — navbatga qo\'shing',
                        style: TextStyle(
                            color: Colors.orange.withValues(alpha: 0.7),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        ScaleButton(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Yangi Video',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A2A2A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Error state ──────────────────────────────────────────────────────────

  Widget _buildErrorContent(VideoProcessingProvider provider) {
    return Column(
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.error_outline, size: 56, color: Colors.orangeAccent),
        const SizedBox(height: 16),
        const Text('Xatolik yuz berdi',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          provider.statusText,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ScaleButton(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _startProcessFlow,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Qayta urinish',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0000),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.refresh, color: Colors.white38, size: 16),
          label: const Text('Boshqa video tanlash',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ),
      ],
    );
  }
}

class ProcessingStepper extends StatelessWidget {
  final int activeIndex; // 0 for Analiz, 1 for Konvertatsiya, 2 for Saqlash

  const ProcessingStepper({super.key, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    final stages = [
      {'label': 'Analiz', 'icon': Icons.search},
      {'label': 'Konvertatsiya', 'icon': Icons.autorenew},
      {'label': 'Saqlash', 'icon': Icons.save_outlined},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: List.generate(stages.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Divider/Line between steps
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex < activeIndex;
            return Expanded(
              child: Container(
                height: 2,
                color: isCompleted ? const Color(0xFF69F0AE) : const Color(0xFF2C2C2C),
              ),
            );
          }

          final stepIndex = index ~/ 2;
          final isCompleted = stepIndex < activeIndex;
          final isActive = stepIndex == activeIndex;

          final Color color = isCompleted
              ? const Color(0xFF69F0AE) // var(--green-accent)
              : isActive
                  ? const Color(0xFFFF0000) // var(--red-500)
                  : Colors.white24; // var(--text-disabled)

          final iconColor = isCompleted
              ? const Color(0xFF69F0AE)
              : isActive
                  ? const Color(0xFFFF0000)
                  : Colors.white24;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? const Color(0xFFFF0000).withValues(alpha: 0.12)
                      : isCompleted
                          ? const Color(0xFF69F0AE).withValues(alpha: 0.14)
                          : const Color(0xFF161616),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFFF0000).withValues(alpha: 0.5)
                        : isCompleted
                            ? const Color(0xFF69F0AE).withValues(alpha: 0.4)
                            : Colors.white10,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 18, color: Color(0xFF69F0AE))
                      : isActive
                          ? _SpinningIcon(icon: stages[stepIndex]['icon'] as IconData, color: iconColor)
                          : Icon(stages[stepIndex]['icon'] as IconData, size: 18, color: iconColor),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                stages[stepIndex]['label'] as String,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _SpinningIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _SpinningIcon({required this.icon, required this.color});

  @override
  State<_SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<_SpinningIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(widget.icon, size: 18, color: widget.color),
    );
  }
}
