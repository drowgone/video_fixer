import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'upload_screen.dart';
import '../services/ffmpeg_runner.dart';
import '../services/security_service.dart';

import 'video_editor/video_editor_models.dart';
import 'video_editor/video_editor_timeline.dart';
import 'video_editor/video_editor_panels.dart';
// --- VIDEO EDITOR SCREEN ---

class VideoEditorScreen extends StatefulWidget {
  final String filePath;

  const VideoEditorScreen({super.key, required this.filePath});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> with SingleTickerProviderStateMixin {
  // Picker Colors alias from models
  final List<Color> _pickerColors = pickerColors;

  // Undo/Redo Stacks
  final List<VideoLayer> _undoStack = [];
  final List<VideoLayer> _redoStack = [];

  // Active video configuration state
  late VideoLayer _currentState;

  VideoPlayerController? _videoPlayerController;
  final List<ja.AudioPlayer> _audioPlayers = [];
  
  double _totalDuration = 0.0;
  double _currentTime = 0.0;

  // Interactive Crop Area (0.0 to 1.0 relative coordinates)
  double _cropLeft = 0.1;
  double _cropTop = 0.1;
  double _cropWidth = 0.8;
  double _cropHeight = 0.8;
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isPlaying = false;
  
  // Selection
  String? _selectedTextId;
  String? _selectedStickerId;
  String? _selectedAudioId;
  // 'cut', 'text', 'sticker', 'audio', 'speed', 'volume', 'none'
  String _activeTool = 'cut';
  bool _toolPanelOpen = true;
  final ValueNotifier<double> _pixelsPerSecondNotifier = ValueNotifier<double>(80.0);
  Timer? _zoomDebounceTimer;

  void _onZoomChanged(double newValue) {
    _zoomDebounceTimer?.cancel();
    _zoomDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _pixelsPerSecondNotifier.value = newValue;
      }
    });
  }

  // Custom visual state listener ticker
  Timer? _syncTimer;

  // List of 10 modern premium fonts
  final List<String> _fonts = [
    'Roboto',
    'Poppins',
    'Montserrat',
    'Pacifico',
    'Dancing Script',
    'Bebas Neue',
    'Nunito',
    'Raleway',
    'Anton',
    'Righteous',
  ];

  @override
  void initState() {
    super.initState();
    _currentState = VideoLayer(
      startCut: 0.0,
      endCut: 0.0,
      speed: 1.0,
      originalVolume: 1.0,
      texts: [],
      stickers: [],
      audios: [],
    );
    _initializePlayers();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _zoomDebounceTimer?.cancel();
    _pixelsPerSecondNotifier.dispose();
    _videoPlayerController?.dispose();
    for (var player in _audioPlayers) {
      player.dispose();
    }
    
    // Temporary files cleanup when editor closes
    for (var audio in _currentState.audios) {
      try {
        final file = File(audio.path);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
    }
    super.dispose();
  }

  // --- INITIALIZE & SYNCHRONIZE ---

  Future<void> _initializePlayers() async {
    try {
      _videoPlayerController = VideoPlayerController.file(File(widget.filePath));
      await _videoPlayerController!.initialize();
      final duration = _videoPlayerController!.value.duration.inMilliseconds / 1000.0;

      setState(() {
        _totalDuration = duration;
        _currentState = _currentState.copyWith(
          startCut: 0.0,
          endCut: duration > 60.0 ? 60.0 : duration,
        );
        _isLoading = false;
      });

      // Synchronize listener updating timing
      _videoPlayerController!.addListener(() {
        if (_videoPlayerController != null && _videoPlayerController!.value.isPlaying) {
          setState(() {
            _currentTime = _videoPlayerController!.value.position.inMilliseconds / 1000.0;
            // Stop loop playback if limits met
            if (_currentTime >= _currentState.endCut) {
              _currentTime = _currentState.startCut;
              _videoPlayerController!.seekTo(Duration(milliseconds: (_currentState.startCut * 1000).toInt()));
              _syncAudioClips();
            }
          });
        }
      });

      // Seek to beginning crop start
      _videoPlayerController!.seekTo(Duration(milliseconds: (_currentState.startCut * 1000).toInt()));
    } catch (e) {
      secureLog('Error initializing video player: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _syncAudioClips() {
    // Seek active players and play if synchronized
    int idx = 0;
    for (var audio in _currentState.audios) {
      if (idx < _audioPlayers.length) {
        final player = _audioPlayers[idx];
        final relativeTime = _currentTime - audio.startTime;
        if (relativeTime >= 0 && relativeTime < audio.duration) {
          player.seek(Duration(milliseconds: ((audio.trimStart + relativeTime) * 1000).toInt()));
          if (_isPlaying) {
            player.play();
          }
        } else {
          player.pause();
        }
      }
      idx++;
    }
  }

  void _togglePlayback() {
    if (_videoPlayerController == null) return;

    if (_isPlaying) {
      _videoPlayerController!.pause();
      for (var player in _audioPlayers) {
        player.pause();
      }
      setState(() {
        _isPlaying = false;
      });
    } else {
      _videoPlayerController!.seekTo(Duration(milliseconds: (_currentTime * 1000).toInt()));
      _videoPlayerController!.setVolume(_currentState.originalVolume);
      _videoPlayerController!.play();
      
      // Setup audio players play state matching video sync
      _syncAudioClips();

      setState(() {
        _isPlaying = true;
      });
    }
  }

  // --- STATE STACK HELPERS ---

  void _saveState() {
    _undoStack.add(
      VideoLayer(
        startCut: _currentState.startCut,
        endCut: _currentState.endCut,
        speed: _currentState.speed,
        originalVolume: _currentState.originalVolume,
        texts: _currentState.texts.map((t) => t.copyWith()).toList(),
        stickers: _currentState.stickers.map((s) => s.copyWith()).toList(),
        audios: _currentState.audios.map((a) => a.copyWith()).toList(),
      ),
    );
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isNotEmpty) {
      _redoStack.add(
        VideoLayer(
          startCut: _currentState.startCut,
          endCut: _currentState.endCut,
          speed: _currentState.speed,
          originalVolume: _currentState.originalVolume,
          texts: _currentState.texts.map((t) => t.copyWith()).toList(),
          stickers: _currentState.stickers.map((s) => s.copyWith()).toList(),
          audios: _currentState.audios.map((a) => a.copyWith()).toList(),
        ),
      );
      setState(() {
        _currentState = _undoStack.removeLast();
        _syncAudioClips();
      });
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      _undoStack.add(
        VideoLayer(
          startCut: _currentState.startCut,
          endCut: _currentState.endCut,
          speed: _currentState.speed,
          originalVolume: _currentState.originalVolume,
          texts: _currentState.texts.map((t) => t.copyWith()).toList(),
          stickers: _currentState.stickers.map((s) => s.copyWith()).toList(),
          audios: _currentState.audios.map((a) => a.copyWith()).toList(),
        ),
      );
      setState(() {
        _currentState = _redoStack.removeLast();
        _syncAudioClips();
      });
    }
  }

  // --- OVERLAY LAYER HELPERS ---

  void _addTextOverlay() {
    _saveState();
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newText = TextLayer(
      id: newId,
      text: 'Matn',
      position: const Offset(0.5, 0.5),
      fontFamily: 'Poppins',
      startTime: _currentState.startCut,
      duration: math.min(10.0, _currentState.endCut - _currentState.startCut),
    );
    setState(() {
      _currentState.texts.add(newText);
      _selectedTextId = newId;
      _selectedStickerId = null;
      _selectedAudioId = null;
      _activeTool = 'text';
    });
  }

  void _addStickerOverlay(String emoji) {
    _saveState();
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newSticker = StickerLayer(
      id: newId,
      emoji: emoji,
      position: const Offset(0.5, 0.5),
      startTime: _currentState.startCut,
      duration: math.min(10.0, _currentState.endCut - _currentState.startCut),
    );
    setState(() {
      _currentState.stickers.add(newSticker);
      _selectedStickerId = newId;
      _selectedTextId = null;
      _selectedAudioId = null;
      _activeTool = 'sticker';
    });
  }

  void _addAudioOverlay(String path, String title) async {
    _saveState();
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newAudio = AudioLayer(
      id: newId,
      path: path,
      title: title,
      startTime: _currentTime,
      duration: math.min(15.0, _currentState.endCut - _currentTime),
    );

    // Initialize actual ja.AudioPlayer
    final player = ja.AudioPlayer();
    try {
      await player.setFilePath(path);
      player.setVolume(1.0);
      _audioPlayers.add(player);
    } catch (e) {
      secureLog('Audio load failed: $e');
    }

    setState(() {
      _currentState.audios.add(newAudio);
      _selectedAudioId = newId;
      _selectedTextId = null;
      _selectedStickerId = null;
      _activeTool = 'audio';
    });

    _showMusicSettingsDialog(newAudio);
  }

  // --- AUDIO MUTING OPTIONS ---

  void _showMusicSettingsDialog(AudioLayer audio) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.music_note, color: Colors.greenAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      audio.title,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Video original ovozi:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Slider(
                    value: _currentState.originalVolume,
                    min: 0.0,
                    max: 1.0,
                    activeColor: Colors.redAccent,
                    inactiveColor: Colors.white12,
                    onChanged: (val) {
                      setDialogState(() {
                        _currentState = _currentState.copyWith(originalVolume: val);
                      });
                      setState(() {});
                      _videoPlayerController?.setVolume(val);
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hajmi: ${(_currentState.originalVolume * 100).toInt()}%',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            _currentState = _currentState.copyWith(originalVolume: 0.0);
                          });
                          setState(() {});
                          _videoPlayerController?.setVolume(0.0);
                        },
                        icon: const Icon(Icons.volume_off, color: Colors.redAccent, size: 16),
                        label: const Text('Ovozni o\'chirish', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tayyor', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- AUDIO SOURCES SELECTION DRAWER ---

  void _showAddMusicDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🎵 Musiqa qo\'shish',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E2E2E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        final result = await FilePicker.platform.pickFiles(type: FileType.audio);
                        if (result != null && result.files.single.path != null) {
                          _addAudioOverlay(result.files.single.path!, result.files.single.name);
                        }
                      },
                      icon: const Icon(Icons.phone_android, color: Colors.white, size: 16),
                      label: const Text('Telefondan', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF0000),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        final tempDir = await getTemporaryDirectory();
                        final recPath = p.join(tempDir.path, 'voice_${DateTime.now().millisecondsSinceEpoch}.mp3');
                        await FFmpegRunner.execute('-y -f lavfi -i anullsrc=r=44100:cl=stereo -t 8 -q:a 9 -acodec libmp3lame "$recPath"');
                        _addAudioOverlay(recPath, 'Yozib olingan ovoz 🎤');
                      },
                      icon: const Icon(Icons.mic, color: Colors.white, size: 16),
                      label: const Text('Ovoz yozish', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Tavsiya etilgan musiqalar:', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    _buildTemplateRow('Shorts Energy Beat', 'energy_beat.mp3'),
                    _buildTemplateRow('Chill Lo-fi Vibe', 'lofi_vibe.mp3'),
                    _buildTemplateRow('Epic Vlog Background', 'epic_bg.mp3'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTemplateRow(String title, String fileName) {
    return ListTile(
      leading: const Icon(Icons.music_note, color: Colors.greenAccent),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
      trailing: const Icon(Icons.add_circle, color: Colors.greenAccent),
      onTap: () async {
        Navigator.pop(context);
        final tempDir = await getTemporaryDirectory();
        final path = p.join(tempDir.path, fileName);
        await FFmpegRunner.execute('-y -f lavfi -i anullsrc=r=44100:cl=stereo -t 60 -q:a 9 -acodec libmp3lame "$path"');
        _addAudioOverlay(path, title);
      },
    );
  }

  // --- EXPORT VIDEO GATHERING CHANNELS COMPLEX GRAPH ---

  Future<void> _exportVideo(bool saveToDownloads) async {
    final selectedDuration = _currentState.endCut - _currentState.startCut;
    if (selectedDuration > 60.1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Video uzunligi 60 soniyadan oshmasligi kerak!'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() {
      _isExporting = true;
      _isPlaying = false;
    });
    _videoPlayerController?.pause();
    for (var player in _audioPlayers) {
      player.pause();
    }

    try {
      final tempDir = await getTemporaryDirectory();
      
      // Guaranteed secure temporary path for FFmpeg execution
      final tempOutputPath = p.join(tempDir.path, 'temp_export_${DateTime.now().millisecondsSinceEpoch}.mp4');
      
      // Determine the final destination path if saveToDownloads is true
      String publicOutputPath = '';
      if (saveToDownloads) {
        final downloadDir = Directory('/storage/emulated/0/Download/VideoFixer/edited');
        publicOutputPath = p.join(downloadDir.path, 'videofixer_${DateTime.now().millisecondsSinceEpoch}.mp4');
      }

      final startStr = _formatDurationForFFmpeg(_currentState.startCut);

      // FFmpeg compound filter
      List<String> videoFilters = [];
      videoFilters.add("scale=w=1080:h=1920:force_original_aspect_ratio=decrease,pad=1080:1920:(1080-iw)/2:(1920-ih)/2:black");

      // Burn Texts with customized modern Google Fonts
      for (var textItem in _currentState.texts) {
        final double xPercent = textItem.position.dx;
        final double yPercent = textItem.position.dy;
        final double size = textItem.fontSize * 1.6;
        final hexColor = '0x${textItem.textColor.toARGB32().toRadixString(16).substring(2)}';
        final shadowColorHex = '0x${textItem.shadowColor.toARGB32().toRadixString(16).substring(2)}';

        // Select exact local system font fallback mapping
        const fontFile = '/system/fonts/Roboto-Bold.ttf';
        final escapedText = textItem.text.replaceAll("'", "'\\''");

        videoFilters.add(
          "drawtext=text='$escapedText':fontfile='$fontFile':fontsize=$size:fontcolor=$hexColor"
          "${textItem.hasBg ? ':box=1:boxcolor=0x${textItem.bgColor.toARGB32().toRadixString(16).substring(2)}@0.6:boxborderw=8' : ''}"
          "${textItem.hasShadow ? ':shadowcolor=$shadowColorHex:shadowx=3:shadowy=3' : ''}"
          ":x=w*$xPercent-text_w/2:y=h*$yPercent-text_h/2:enable='between(t,${textItem.startTime - _currentState.startCut},${textItem.startTime + textItem.duration - _currentState.startCut})'"
        );
      }

      // Emojis/Stickers burn
      for (var sticker in _currentState.stickers) {
        final double xPercent = sticker.position.dx;
        final double yPercent = sticker.position.dy;
        final double size = 70 * sticker.scale;
        
        const fontFile = '/system/fonts/NotoColorEmoji.ttf';
        final escapedEmoji = sticker.emoji.replaceAll("'", "'\\''");

        videoFilters.add(
          "drawtext=text='$escapedEmoji':fontfile='$fontFile':fontsize=$size"
          ":x=w*$xPercent-text_w/2:y=h*$yPercent-text_h/2:enable='between(t,${sticker.startTime - _currentState.startCut},${sticker.startTime + sticker.duration - _currentState.startCut})'"
        );
      }

      if (_currentState.speed != 1.0) {
        final ptsSpeed = 1.0 / _currentState.speed;
        videoFilters.add("setpts=$ptsSpeed*PTS");
      }

      String filterString = videoFilters.join(",");

      // Compile final command
      String command = '-y -ss $startStr -i "${widget.filePath}" ';
      
      for (var audio in _currentState.audios) {
        command += '-i "${audio.path}" ';
      }

      String filterComplex = '';
      if (filterString.isNotEmpty) {
        filterComplex += '[0:v]$filterString[outv]; ';
      } else {
        filterComplex += '[0:v]copy[outv]; ';
      }

      // Original video stream volume
      filterComplex += '[0:a]volume=${_currentState.originalVolume}[a0]; ';

      int audioIdx = 1;
      List<String> mixedLabels = ['[a0]'];
      for (var audio in _currentState.audios) {
        String label = 'a$audioIdx';
        String inputLabel = '[$audioIdx:a]';
        
        String filterPart = '';
        if (audio.isVocalRemoved) {
          filterPart += 'pan=stereo|c0=c0-c1|c1=c1-c0,equalizer=f=200:t=q:w=1:g=-20,';
        }
        
        final delayMs = (audio.startTime * 1000).toInt();
        filterPart += 'atrim=start=${audio.trimStart}:end=${audio.trimStart + audio.duration},';
        if (audio.fadeIn > 0) {
          filterPart += 'afade=t=in:ss=0:d=${audio.fadeIn},';
        }
        if (audio.fadeOut > 0) {
          filterPart += 'afade=t=out:st=${audio.duration - audio.fadeOut}:d=${audio.fadeOut},';
        }
        filterPart += 'volume=${audio.volume},';
        filterPart += 'adelay=$delayMs|$delayMs';
        
        filterComplex += '$inputLabel$filterPart[$label]; ';
        mixedLabels.add('[$label]');
        audioIdx++;
      }

      String mixInputs = mixedLabels.join('');
      filterComplex += '${mixInputs}amix=inputs=${mixedLabels.length}:duration=first[outa]';

      command += '-filter_complex "$filterComplex" -map "[outv]" -map "[outa]" ';
      
      if (_currentState.speed != 1.0) {
        command += '-filter:a "atempo=${_currentState.speed}" ';
      }

      command += '-c:v libx264 -preset superfast -c:a aac -ar 44100 -b:a 192k "$tempOutputPath"';

      final success = await FFmpegRunner.execute(command);

      if (success) {
        if (mounted) {
          setState(() {
            _isExporting = false;
          });

          String finalPath = tempOutputPath;

          if (saveToDownloads) {
            final downloadDir = Directory('/storage/emulated/0/Download/VideoFixer/edited');
            try {
              if (!downloadDir.existsSync()) {
                downloadDir.createSync(recursive: true);
              }
              
              final testFile = File(p.join(downloadDir.path, '.test_copy'));
              await testFile.writeAsString('test');
              await testFile.delete();

              finalPath = publicOutputPath;
              final finalFile = File(finalPath);
              if (await finalFile.exists()) {
                await finalFile.delete();
              }
              await File(tempOutputPath).copy(finalPath);
              await File(tempOutputPath).delete();
            } catch (e) {
              // Fallback to app's secure external directory
              final extDir = await getExternalStorageDirectory();
              final fallbackDir = Directory(p.join(extDir?.path ?? tempDir.path, 'VideoFixer/edited'));
              if (!fallbackDir.existsSync()) {
                fallbackDir.createSync(recursive: true);
              }
              finalPath = p.join(fallbackDir.path, p.basename(publicOutputPath));
              
              final finalFile = File(finalPath);
              if (await finalFile.exists()) {
                await finalFile.delete();
              }
              await File(tempOutputPath).copy(finalPath);
              await File(tempOutputPath).delete();
            }
          }

          if (saveToDownloads) {
            _showSuccess(finalPath);
          } else {
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UploadScreen(filePath: finalPath, isShorts: true),
              ),
            );
          }
        }
      } else {
        if (!mounted) return;
        setState(() {
          _isExporting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Eksportda xatolik yuz berdi ❌'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      secureLog('Export error: $e');
      setState(() {
        _isExporting = false;
      });
    }
  }

  void _showSuccess(String path) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Muvaffaqiyatli! ✅', style: TextStyle(color: Colors.white)),
        content: Text('Saqlandi:\n\n${p.basename(path)}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- LAYOUT RENDERING ---

  @override
  Widget build(BuildContext context) {
    final selectedDuration = _currentState.endCut - _currentState.startCut;
    final isDurationValid = selectedDuration <= 60.1;

    TimelineItem? selectedItem;
    final timelineItems = _getTimelineItems();
    for (var item in timelineItems) {
      if (item.isSelected && item.type != TimelineItemType.video) {
        selectedItem = item;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF0000)))
          : Stack(
              children: [
                Column(
                  children: [
                    // 1. 9:16 Video Preview with tap-to-play
                    Expanded(
                      flex: 5,
                      child: _buildVideoPreviewCanvas(),
                    ),

                    // 2. Compact Playback Row
                    _buildPlaybackRow(selectedDuration, isDurationValid),

                    // 3. Multi-layer Timeline
                    Expanded(
                      flex: 2,
                      child: _buildMultiLayerTimeline(selectedDuration, isDurationValid),
                    ),

                    // 4. CapCut-style animated tool panel
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      child: _toolPanelOpen ? _buildToolPanelContent() : const SizedBox.shrink(),
                    ),

                    // 5. Horizontal scrollable CapCut toolbar
                    _buildCapCutToolBar(),
                  ],
                ),

                if (selectedItem != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildItemBottomSheet(selectedItem),
                  ),

                if (_isExporting) _buildExportOverlay(),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final selectedDuration = _currentState.endCut - _currentState.startCut;
    return AppBar(
      backgroundColor: const Color(0xFF0C0C0C),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white70, size: 22),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Tahrirlash', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          Text(
            '${selectedDuration.toStringAsFixed(1)}s / ${_totalDuration.toStringAsFixed(1)}s',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(Icons.undo_rounded, color: _undoStack.isNotEmpty ? Colors.white70 : Colors.white24, size: 22),
          onPressed: _undoStack.isNotEmpty ? _undo : null,
          tooltip: 'Bekor qilish',
        ),
        IconButton(
          icon: Icon(Icons.redo_rounded, color: _redoStack.isNotEmpty ? Colors.white70 : Colors.white24, size: 22),
          onPressed: _redoStack.isNotEmpty ? _redo : null,
          tooltip: 'Qaytarish',
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF0000),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            onPressed: _showReadySheet,
            child: const Text('Tayyor', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  void _showReadySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Nima qilmoqchisiz?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2A2A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _exportVideo(true);
                  },
                  icon: const Icon(Icons.save_alt, color: Colors.white),
                  label: const Text('💾 Qurilmaga saqlash', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
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
                    _exportVideo(false);
                  },
                  icon: const Icon(Icons.cloud_upload, color: Colors.white),
                  label: const Text('🚀 YouTube ga yuklash', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoPreviewCanvas() {
    return GestureDetector(
      onTap: _togglePlayback,
      child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Actual native VideoPlayer
                  if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized)
                    Center(
                      child: AspectRatio(
                        aspectRatio: _videoPlayerController!.value.aspectRatio,
                        child: VideoPlayer(_videoPlayerController!),
                      ),
                    )
                  else
                    const Center(child: CircularProgressIndicator(color: Colors.red)),

                  // Golden Custom Interactive Crop/Trim UI Frame Overlay
                  _buildInteractiveCropOverlay(constraints),

                  // Play/Pause overlay button (fades out when playing)
                  if (!_isPlaying)
                    Center(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                      ),
                    ),

                  // DRAGGABLE, PINCH-ZOOMABLE, ROTATABLE TEXT overlays Stack
                  ..._currentState.texts.map((text) {
                    if (_currentTime < text.startTime || _currentTime > (text.startTime + text.duration)) {
                      return const SizedBox.shrink();
                    }

                    final isSelected = text.id == _selectedTextId;

                    return Positioned(
                      left: text.position.dx * constraints.maxWidth - 80,
                      top: text.position.dy * constraints.maxHeight - 20,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          _saveState();
                          setState(() {
                            double dx = (text.position.dx * constraints.maxWidth + details.delta.dx) / constraints.maxWidth;
                            double dy = (text.position.dy * constraints.maxHeight + details.delta.dy) / constraints.maxHeight;
                            text.position = Offset(dx.clamp(0.05, 0.95), dy.clamp(0.05, 0.95));
                          });
                        },
                        onScaleUpdate: (scaleDetails) {
                          setState(() {
                            text.scale = scaleDetails.scale.clamp(0.5, 3.0);
                            text.rotation = scaleDetails.rotation;
                          });
                        },
                        onTap: () {
                          setState(() {
                            _selectedTextId = text.id;
                            _selectedStickerId = null;
                            _selectedAudioId = null;
                            _activeTool = 'text';
                          });
                        },
                        child: Transform.rotate(
                          angle: text.rotation,
                          child: Transform.scale(
                            scale: text.scale,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: text.hasBg ? text.bgColor.withValues(alpha: 0.75) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: isSelected ? Border.all(color: Colors.redAccent, width: 2) : null,
                                boxShadow: text.hasShadow
                                    ? [BoxShadow(color: text.shadowColor, blurRadius: 4, offset: const Offset(2, 2))]
                                    : [],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    text.text,
                                    style: TextStyle(
                                      color: text.textColor,
                                      fontSize: text.fontSize,
                                      fontWeight: text.fontStyle == 'bold' ? FontWeight.bold : FontWeight.normal,
                                      fontStyle: text.fontStyle == 'italic' ? FontStyle.italic : FontStyle.normal,
                                      fontFamily: text.fontFamily,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () {
                                        _saveState();
                                        setState(() {
                                          _currentState.texts.removeWhere((t) => t.id == text.id);
                                          _selectedTextId = null;
                                        });
                                      },
                                      child: const Icon(Icons.cancel, color: Colors.red, size: 18),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  // STICKERS stack overlays
                  ..._currentState.stickers.map((sticker) {
                    if (_currentTime < sticker.startTime || _currentTime > (sticker.startTime + sticker.duration)) {
                      return const SizedBox.shrink();
                    }

                    final isSelected = sticker.id == _selectedStickerId;

                    return Positioned(
                      left: sticker.position.dx * constraints.maxWidth - 30,
                      top: sticker.position.dy * constraints.maxHeight - 30,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          _saveState();
                          setState(() {
                            double dx = (sticker.position.dx * constraints.maxWidth + details.delta.dx) / constraints.maxWidth;
                            double dy = (sticker.position.dy * constraints.maxHeight + details.delta.dy) / constraints.maxHeight;
                            sticker.position = Offset(dx.clamp(0.05, 0.95), dy.clamp(0.05, 0.95));
                          });
                        },
                        onScaleUpdate: (scaleDetails) {
                          setState(() {
                            sticker.scale = scaleDetails.scale.clamp(0.5, 3.0);
                            sticker.rotation = scaleDetails.rotation;
                          });
                        },
                        onTap: () {
                          setState(() {
                            _selectedStickerId = sticker.id;
                            _selectedTextId = null;
                            _selectedAudioId = null;
                            _activeTool = 'sticker';
                          });
                        },
                        child: Transform.rotate(
                          angle: sticker.rotation,
                          child: Transform.scale(
                            scale: sticker.scale,
                            child: Container(
                              decoration: BoxDecoration(
                                border: isSelected ? Border.all(color: Colors.redAccent, width: 2) : null,
                                shape: BoxShape.circle,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(sticker.emoji, style: const TextStyle(fontSize: 42)),
                                  if (isSelected) ...[
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () {
                                        _saveState();
                                        setState(() {
                                          _currentState.stickers.removeWhere((s) => s.id == sticker.id);
                                          _selectedStickerId = null;
                                        });
                                      },
                                      child: const Icon(Icons.cancel, color: Colors.red, size: 18),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ),
      ), // GestureDetector
    );
  }

  Widget _buildPlaybackRow(double selectedDuration, bool isDurationValid) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFF0C0C0C),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlayback,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF222222)),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatTime(_currentTime).substring(0, 5),
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
          const Text(' / ', style: TextStyle(color: Colors.white24, fontSize: 11)),
          Text(
            _formatTime(_totalDuration).substring(0, 5),
            style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace'),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDurationValid ? Colors.white.withValues(alpha: 0.04) : Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDurationValid ? Colors.white12 : Colors.redAccent),
            ),
            child: Text(
              isDurationValid ? '${selectedDuration.toStringAsFixed(1)}s ✓' : '${selectedDuration.toStringAsFixed(1)}s ⚠️',
              style: TextStyle(
                color: isDurationValid ? Colors.white70 : Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- MULTI-LAYER TIMELINE COMPONENT ---

  List<TimelineItem> _getTimelineItems() {
    final List<TimelineItem> items = [];
    
    // 1. Video Item (the active cut range)
    items.add(TimelineItem(
      id: 'video_track',
      type: TimelineItemType.video,
      startSeconds: _currentState.startCut,
      durationSeconds: _currentState.endCut - _currentState.startCut,
      color: Colors.grey,
      label: '🎬 Video (${_currentState.speed}x)',
      isSelected: _selectedTextId == null && _selectedStickerId == null && _selectedAudioId == null && _activeTool == 'cut',
    ));

    // 2. Audio Items
    for (var audio in _currentState.audios) {
      items.add(TimelineItem(
        id: audio.id,
        type: TimelineItemType.audio,
        startSeconds: audio.startTime,
        durationSeconds: audio.duration,
        color: Colors.green,
        label: '🎵 ${audio.title}',
        isSelected: audio.id == _selectedAudioId,
      ));
    }

    // 3. Text Items
    for (var text in _currentState.texts) {
      items.add(TimelineItem(
        id: text.id,
        type: TimelineItemType.text,
        startSeconds: text.startTime,
        durationSeconds: text.duration,
        color: Colors.blue,
        label: '📝 ${text.text}',
        isSelected: text.id == _selectedTextId,
      ));
    }

    // 4. Sticker Items
    for (var sticker in _currentState.stickers) {
      items.add(TimelineItem(
        id: sticker.id,
        type: TimelineItemType.sticker,
        startSeconds: sticker.startTime,
        durationSeconds: sticker.duration,
        color: Colors.orange,
        label: '🎭 ${sticker.emoji}',
        isSelected: sticker.id == _selectedStickerId,
      ));
    }

    return items;
  }

  void _updateItemSeconds(String id, TimelineItemType type, double newStart, double newDuration) {
    _saveState();
    setState(() {
      if (type == TimelineItemType.video) {
        double start = newStart.clamp(0.0, _totalDuration);
        double end = (newStart + newDuration).clamp(start + 1.0, _totalDuration);
        _currentState = _currentState.copyWith(
          startCut: start,
          endCut: end,
        );
        _currentTime = start;
      } else if (type == TimelineItemType.audio) {
        final audio = _currentState.audios.firstWhere((a) => a.id == id);
        audio.startTime = newStart.clamp(0.0, _totalDuration);
        audio.duration = newDuration.clamp(1.0, _totalDuration - audio.startTime);
        _syncAudioClips();
      } else if (type == TimelineItemType.text) {
        final text = _currentState.texts.firstWhere((t) => t.id == id);
        text.startTime = newStart.clamp(0.0, _totalDuration);
        text.duration = newDuration.clamp(1.0, _totalDuration - text.startTime);
      } else if (type == TimelineItemType.sticker) {
        final sticker = _currentState.stickers.firstWhere((s) => s.id == id);
        sticker.startTime = newStart.clamp(0.0, _totalDuration);
        sticker.duration = newDuration.clamp(1.0, _totalDuration - sticker.startTime);
      }
    });
  }

  void _selectItem(TimelineItem item) {
    setState(() {
      if (item.type == TimelineItemType.video) {
        _selectedTextId = null;
        _selectedStickerId = null;
        _selectedAudioId = null;
        _activeTool = 'cut';
      } else if (item.type == TimelineItemType.audio) {
        _selectedAudioId = item.id;
        _selectedTextId = null;
        _selectedStickerId = null;
        _activeTool = 'audio';
      } else if (item.type == TimelineItemType.text) {
        _selectedTextId = item.id;
        _selectedAudioId = null;
        _selectedStickerId = null;
        _activeTool = 'text';
      } else if (item.type == TimelineItemType.sticker) {
        _selectedStickerId = item.id;
        _selectedTextId = null;
        _selectedAudioId = null;
        _activeTool = 'sticker';
      }
    });
  }

  Widget _buildItemBottomSheet(TimelineItem selectedItem) {
    if (selectedItem.type == TimelineItemType.text) {
      final text = _currentState.texts.firstWhere((t) => t.id == selectedItem.id);
      return TextEditPanel(
        text: text,
        onDelete: () {
          _saveState();
          setState(() {
            _currentState.texts.removeWhere((t) => t.id == text.id);
            _selectedTextId = null;
          });
        },
        onChanged: (val) {
          setState(() {
            text.text = val;
          });
        },
        onFontChanged: (font) {
          _saveState();
          setState(() {
            text.fontFamily = font;
          });
        },
        onColorChanged: (color) {
          setState(() {
            text.textColor = color;
          });
        },
        fonts: _fonts,
      );
    } else if (selectedItem.type == TimelineItemType.audio) {
      final audio = _currentState.audios.firstWhere((a) => a.id == selectedItem.id);
      return AudioEditPanel(
        audio: audio,
        onDelete: () {
          _saveState();
          setState(() {
            _currentState.audios.removeWhere((a) => a.id == audio.id);
            _selectedAudioId = null;
            _syncAudioClips();
          });
        },
        onVolumeChanged: (val) {
          setState(() {
            audio.volume = val;
          });
        },
        onVocalToggle: (val) {
          _saveState();
          setState(() {
            audio.isVocalRemoved = val;
          });
        },
      );
    } else if (selectedItem.type == TimelineItemType.sticker) {
      final sticker = _currentState.stickers.firstWhere((s) => s.id == selectedItem.id);
      return StickerEditPanel(
        sticker: sticker,
        onDelete: () {
          _saveState();
          setState(() {
            _currentState.stickers.removeWhere((s) => s.id == sticker.id);
            _selectedStickerId = null;
          });
        },
        onScaleChanged: (val) {
          setState(() {
            sticker.scale = val;
          });
        },
        onRotationChanged: (val) {
          setState(() {
            sticker.rotation = val;
          });
        },
      );
    }
    return const SizedBox();
  }

  Widget _buildMultiLayerTimeline(double selectedDuration, bool isDurationValid) {
    final timelineItems = _getTimelineItems();
    final videoItem = timelineItems.firstWhere((i) => i.type == TimelineItemType.video);
    final audioItems = timelineItems.where((i) => i.type == TimelineItemType.audio).toList();
    final textItems = timelineItems.where((i) => i.type == TimelineItemType.text).toList();
    final stickerItems = timelineItems.where((i) => i.type == TimelineItemType.sticker).toList();

    return Container(
      color: const Color(0xFF0F0F0F),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Zoom Slider control
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.zoom_out, color: Colors.white30, size: 14),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.white30,
                      inactiveTrackColor: Colors.white10,
                      trackHeight: 2,
                      thumbColor: Colors.white,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    ),
                    child: ValueListenableBuilder<double>(
                      valueListenable: _pixelsPerSecondNotifier,
                      builder: (context, pixelsPerSecond, child) {
                        return Slider(
                          value: pixelsPerSecond,
                          min: 30.0,
                          max: 300.0,
                          onChanged: (v) {
                            _pixelsPerSecondNotifier.value = v;
                          },
                        );
                      },
                    ),
                  ),
                ),
                const Icon(Icons.zoom_in, color: Colors.white30, size: 14),
              ],
            ),
          ),

          // Stacked layers list wrapped in GestureDetector for pinch-to-zoom scaling
          Expanded(
            child: GestureDetector(
              onScaleUpdate: (details) {
                final double currentZoom = _pixelsPerSecondNotifier.value;
                final double newZoom = (currentZoom * details.scale).clamp(30.0, 300.0);
                _onZoomChanged(newZoom);
              },
              onTap: () {
                // Tap on background deselects items
                setState(() {
                  _selectedTextId = null;
                  _selectedAudioId = null;
                  _selectedStickerId = null;
                });
              },
              child: ValueListenableBuilder<double>(
                valueListenable: _pixelsPerSecondNotifier,
                builder: (context, pixelsPerSecond, child) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: math.max(MediaQuery.of(context).size.width, _totalDuration * pixelsPerSecond + 48),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                RepaintBoundary(
                                  child: TimelineRow(
                                    type: 'video',
                                    item: videoItem,
                                    videoPath: widget.filePath,
                                    pixelsPerSecond: pixelsPerSecond,
                                    maxDuration: _totalDuration,
                                    onSelect: _selectItem,
                                    onUpdate: (item, start, duration) {
                                      _updateItemSeconds(item.id, item.type, start, duration);
                                    },
                                  ),
                                ),
                                RepaintBoundary(
                                  child: TimelineRow(
                                    type: 'audio',
                                    items: audioItems,
                                    pixelsPerSecond: pixelsPerSecond,
                                    maxDuration: _totalDuration,
                                    onSelect: _selectItem,
                                    onUpdate: (item, start, duration) {
                                      _updateItemSeconds(item.id, item.type, start, duration);
                                    },
                                  ),
                                ),
                                RepaintBoundary(
                                  child: TimelineRow(
                                    type: 'text',
                                    items: textItems,
                                    pixelsPerSecond: pixelsPerSecond,
                                    maxDuration: _totalDuration,
                                    onSelect: _selectItem,
                                    onUpdate: (item, start, duration) {
                                      _updateItemSeconds(item.id, item.type, start, duration);
                                    },
                                  ),
                                ),
                                RepaintBoundary(
                                  child: TimelineRow(
                                    type: 'sticker',
                                    items: stickerItems,
                                    pixelsPerSecond: pixelsPerSecond,
                                    maxDuration: _totalDuration,
                                    onSelect: _selectItem,
                                    onUpdate: (item, start, duration) {
                                      _updateItemSeconds(item.id, item.type, start, duration);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Golden crop box selection track highlight
                          _buildRangeHighlightTrack(selectedDuration, isDurationValid, pixelsPerSecond),

                          // Playhead Line Pointer indicator
                          PlayheadWidget(
                            position: _currentTime * pixelsPerSecond,
                            height: 280.0,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeHighlightTrack(double selectedDuration, bool isDurationValid, double pixelsPerSecond) {
    final double startX = _currentState.startCut * pixelsPerSecond;
    final double endX = _currentState.endCut * pixelsPerSecond;
    final isOverLimit = selectedDuration > 60.1;
    final activeColor = isOverLimit ? Colors.red : const Color(0xFFFFD700);

    return Positioned(
      left: startX,
      width: math.max(20.0, endX - startX),
      top: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border.symmetric(
            horizontal: BorderSide(color: activeColor.withValues(alpha: 0.4), width: 2.0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onHorizontalDragUpdate: (details) {
                _saveState();
                final double shift = details.delta.dx / pixelsPerSecond;
                setState(() {
                  double newStart = (_currentState.startCut + shift).clamp(0.0, _currentState.endCut - 1.0);
                  _currentState = _currentState.copyWith(startCut: newStart);
                  _currentTime = newStart;
                });
              },
              child: Container(
                width: 12,
                color: activeColor,
                child: const Center(child: Icon(Icons.drag_indicator, size: 8, color: Colors.black)),
              ),
            ),
            GestureDetector(
              onHorizontalDragUpdate: (details) {
                _saveState();
                final double shift = details.delta.dx / pixelsPerSecond;
                setState(() {
                  double newEnd = (_currentState.endCut + shift).clamp(_currentState.startCut + 1.0, _totalDuration);
                  _currentState = _currentState.copyWith(endCut: newEnd);
                  _currentTime = newEnd;
                });
              },
              child: Container(
                width: 12,
                color: activeColor,
                child: const Center(child: Icon(Icons.drag_indicator, size: 8, color: Colors.black)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CAPCUT-STYLE TOOLBAR AND TOOL PANELS ---

  Widget _buildCapCutToolBar() {
    const tools = [
      ('cut',     Icons.content_cut_rounded,  'Kesish'),
      ('text',    Icons.text_fields_rounded,  'Matn'),
      ('sticker', Icons.emoji_emotions_rounded,'Stiker'),
      ('audio',   Icons.music_note_rounded,   'Musiqa'),
      ('speed',   Icons.speed_rounded,        'Tezlik'),
      ('volume',  Icons.volume_up_rounded,    'Ovoz'),
    ];

    return Container(
      height: 72,
      color: const Color(0xFF111111),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: tools.length,
        itemBuilder: (context, i) {
          final (id, icon, label) = tools[i];
          final isActive = _activeTool == id && _toolPanelOpen;
          return GestureDetector(
            onTap: () {
              setState(() {
                if (_activeTool == id && _toolPanelOpen) {
                  _toolPanelOpen = false;
                } else {
                  _activeTool = id;
                  _toolPanelOpen = true;
                }
              });
            },
            child: Container(
              width: 64,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFFF0000).withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isActive ? Border.all(color: const Color(0xFFFF0000).withValues(alpha: 0.5), width: 1) : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: isActive ? const Color(0xFFFF0000) : Colors.white60, size: 22),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: isActive ? const Color(0xFFFF0000) : Colors.white38,
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolPanelContent() {
    return Container(
      constraints: const BoxConstraints(minHeight: 0, maxHeight: 200),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: _buildSelectedToolDrawer(),
    );
  }

  Widget _buildSelectedToolDrawer() {
    switch (_activeTool) {
      case 'text':
        return _buildTextSubDrawer();
      case 'sticker':
        return _buildStickerSubDrawer();
      case 'audio':
        return _buildAudioSubDrawer();
      case 'speed':
        return _buildSpeedSubDrawer();
      case 'volume':
        return _buildVolumeSubDrawer();
      case 'cut':
      default:
        return _buildCutSubDrawer();
    }
  }

  Widget _buildCutSubDrawer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Start / End time display
        Row(
          children: [
            Expanded(child: _buildTimeChip('Boshlanish', _currentState.startCut, (v) {
              _saveState();
              setState(() {
                _currentState = _currentState.copyWith(startCut: v.clamp(0.0, _currentState.endCut - 1.0));
                _currentTime = _currentState.startCut;
              });
            })),
            const SizedBox(width: 8),
            Expanded(child: _buildTimeChip('Tugash', _currentState.endCut, (v) {
              _saveState();
              setState(() {
                _currentState = _currentState.copyWith(endCut: v.clamp(_currentState.startCut + 1.0, _totalDuration));
                _currentTime = _currentState.endCut;
              });
            })),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildActionChip(Icons.content_cut_rounded, 'Split', const Color(0xFF2A2A2A), () {
              _saveState();
              setState(() {
                _currentState = _currentState.copyWith(endCut: _currentTime);
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bo\'lindi ✂️'), duration: Duration(seconds: 1)));
            }),
            const SizedBox(width: 8),
            _buildActionChip(Icons.restart_alt_rounded, 'Reset', const Color(0xFF2A2A2A), () {
              _saveState();
              setState(() {
                _currentState = _currentState.copyWith(startCut: 0.0, endCut: _totalDuration, speed: 1.0, originalVolume: 1.0);
                _currentTime = 0.0;
              });
            }),
            const SizedBox(width: 8),
            _buildActionChip(Icons.play_circle_outline_rounded, 'Joylashuvga o\'t', const Color(0xFF2A2A2A), () {
              _videoPlayerController?.seekTo(Duration(milliseconds: (_currentState.startCut * 1000).toInt()));
              setState(() { _currentTime = _currentState.startCut; });
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildSpeedSubDrawer() {
    const speeds = [0.3, 0.5, 1.0, 1.5, 2.0, 3.0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Tezlik', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: speeds.map((s) {
            final isSelected = (_currentState.speed - s).abs() < 0.01;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  _saveState();
                  setState(() { _currentState = _currentState.copyWith(speed: s); });
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFF0000) : const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    s == s.truncateToDouble() ? '${s.toInt()}x' : '${s}x',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVolumeSubDrawer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Original Ovoz', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
            Text('${(_currentState.originalVolume * 100).toInt()}%',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.volume_off_rounded, color: Colors.white24, size: 18),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFFFF0000),
                  inactiveTrackColor: Colors.white12,
                  trackHeight: 3,
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: _currentState.originalVolume,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) {
                    setState(() {
                      _currentState = _currentState.copyWith(originalVolume: val);
                    });
                    _videoPlayerController?.setVolume(val);
                  },
                ),
              ),
            ),
            const Icon(Icons.volume_up_rounded, color: Colors.white54, size: 18),
          ],
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            final isMuted = _currentState.originalVolume < 0.01;
            setState(() {
              _currentState = _currentState.copyWith(originalVolume: isMuted ? 1.0 : 0.0);
            });
            _videoPlayerController?.setVolume(isMuted ? 1.0 : 0.0);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              _currentState.originalVolume < 0.01 ? 'Ovozni yoqish' : 'Ovozni o\'chirish',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeChip(String label, double value, Function(double) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          Text(_formatTime(value).substring(0, 5),
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => onChanged(value - 0.5),
                child: const Icon(Icons.remove_rounded, color: Colors.white38, size: 18),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => onChanged(value + 0.5),
                child: const Icon(Icons.add_rounded, color: Colors.white38, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(IconData icon, String label, Color bg, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }


  // --- TEXT STYLE PANE ---

  Widget _buildTextSubDrawer() {
    final hasSelection = _selectedTextId != null;
    final selectedText = hasSelection ? _currentState.texts.firstWhere((t) => t.id == _selectedTextId) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: _addTextOverlay,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFFF0000), borderRadius: BorderRadius.circular(20)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('Matn', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (hasSelection && selectedText != null)
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(20)),
                  child: TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'Matnni yozing...', hintStyle: TextStyle(color: Colors.white24, fontSize: 12)),
                    controller: TextEditingController(text: selectedText.text)
                      ..selection = TextSelection.fromPosition(TextPosition(offset: selectedText.text.length)),
                    onChanged: (val) => setState(() { selectedText.text = val; }),
                  ),
                ),
              ),
          ],
        ),
        if (hasSelection && selectedText != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Color dots
                ..._pickerColors.take(12).map((color) {
                  final isColorSelected = selectedText.textColor == color;
                  return GestureDetector(
                    onTap: () { _saveState(); setState(() { selectedText.textColor = color; }); },
                    child: Container(
                      width: 28, height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isColorSelected ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.white12),
                      ),
                    ),
                  );
                }),
                // Font chips
                const VerticalDivider(color: Colors.white12, width: 20),
                ..._fonts.take(5).map((font) {
                  final isFontSelected = selectedText.fontFamily == font;
                  return GestureDetector(
                    onTap: () { _saveState(); setState(() { selectedText.fontFamily = font; }); },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isFontSelected ? const Color(0xFFFF0000) : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(font, style: TextStyle(color: Colors.white, fontSize: 10, fontFamily: isFontSelected ? font : null)),
                    ),
                  );
                }),
                // Bg/Shadow toggles
                const VerticalDivider(color: Colors.white12, width: 20),
                _buildToggleChip('Fon', selectedText.hasBg, (v) { _saveState(); setState(() { selectedText.hasBg = v; }); }),
                const SizedBox(width: 6),
                _buildToggleChip('Soya', selectedText.hasShadow, (v) { _saveState(); setState(() { selectedText.hasShadow = v; }); }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildToggleChip(String label, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: value ? Colors.white.withValues(alpha: 0.15) : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: value ? Colors.white38 : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(color: value ? Colors.white : Colors.white38, fontSize: 10)),
      ),
    );
  }

  Widget _buildStickerSubDrawer() {
    const emojis = [
      '🔥', '😂', '❤️', '👍', '🎉', '🚀', '✨', '⚡', '💯', '😎',
      '🌟', '💪', '🔔', '📌', '⭐', '✔️', '❌', '👀', '💡', '👑', '🎯', '💎',
    ];

    return SizedBox(
      height: 120,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, mainAxisSpacing: 6, crossAxisSpacing: 6),
        itemCount: emojis.length,
        itemBuilder: (context, index) => GestureDetector(
          onTap: () => _addStickerOverlay(emojis[index]),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(8)),
            child: Text(emojis[index], style: const TextStyle(fontSize: 22)),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioSubDrawer() {
    final hasAudioSelected = _selectedAudioId != null;
    final selectedAudio = hasAudioSelected ? _currentState.audios.firstWhere((a) => a.id == _selectedAudioId) : null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF0000), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: _showAddMusicDrawer,
                icon: const Icon(Icons.add, color: Colors.white, size: 16),
                label: const Text('Musiqa qo\'shish', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              if (hasAudioSelected && selectedAudio != null) ...[
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () {
                    _saveState();
                    setState(() {
                      _currentState.audios.removeWhere((a) => a.id == selectedAudio.id);
                      _selectedAudioId = null;
                    });
                  },
                  tooltip: 'O\'chirish',
                ),
                FilterChip(
                  backgroundColor: Colors.black38,
                  selectedColor: Colors.green,
                  label: Text(
                    selectedAudio.isVocalRemoved ? 'Vokal o\'chirildi 🎙️' : 'Vokal o\'chirish',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  selected: selectedAudio.isVocalRemoved,
                  onSelected: (selected) {
                    _saveState();
                    setState(() {
                      selectedAudio.isVocalRemoved = selected;
                    });
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (hasAudioSelected && selectedAudio != null) ...[
            _buildSliderRow('Hajmi', selectedAudio.volume, 0.0, 2.0, (val) {
              setState(() {
                selectedAudio.volume = val;
              });
            }, percentage: true),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _buildSliderRow('Fade In', selectedAudio.fadeIn, 0.0, 3.0, (val) {
                    setState(() {
                      selectedAudio.fadeIn = val;
                    });
                  }, suffix: 's'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSliderRow('Fade Out', selectedAudio.fadeOut, 0.0, 3.0, (val) {
                    setState(() {
                      selectedAudio.fadeOut = val;
                    });
                  }, suffix: 's'),
                ),
              ],
            ),
          ] else ...[
            _buildSliderRow('Original', _currentState.originalVolume, 0.0, 1.0, (val) {
              setState(() {
                _currentState = _currentState.copyWith(originalVolume: val);
              });
              _videoPlayerController?.setVolume(val);
            }, percentage: true),
          ],
        ],
      ),
    );
  }

  Widget _buildSliderRow(String label, double value, double min, double max, Function(double) onChanged, {bool percentage = false, String suffix = '', Color trackColor = Colors.white54}) {
    String valStr = percentage ? '${(value * 100).toInt()}%' : '${value.toStringAsFixed(1)}$suffix';
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11))),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: trackColor,
              inactiveTrackColor: Colors.white10,
              trackHeight: 3,
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 36, child: Text(valStr, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _buildExportOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Card(
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 36, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFFFF0000)),
                SizedBox(height: 20),
                Text('Video eksport qilinmoqda...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 6),
                Text('Musiqalar, matn va stickerlar yondirilmoqda...', style: TextStyle(color: Colors.white54, fontSize: 11)),
                SizedBox(height: 2),
                Text('Iltimos, kuting...', style: TextStyle(color: Colors.white30, fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(double totalSeconds) {
    final int minutes = (totalSeconds / 60).floor();
    final int seconds = (totalSeconds % 60).floor();
    final int milliseconds = ((totalSeconds - totalSeconds.floor()) * 100).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(2, '0')}';
  }

  String _formatDurationForFFmpeg(double totalSeconds) {
    final int hours = (totalSeconds / 3600).floor();
    final int minutes = ((totalSeconds % 3600) / 60).floor();
    final double seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toStringAsFixed(3).padLeft(6, '0')}';
  }

  // --- INTERACTIVE DRAG-AND-DROP CROP OVERLAY ---

  Widget _buildInteractiveCropOverlay(BoxConstraints constraints) {
    if (_activeTool != 'cut') {
      return const SizedBox.shrink();
    }

    final double width = constraints.maxWidth;
    final double height = constraints.maxHeight;

    final double rectLeft = _cropLeft * width;
    final double rectTop = _cropTop * height;
    final double rectWidth = _cropWidth * width;
    final double rectHeight = _cropHeight * height;

    return Stack(
      children: [
        // Custom Painter to draw dim overlay outside the crop rect
        Positioned.fill(
          child: CustomPaint(
            painter: CropOverlayPainter(
              left: rectLeft,
              top: rectTop,
              width: rectWidth,
              height: rectHeight,
            ),
          ),
        ),

        // The draggable crop rect boundary
        Positioned(
          left: rectLeft,
          top: rectTop,
          width: rectWidth,
          height: rectHeight,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _cropLeft = (_cropLeft + details.delta.dx / width).clamp(0.0, 1.0 - _cropWidth);
                _cropTop = (_cropTop + details.delta.dy / height).clamp(0.0, 1.0 - _cropHeight);
              });
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
              ),
              child: Stack(
                children: [
                  // Grid lines inside the crop box (3x3 grid)
                  Column(
                    children: [
                      Expanded(child: Container(decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white24, width: 0.5))))),
                      Expanded(child: Container(decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white24, width: 0.5))))),
                      Expanded(child: Container()),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: Container(decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.white24, width: 0.5))))),
                      Expanded(child: Container(decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.white24, width: 0.5))))),
                      Expanded(child: Container()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Corner Handles (Drag & drop handles to resize crop box)
        // Top-Left corner
        Positioned(
          left: rectLeft - 10,
          top: rectTop - 10,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                final double originalRight = _cropLeft + _cropWidth;
                final double originalBottom = _cropTop + _cropHeight;

                final double newLeft = (_cropLeft + details.delta.dx / width).clamp(0.0, originalRight - 0.1);
                final double newTop = (_cropTop + details.delta.dy / height).clamp(0.0, originalBottom - 0.1);

                _cropLeft = newLeft;
                _cropWidth = originalRight - newLeft;
                _cropTop = newTop;
                _cropHeight = originalBottom - newTop;
              });
            },
            child: _buildCornerHandle(true, true),
          ),
        ),

        // Top-Right corner
        Positioned(
          left: rectLeft + rectWidth - 10,
          top: rectTop - 10,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                final double originalBottom = _cropTop + _cropHeight;

                final double newWidth = (_cropWidth + details.delta.dx / width).clamp(0.1, 1.0 - _cropLeft);
                final double newTop = (_cropTop + details.delta.dy / height).clamp(0.0, originalBottom - 0.1);

                _cropWidth = newWidth;
                _cropTop = newTop;
                _cropHeight = originalBottom - newTop;
              });
            },
            child: _buildCornerHandle(false, true),
          ),
        ),

        // Bottom-Left corner
        Positioned(
          left: rectLeft - 10,
          top: rectTop + rectHeight - 10,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                final double originalRight = _cropLeft + _cropWidth;

                final double newLeft = (_cropLeft + details.delta.dx / width).clamp(0.0, originalRight - 0.1);
                final double newHeight = (_cropHeight + details.delta.dy / height).clamp(0.1, 1.0 - _cropTop);

                _cropLeft = newLeft;
                _cropWidth = originalRight - newLeft;
                _cropHeight = newHeight;
              });
            },
            child: _buildCornerHandle(true, false),
          ),
        ),

        // Bottom-Right corner
        Positioned(
          left: rectLeft + rectWidth - 10,
          top: rectTop + rectHeight - 10,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                final double newWidth = (_cropWidth + details.delta.dx / width).clamp(0.1, 1.0 - _cropLeft);
                final double newHeight = (_cropHeight + details.delta.dy / height).clamp(0.1, 1.0 - _cropTop);

                _cropWidth = newWidth;
                _cropHeight = newHeight;
              });
            },
            child: _buildCornerHandle(false, false),
          ),
        ),
      ],
    );
  }

  Widget _buildCornerHandle(bool isLeft, bool isTop) {
    return Container(
      width: 20,
      height: 20,
      color: Colors.transparent,
      child: CustomPaint(
        painter: CornerHandlePainter(isLeft: isLeft, isTop: isTop),
      ),
    );
  }
}

