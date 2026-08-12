import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import '../services/ffmpeg_runner.dart';
import 'package:path_provider/path_provider.dart';
import '../models/history_item.dart';
import '../models/youtube_account.dart';
import '../services/db_helper.dart';
import '../services/settings_provider.dart';
import '../services/youtube_uploader.dart';
import '../services/security_service.dart';
import 'package:confetti/confetti.dart';
import '../widgets/shake_widget.dart';
import '../widgets/scale_button.dart';
import '../utils/youtube_validator.dart';
import '../utils/location_data.dart';
import '../main.dart';

class UploadScreen extends StatefulWidget {
  final String filePath;
  final bool isShorts;

  const UploadScreen({
    super.key,
    required this.filePath,
    required this.isShorts,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with SingleTickerProviderStateMixin {
  YouTubeAccount? _selectedAccount;

  late TextEditingController _titleController;
  late HashtagHighlightController _descController;
  final TextEditingController _newTagController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  List<String> _tagsList = [];

  String _privacy = 'unlisted';
  String _categoryId = '22'; // Default: People & Blogs
  String _selectedLanguage = 'uz';
  bool _isMadeForKids = false;

  // Scheduling
  bool _isScheduled = false;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;

  bool _isUploading = false;
  bool _isSuccess = false;
  String? _errorMessage;
  String? _uploadedVideoUrl;

  int _bytesSent = 0;
  int _totalBytes = 1;
  DateTime? _uploadStartTime;
  String _timeRemaining = '--:--';
  double _uploadSpeedMbps = 0.0;
  String? _thumbnailPath;

  final Map<String, String> _categories = {
    '24': 'Entertainment (Ko\'ngilochar)',
    '27': 'Education (Ta\'lim)',
    '20': 'Gaming (O\'yinlar)',
    '10': 'Music (Musiqa)',
    '22': 'People & Blogs (Bloglar)',
    '1': 'Film & Animation',
    '28': 'Science & Tech',
  };

  final Map<String, String> _languages = {
    'uz': 'O\'zbekcha',
    'ru': 'Ruscha',
    'en': 'Inglizcha',
  };

  late String _uploadFilePath;
  late ConfettiController _confettiController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _shakeTitle = false;
  bool _shakeDesc = false;
  bool _shakeTags = false;
  List<String> _validationErrors = [];

  final GlobalKey _titleKey = GlobalKey();
  final GlobalKey _descKey = GlobalKey();
  final GlobalKey _tagsKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _pulseAnimation =
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);
    _uploadFilePath = widget.filePath;

    // Auto-append and pin #Shorts in title field only if isShorts is true
    final initialTitle = p.basenameWithoutExtension(widget.filePath);
    if (widget.isShorts) {
      _titleController = TextEditingController(
        text: initialTitle.toLowerCase().contains('#shorts')
            ? initialTitle
            : '${initialTitle.trimRight()} #Shorts',
      );
    } else {
      _titleController = TextEditingController(text: initialTitle);
    }
    _descController = HashtagHighlightController();

    _titleController.addListener(() {
      if (widget.isShorts) {
        final text = _titleController.text;
        if (!text.endsWith('#Shorts')) {
          String base = text;
          base = base
              .replaceAll(RegExp(r'#shorts', caseSensitive: false), '')
              .trim();
          final newText = base.isEmpty ? '#Shorts' : '$base #Shorts';

          final int cursorOffset = base.length;

          _titleController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.fromPosition(
              TextPosition(offset: cursorOffset.clamp(0, newText.length)),
            ),
          );
        }
      }
      if (mounted) setState(() {});
    });

    _descController.addListener(() {
      if (mounted) setState(() {});
    });

    _loadThumbnail();
  }