class CropOverlayPainter extends CustomPainter {
  final double left;
  final double top;
  final double width;
  final double height;

  CropOverlayPainter({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    // Draw the dimmed background outside the crop box
    // Top box
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, top), paint);
    // Bottom box
    canvas.drawRect(Rect.fromLTRB(0, top + height, size.width, size.height), paint);
    // Left box
    canvas.drawRect(Rect.fromLTRB(0, top, left, top + height), paint);
    // Right box
    canvas.drawRect(Rect.fromLTRB(left + width, top, size.width, top + height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CornerHandlePainter extends CustomPainter {
  final bool isLeft;
  final bool isTop;

  CornerHandlePainter({required this.isLeft, required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD700) // Golden
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final double x = isLeft ? 10.0 : 10.0;
    final double y = isTop ? 10.0 : 10.0;

    final Path path = Path();
    if (isLeft && isTop) {
      path.moveTo(x + 10, y);
      path.lineTo(x, y);
      path.lineTo(x, y + 10);
    } else if (!isLeft && isTop) {
      path.moveTo(x - 10, y);
      path.lineTo(x, y);
      path.lineTo(x, y + 10);
    } else if (isLeft && !isTop) {
      path.moveTo(x + 10, y);
      path.lineTo(x, y);
      path.lineTo(x, y - 10);
    } else {
      path.moveTo(x - 10, y);
      path.lineTo(x, y);
      path.lineTo(x, y - 10);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