  bool _didInitDefaults = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final settings = Provider.of<SettingsProvider>(context);
    if (!settings.isLoading && !_didInitDefaults) {
      _didInitDefaults = true;
      _initDefaultChannelAndMetadata(settings);
    }
  }

  Future<void> _initDefaultChannelAndMetadata(SettingsProvider settings) async {
    final activeAccounts = settings.accounts.where((a) => a.isActive).toList();
    if (activeAccounts.isNotEmpty) {
      setState(() {
        _selectedAccount = activeAccounts.first;
      });
      await _loadChannelDefaults(_selectedAccount!);
    } else {
      await _promptChannelSelection(settings);
    }
  }

  Future<void> _promptChannelSelection(SettingsProvider settings) async {
    final allAccounts = settings.accounts;
    if (allAccounts.isEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('⚠️ Kanal aniqlanmadi',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            'Videoni yuklash uchun avval sozlamalar bo\'limidan YouTube kanalingizni ulashingiz kerak.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child:
                  const Text('Orqaga', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0000)),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
                MainTabScreen.onSwitchTab?.call(2);
              },
              child: const Text('Sozlamalar',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    final YouTubeAccount? chosen = await showModalBottomSheet<YouTubeAccount>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Kanalni tanlang',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...allAccounts.map((account) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: account.channelProfilePic != null
                          ? NetworkImage(account.channelProfilePic!)
                          : null,
                      child: account.channelProfilePic == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    title: Text(account.name,
                        style: const TextStyle(color: Colors.white)),
                    onTap: () => Navigator.pop(ctx, account),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (chosen != null) {
      setState(() {
        _selectedAccount = chosen;
      });
      await _loadChannelDefaults(chosen);
    } else {
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  Future<void> _loadThumbnail() async {
    try {
      final dbItems = await DBHelper.instance.getAllHistory();
      if (dbItems.isEmpty) return;
      final match = dbItems.firstWhere(
        (i) => i.filePath == widget.filePath,
        orElse: () => dbItems.last,
      );
      if (mounted) {
        setState(() {
          _thumbnailPath = match.thumbnailPath;
        });
      }
    } catch (e) {
      secureLog('Error loading thumbnail: $e');
    }
  }

  Future<void> _loadChannelDefaults(YouTubeAccount account) async {
    if (!mounted) return;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final metadata = await settings.loadDefaultUploadMetadata(
      filePath: widget.filePath,
      isShorts: widget.isShorts,
      channelId: account.channelId,
    );
    if (!mounted) return;

    setState(() {
      _titleController.text = metadata['title'] ?? '';
      _descController.text = metadata['description'] ?? '';
      _tagsList = List<String>.from(metadata['tags'] ?? []);
      _privacy = metadata['privacy'] ?? 'unlisted';
      _categoryId = metadata['category'] ?? '22';
      _isMadeForKids = metadata['audience'] == 'true';
      _selectedLanguage = metadata['language'] ?? 'uz';
      _locationController.text = metadata['location'] ?? '';
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _newTagController.dispose();
    _locationController.dispose();
    _confettiController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _addTag(String val) {
    final clean = val.trim();
    if (clean.isEmpty) return;

    final testList = List<String>.from(_tagsList)..add(clean);
    final combinedLength = testList.join(',').length;
    if (combinedLength > 500) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Teglar limiti oshib ketmoqda (Maksimal 500 belgi)! ❌'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    if (!_tagsList.contains(clean)) {
      setState(() {
        _tagsList.add(clean);
        _newTagController.clear();
      });
    }
  }

  Future<void> _startUpload() async {
    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Iltimos, kanalni tanlang!')));
      return;
    }

    // Deduplication of description
    final rawDescText = _descController.text;
    final cleanDescText =
        YouTubeInputValidator.deduplicateDescription(rawDescText);
    if (cleanDescText != rawDescText) {
      _descController.text = cleanDescText;
    }

    final titleText = _titleController.text;
    final descText = _descController.text;

    final titleVal = YouTubeInputValidator.validateTitle(titleText);
    final descVal = YouTubeInputValidator.validateDescription(descText);
    final tagsVal = YouTubeInputValidator.validateTags(_tagsList);

    final errors = <String>[];
    GlobalKey? firstInvalidKey;

    if (!titleVal['valid']) {
      errors.add('Sarlavha xatosi: ${titleVal['message']}');
      setState(() => _shakeTitle = true);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _shakeTitle = false);
      });
      firstInvalidKey ??= _titleKey;
    }

    if (!descVal['valid']) {
      errors.add('Tavsif xatosi: ${descVal['message']}');
      setState(() => _shakeDesc = true);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _shakeDesc = false);
      });
      firstInvalidKey ??= _descKey;
    }

    if (!tagsVal['valid']) {
      errors.add('Teglar xatosi: ${tagsVal['message']}');
      setState(() => _shakeTags = true);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _shakeTags = false);
      });
      firstInvalidKey ??= _tagsKey;
    }

    setState(() {
      _validationErrors = errors;
    });

    if (errors.isNotEmpty) {
      if (firstInvalidKey != null && firstInvalidKey.currentContext != null) {
        Scrollable.ensureVisible(
          firstInvalidKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
      return;
    }

    // Hashtag formatting warning adjustment:
    // If hashtag count exceeds 15, we shuffle all hashtags and take only 5 random ones!
    String finalDesc = descText;
    final RegExp hashReg = RegExp(r'#\S+');
    final matches =
        hashReg.allMatches(descText).map((m) => m.group(0)!).toList();
    if (matches.length > 15) {
      final List<String> shuffledMatches = List<String>.from(matches)
        ..shuffle();
      final Set<String> chosenTags = shuffledMatches.take(5).toSet();

      final Set<String> keptTags = {};
      finalDesc = descText.replaceAllMapped(hashReg, (m) {
        final tag = m.group(0)!;
        if (chosenTags.contains(tag) && !keptTags.contains(tag)) {
          keptTags.add(tag);
          return tag;
        }
        return ''; // remove it!
      });
      // Clean up extra spaces/newlines that might result from removal
      finalDesc = finalDesc.replaceAll(RegExp(r' +'), ' ');
      finalDesc = finalDesc.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    }

    _runUploadFlow(finalDesc);
  }

  Future<void> _runUploadFlow(String validatedDesc) async {
    DateTime? publishDateTime;
    if (_isScheduled) {
      if (_scheduledDate == null || _scheduledTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Iltimos, rejalashtirilgan sana va vaqtni tanlang!')));
        return;
      }
      publishDateTime = DateTime(
        _scheduledDate!.year,
        _scheduledDate!.month,
        _scheduledDate!.day,
        _scheduledTime!.hour,
        _scheduledTime!.minute,
      );
      if (publishDateTime.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Rejalashtirish vaqti o\'tib ketgan vaqt bo\'lmasligi kerak!')));
        return;
      }
    }

    if (widget.isShorts) {
      // Get video duration via FFprobe to verify the 60 seconds limit
      try {
        final mediaInfo = await FFprobeKit.getMediaInformation(_uploadFilePath);
        final info = mediaInfo.getMediaInformation();
        if (info != null) {
          final durationStr = info.getDuration();
          if (durationStr != null) {
            final durationSecs = double.tryParse(durationStr) ?? 0.0;
            if (durationSecs > 60.1) {
              // Show alert dialog and offer trimming
              if (!mounted) return;
              final trimConfirmed = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orangeAccent),
                      SizedBox(width: 8),
                      Text('Muddati juda uzun! ⚠️',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                  content: const Text(
                    'YouTube Shorts videolari 60 soniyadan oshmasligi kerak. Videoni avtomatik 60 soniyaga qisqartiraylikmi?\n(Qisqartirmasdan yuklash mumkin emas)',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Bekor qilish',
                          style: TextStyle(color: Colors.white54)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF0000)),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Qisqartirish',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );

              if (trimConfirmed == true) {
                // Show a loading dialog while trimming
                if (!mounted) return;
                showDialog(
                  context: context,
                  useRootNavigator: true,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: Card(
                      color: Color(0xFF1E1E1E),
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFFFF0000)),
                            SizedBox(height: 16),
                            Text('Video 60 soniyaga qisqartirilmoqda...',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                // Trim video using FFmpeg
                final tempDir = await getTemporaryDirectory();
                final trimmedPath = p.join(tempDir.path,
                    'trimmed_${DateTime.now().millisecondsSinceEpoch}.mp4');

                // Fast trim first (no re-encode), fallback to re-encode for compatibility.
                final trimCmd =
                    '-y -ss 0 -i "$_uploadFilePath" -t 60 -c copy -movflags +faststart "$trimmedPath"';
                bool success = await FFmpegRunner.execute(trimCmd);
                if (!success) {
                  final fallbackTrimCmd =
                      '-y -i "$_uploadFilePath" -t 60 -c:v libx264 -preset ultrafast -crf 26 -c:a aac -ar 44100 -ac 2 -b:a 128k -movflags +faststart "$trimmedPath"';
                  success = await FFmpegRunner.execute(fallbackTrimCmd);
                }

                if (!mounted) return;
                final rootNav = Navigator.of(context, rootNavigator: true);
                if (rootNav.canPop()) {
                  rootNav.pop(); // Dismiss loading dialog
                }

                if (success) {
                  _uploadFilePath = trimmedPath;
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Videoni qisqartirishda xatolik yuz berdi ❌'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
              } else {
                // User refused to trim
                return;
              }
            }
          }
        }
      } catch (e) {
        secureLog('Error checking duration: $e');
      }
    }

    if (widget.isShorts) {
      final ready = await _ensureShortsFormatForUpload();
      if (!ready) return;
    }

    setState(() {
      _isUploading = true;
      _isSuccess = false;
      _errorMessage = null;
      _bytesSent = 0;
      _totalBytes = File(_uploadFilePath).lengthSync();
      _uploadStartTime = DateTime.now();
    });

    try {
      final url = await YouTubeUploader.upload(
        account: _selectedAccount!,
        videoFile: File(_uploadFilePath),
        title: _titleController.text.trim(),
        description: validatedDesc.trim(),
        tags: _tagsList,
        privacyStatus: _privacy,
        categoryId: _categoryId,
        isMadeForKids: _isMadeForKids,
        language: _selectedLanguage,
        location: _locationController.text.trim(),
        publishAt: publishDateTime,
        videoType: 'short',
        onProgress: (sent, total) {
          if (!mounted) return;
          setState(() {
            _bytesSent = sent;
            _totalBytes = total;

            if (_uploadStartTime != null) {
              final elapsedSec =
                  DateTime.now().difference(_uploadStartTime!).inMilliseconds /
                      1000.0;
              if (elapsedSec > 0) {
                final bytesPerSec = sent / elapsedSec;
                _uploadSpeedMbps = (bytesPerSec * 8) / 1000000.0;

                if (bytesPerSec > 0) {
                  final remainingBytes = total - sent;
                  final remainingSec = remainingBytes / bytesPerSec;
                  final min = (remainingSec / 60).floor();
                  final sec = (remainingSec % 60).floor();
                  _timeRemaining =
                      '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
                }
              }
            }
          });
        },
      );

      // Save upload state to history
      final dbItems = await DBHelper.instance.getAllHistory();
      HistoryItem? currentItem;
      for (final item in dbItems) {
        if (item.filePath == widget.filePath) {
          currentItem = item;
          break;
        }
      }
      if (currentItem?.id != null) {
        await DBHelper.instance.updateHistory(currentItem!.copyWith(
          isUploaded: true,
          uploadedChannel: _selectedAccount!.name,
          youtubeLink: url,
          youtubeStatus: '⏳ Yuklanmoqda',
          lastSynced: DateTime.now().toIso8601String(),
        ));
      }

      if (mounted) {
        setState(() {
          _isUploading = false;
          _isSuccess = true;
          _uploadedVideoUrl = url;
        });
        _confettiController.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<bool> _ensureShortsFormatForUpload() async {
    final info = await FFmpegRunner.probeVideo(_uploadFilePath);
    if (info == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Video formatini tekshirib bo\'lmadi ❌'),
          backgroundColor: Colors.red,
        ));
      }
      return false;
    }

    final videoCompliant = FFmpegRunner.isShortsVideoCompliant(info);
    final audioCompliant = FFmpegRunner.isShortsAudioCompliant(info);
    if (videoCompliant && audioCompliant) {
      return true;
    }

    if (!mounted) return false;
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          color: Color(0xFF1E1E1E),
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFFFF0000)),
                SizedBox(height: 16),
                Text('Shorts formatiga moslashtirilmoqda...',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );

    bool success = false;
    try {
      final tempDir = await getTemporaryDirectory();
      final preparedPath = p.join(
        tempDir.path,
        'shorts_ready_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      final isVertical = info.width > 0 &&
          info.height > 0 &&
          (info.height / info.width - 16 / 9).abs() < 0.25;
      final targetBitrate = info.bitrate <= 0
          ? 6000000
          : (info.bitrate < 4000000
              ? 4000000
              : (info.bitrate > 8000000 ? 8000000 : info.bitrate.toInt()));

      String command;
      String? fallbackCommand;

      if (videoCompliant && !audioCompliant) {
        command =
            '-y -i "$_uploadFilePath" -c:v copy -c:a aac -ar 44100 -ac 2 -b:a 128k -movflags +faststart "$preparedPath"';
      } else if (isVertical) {
        const filter = 'scale=1080:1920:flags=fast_bilinear,fps=30,format=yuv420p';
        if (Platform.isAndroid) {
          command =
              '-y -i "$_uploadFilePath" -vf "$filter" -c:v h264_mediacodec -b:v $targetBitrate -maxrate $targetBitrate -pix_fmt yuv420p -c:a aac -ar 44100 -ac 2 -b:a 128k -movflags +faststart "$preparedPath"';
          fallbackCommand =
              '-y -i "$_uploadFilePath" -vf "$filter" -c:v libx264 -preset ultrafast -crf 26 -pix_fmt yuv420p -c:a aac -ar 44100 -ac 2 -b:a 128k -movflags +faststart "$preparedPath"';
        } else {
          command =
              '-y -i "$_uploadFilePath" -vf "$filter" -c:v libx264 -preset ultrafast -crf 26 -pix_fmt yuv420p -c:a aac -ar 44100 -ac 2 -b:a 128k -movflags +faststart "$preparedPath"';
        }
      } else {
        const blurFilter =
            '[0:v]scale=108:192:flags=fast_bilinear,gblur=sigma=2,scale=1080:1920:flags=fast_bilinear[bg];[0:v]scale=1080:-2:flags=fast_bilinear[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2,fps=30,format=yuv420p';
        if (Platform.isAndroid) {
          command =
              '-y -i "$_uploadFilePath" -filter_complex "$blurFilter" -c:v h264_mediacodec -b:v $targetBitrate -maxrate $targetBitrate -pix_fmt yuv420p -c:a aac -ar 44100 -ac 2 -b:a 128k -movflags +faststart "$preparedPath"';
          fallbackCommand =
              '-y -i "$_uploadFilePath" -filter_complex "$blurFilter" -c:v libx264 -preset ultrafast -crf 26 -pix_fmt yuv420p -c:a aac -ar 44100 -ac 2 -b:a 128k -movflags +faststart "$preparedPath"';
        } else {
          command =
              '-y -i "$_uploadFilePath" -filter_complex "$blurFilter" -c:v libx264 -preset ultrafast -crf 26 -pix_fmt yuv420p -c:a aac -ar 44100 -ac 2 -b:a 128k -movflags +faststart "$preparedPath"';
        }
      }

      success = await FFmpegRunner.execute(command);
      if (!success && fallbackCommand != null) {
        success = await FFmpegRunner.execute(fallbackCommand);
      }

      if (success) {
        _uploadFilePath = preparedPath;
      }
    } finally {
      if (mounted) {
        final rootNav = Navigator.of(context, rootNavigator: true);
        if (rootNav.canPop()) {
          rootNav.pop();
        }
      }
    }

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Shorts formatiga moslashtirishda xatolik ❌'),
        backgroundColor: Colors.red,
      ));
    }
    return success;
  }

  Widget _buildForm() {
    final settings = Provider.of<SettingsProvider>(context);
    final activeAccounts = settings.accounts.where((a) => a.isActive).toList();

    final titleText = _titleController.text;
    final titleVal = YouTubeInputValidator.validateTitle(titleText);

    final descText = _descController.text;
    final descVal = YouTubeInputValidator.validateDescription(descText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FFmpeg Video Thumbnail Card
        if (_thumbnailPath != null)
          Container(
            height: 180,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(
                image: FileImage(File(_thumbnailPath!)),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.all(16),
              alignment: Alignment.bottomLeft,
              child: Text(
                p.basename(widget.filePath),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

        // Channel Select Dropdown Card
        Card(
          color: const Color(0xFF1E1E1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Yuklovchi Kanal',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                DropdownButtonFormField<YouTubeAccount>(
                  dropdownColor: const Color(0xFF2A2A2A),
                  initialValue: _selectedAccount,
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFFF0000))),
                  ),
                  items: activeAccounts.map((a) {
                    return DropdownMenuItem(
                      value: a,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundImage: a.channelProfilePic != null
                                ? NetworkImage(a.channelProfilePic!)
                                : null,
                            child: a.channelProfilePic == null
                                ? const Icon(Icons.person,
                                    size: 16, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(a.name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedAccount = val);
                      _loadChannelDefaults(val);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 📝 Card 1: Asosiy Ma'lumotlar Card
        Card(
          color: const Color(0xFF1E1E1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('📝 Asosiy Ma\'lumotlar',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),

                // Title Field Container
                Container(
                  key: _titleKey,
                  child: ShakeWidget(
                    shake: _shakeTitle,
                    child: TextFormField(
                      controller: _titleController,
                      keyboardType: TextInputType.text,
                      autocorrect: false,
                      style: TextStyle(
                        color: !titleVal['valid']
                            ? Colors.redAccent
                            : (_shakeTitle ? Colors.redAccent : Colors.white),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Sarlavha (Title)',
                        labelStyle: TextStyle(
                          color: !titleVal['valid']
                              ? Colors.redAccent
                              : (titleVal['warning']
                                  ? Colors.amberAccent
                                  : Colors.white54),
                          fontSize: 13,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: !titleVal['valid']
                                ? Colors.redAccent
                                : (titleVal['warning']
                                    ? Colors.amberAccent
                                    : Colors.white24),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: !titleVal['valid']
                                ? Colors.redAccent
                                : (titleVal['warning']
                                    ? Colors.amberAccent
                                    : const Color(0xFFFF0000)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                YouTubeValidationFeedback(
                  validation: titleVal,
                  currentLength: titleText.length,
                  maxLength: 100,
                ),
                const SizedBox(height: 16),

                // Description Field Container
                Container(
                  key: _descKey,
                  child: ShakeWidget(
                    shake: _shakeDesc,
                    child: TextFormField(
                      controller: _descController,
                      maxLines: 4,
                      keyboardType: TextInputType.text,
                      autocorrect: false,
                      style: TextStyle(
                        color: !descVal['valid']
                            ? Colors.redAccent
                            : (_shakeDesc ? Colors.redAccent : Colors.white),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Tavsif (Description)',
                        labelStyle: TextStyle(
                          color: !descVal['valid']
                              ? Colors.redAccent
                              : (descVal['warning']
                                  ? Colors.amberAccent
                                  : Colors.white54),
                          fontSize: 13,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: !descVal['valid']
                                ? Colors.redAccent
                                : (descVal['warning']
                                    ? Colors.amberAccent
                                    : Colors.white24),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: !descVal['valid']
                                ? Colors.redAccent
                                : (descVal['warning']
                                    ? Colors.amberAccent
                                    : const Color(0xFFFF0000)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                YouTubeValidationFeedback(
                  validation: descVal,
                  currentLength: descText.length,
                  maxLength: 5000,
                ),
                const SizedBox(height: 16),

                // Tags Field Container with Shake and Key
                Container(
                  key: _tagsKey,
                  child: ShakeWidget(
                    shake: _shakeTags,
                    child: _buildTagsInput(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 🔒 Card 2: Ko'rinish Sozlamalari
        Card(
          color: const Color(0xFF1E1E1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('🔒 Ko\'rinish Sozlamalari',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Maxfiylik (Privacy Status):',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                        value: 'public', label: Text('Public')),
                    ButtonSegment<String>(
                        value: 'unlisted', label: Text('Unlisted')),
                    ButtonSegment<String>(
                        value: 'private', label: Text('Private')),
                  ],
                  selected: {_privacy},
                  onSelectionChanged: (selection) {
                    setState(() => _privacy = selection.first);
                  },
                ),
                const Divider(color: Colors.white12, height: 24),
                SwitchListTile(
                  title: const Text('Bolalar uchun (Made for Kids)',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: Text(
                      _isMadeForKids
                          ? 'Ha, bolalar uchun'
                          : 'Yo\'q, bolalar uchun emas',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12)),
                  value: _isMadeForKids,
                  activeThumbColor: const Color(0xFFFF0000),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _isMadeForKids = val),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 📍 Card 3: Qo'shimcha Sozlamalar
        Card(
          color: const Color(0xFF1E1E1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('📍 Qo\'shimcha Sozlamalar',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Toifa (Category)',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  dropdownColor: const Color(0xFF2A2A2A),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFFF0000))),
                  ),
                  items: _categories.entries.map((e) {
                    return DropdownMenuItem(value: e.key, child: Text(e.value));
                  }).toList(),
                  onChanged: (val) => setState(() => _categoryId = val!),
                ),
                const SizedBox(height: 16),
                const Text('Video Tili (Language)',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _selectedLanguage,
                  dropdownColor: const Color(0xFF2A2A2A),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFFF0000))),
                  ),
                  items: _languages.entries.map((e) {
                    return DropdownMenuItem(value: e.key, child: Text(e.value));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedLanguage = val!),
                ),
                const SizedBox(height: 16),
                const Text('Joylashuv (Location)',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final picked = await showLocationPicker(
                        context, _locationController.text);
                    if (picked != null) {
                      setState(() => _locationController.text = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            color: Colors.white54, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _locationController.text.isEmpty
                                ? 'Joylashuvni tanlang...'
                                : _locationController.text,
                            style: TextStyle(
                              color: _locationController.text.isEmpty
                                  ? Colors.white38
                                  : Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (_locationController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () =>
                                setState(() => _locationController.text = ''),
                            child: const Icon(Icons.close,
                                color: Colors.white38, size: 16),
                          )
                        else
                          const Icon(Icons.arrow_forward_ios,
                              color: Colors.white24, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 📅 Card 4: Rejalashtirish Card
        Card(
          color: const Color(0xFF1E1E1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('📅 Rejalashtirish',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Hozir yuklash')),
                        selected: !_isScheduled,
                        selectedColor: const Color(0xFFFF0000),
                        backgroundColor: const Color(0xFF2A2A2A),
                        labelStyle: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        onSelected: (val) =>
                            setState(() => _isScheduled = false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(
                            child: Text('Rejalashtirish (Schedule)')),
                        selected: _isScheduled,
                        selectedColor: const Color(0xFFFF0000),
                        backgroundColor: const Color(0xFF2A2A2A),
                        labelStyle: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        onSelected: (val) =>
                            setState(() => _isScheduled = true),
                      ),
                    ),
                  ],
                ),
                if (_isScheduled) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white30),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.calendar_today,
                              color: Colors.white70, size: 16),
                          label: Text(
                            _scheduledDate == null
                                ? 'Sana tanlash'
                                : '${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  DateTime.now().add(const Duration(days: 1)),
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => _scheduledDate = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white30),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.access_time,
                              color: Colors.white70, size: 16),
                          label: Text(
                            _scheduledTime == null
                                ? 'Vaqt tanlash'
                                : _scheduledTime!.format(context),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (picked != null) {
                              setState(() => _scheduledTime = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  )
                ]
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        if (_validationErrors.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.5), width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.redAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Quyidagilarni to\'g\'rilang:',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._validationErrors.map((err) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ',
                              style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              err,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],

        // Gradient Yuklash Button
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) => Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFFE50914), Color(0xFFFF0000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF0000)
                        .withValues(alpha: 0.3 + 0.3 * _pulseAnimation.value),
                    blurRadius: 10 + 10 * _pulseAnimation.value,
                    spreadRadius: 2 * _pulseAnimation.value,
                    offset: const Offset(0, 4),
                  )
                ]),
            child: child,
          ),
          child: ScaleButton(
            child: ElevatedButton.icon(
              onPressed: activeAccounts.isEmpty ? null : _startUpload,
              icon: const Icon(Icons.rocket_launch, color: Colors.white),
              label: const Text(
                'Yuklash 🚀',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                disabledBackgroundColor: Colors.grey.shade800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTagsInput() {
    final tagsVal = YouTubeInputValidator.validateTags(_tagsList);
    final combinedLength = _tagsList.join(',').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Teglar (Tags)',
            style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _tagsList.map((tag) {
            final prohibited = ['<', '>', '"', "'", '&', '#', '@'];
            final hasProhibited =
                tag.split('').any((char) => prohibited.contains(char));

            return Chip(
              label: Text(
                tag,
                style: TextStyle(
                  color: hasProhibited ? Colors.redAccent : Colors.white,
                  fontSize: 12,
                  decoration: hasProhibited ? TextDecoration.lineThrough : null,
                  decorationColor: Colors.redAccent,
                ),
              ),
              backgroundColor: hasProhibited
                  ? Colors.redAccent.withValues(alpha: 0.1)
                  : const Color(0xFF2A2A2A),
              side: hasProhibited
                  ? const BorderSide(color: Colors.redAccent, width: 1)
                  : BorderSide.none,
              deleteIcon: Icon(Icons.close,
                  size: 14,
                  color: hasProhibited ? Colors.redAccent : Colors.white70),
              onDeleted: () {
                setState(() {
                  _tagsList.remove(tag);
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _newTagController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.text,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'Yangi teg yozing...',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFFF0000))),
                ),
                onFieldSubmitted: (val) {
                  _addTag(val);
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFFFF0000)),
              onPressed: () {
                _addTag(_newTagController.text);
              },
            )
          ],
        ),
        YouTubeValidationFeedback(
          validation: tagsVal,
          currentLength: combinedLength,
          maxLength: 500,
        ),
      ],
    );
  }

  Widget _buildProgress() {
    final percent = (_bytesSent / _totalBytes).clamp(0.0, 1.0);
    final sentMB = (_bytesSent / (1024 * 1024)).toStringAsFixed(1);
    final totalMB = (_totalBytes / (1024 * 1024)).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: const Color(0xFFFF0000).withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_upload, size: 64, color: Color(0xFFFF0000)),
          const SizedBox(height: 16),
          const Text('Video yuklanmoqda...',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: percent),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, child) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 12,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
                borderRadius: BorderRadius.circular(6),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$sentMB MB / $totalMB MB',
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: percent * 100),
                duration: const Duration(milliseconds: 500),
                builder: (context, value, child) {
                  return Text('${value.toStringAsFixed(1)}%',
                      style: const TextStyle(
                          color: Color(0xFFFF0000),
                          fontSize: 16,
                          fontWeight: FontWeight.bold));
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tezlik: ${_uploadSpeedMbps.toStringAsFixed(1)} Mbps',
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
              Text('Qolgan vaqt: $_timeRemaining',
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
      ),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle,
                  size: 80, color: Colors.greenAccent),
              const SizedBox(height: 16),
              const Text('Muvaffaqiyatli yuklandi!',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _uploadedVideoUrl ?? '',
                        style: const TextStyle(
                            color: Colors.blueAccent, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white70),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: _uploadedVideoUrl!));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nusxa olindi!')));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ScaleButton(
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2A2A2A),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16))),
                    child: const Text('Ortga qaytish',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              )
            ],
          ),
          Positioned(
            top: -50,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ShakeWidget(
            shake: true,
            child:
                Icon(Icons.error_outline, size: 80, color: Colors.orangeAccent),
          ),
          const SizedBox(height: 16),
          const Text('Yuklashda xatolik yuz berdi',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(_errorMessage ?? 'Noma\'lum xatolik',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ScaleButton(
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _startUpload,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Qayta urinish',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF0000),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _errorMessage = null;
              _isUploading = false;
            }),
            child: const Text('Sozlamalarni o\'zgartirish',
                style: TextStyle(color: Colors.white54)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('YouTube\'ga yuklash',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        child: _isSuccess
            ? _buildSuccess()
            : _errorMessage != null
                ? _buildError()
                : _isUploading
                    ? _buildProgress()
                    : _buildForm(),
      ),
    );
  }
}
