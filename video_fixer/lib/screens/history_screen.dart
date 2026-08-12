import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_item.dart';
import '../services/db_helper.dart';
import '../services/youtube_uploader.dart';
import 'package:provider/provider.dart';
import '../services/settings_provider.dart';
import '../services/security_service.dart';
import 'upload_screen.dart';
import 'video_editor_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../widgets/shake_widget.dart';
import '../services/upload_queue_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with TickerProviderStateMixin {
  List<HistoryItem> _videos = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isOffline = false;

  // Filtering
  String _statusFilter = 'All';
  String _timeFilter = 'All';
  DateTimeRange? _customDateRange;
  List<String> _selectedChannels = [];
  String _sortFilter = 'Newest';

  // Pagination
  final ScrollController _scrollController = ScrollController();
  final int _pageSize = 20;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadMoreRunning = false;

  // View Mode: 'list', 'grid', 'compact'
  String _viewMode = 'list';

  // Multi-select
  bool _isMultiSelectMode = false;
  final Set<int> _selectedIds = {};
  late AnimationController _multiSelectAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadViewMode();
    _checkNetworkAndLoad();
    _multiSelectAnim = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _multiSelectAnim, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _multiSelectAnim.dispose();
    super.dispose();
  }

  void _enterMultiSelect(HistoryItem firstItem) {
    setState(() {
      _isMultiSelectMode = true;
      _selectedIds.clear();
      if (firstItem.id != null) _selectedIds.add(firstItem.id!);
    });
    _multiSelectAnim.forward();
  }

  void _exitMultiSelect() {
    _multiSelectAnim.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isMultiSelectMode = false;
          _selectedIds.clear();
        });
      }
    });
  }

  void _toggleSelect(HistoryItem item) {
    if (item.id == null) return;
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
        if (_selectedIds.isEmpty) _exitMultiSelect();
      } else {
        _selectedIds.add(item.id!);
      }
    });
  }

  void _selectAll() {
    setState(() {
      for (final v in _videos) {
        if (v.id != null) _selectedIds.add(v.id!);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('O\'chirishni tasdiqlash ⚠️',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('$count ta videoni o\'chirasizmi?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('Bekor', style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('O\'chirish',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirm != true) return;
    final toDelete = _videos
        .where((v) => v.id != null && _selectedIds.contains(v.id))
        .toList();
    for (final item in toDelete) {
      await _deleteVideo(item);
    }
    _exitMultiSelect();
  }

  Future<void> _shareSelected() async {
    final items = _videos
        .where((v) => v.id != null && _selectedIds.contains(v.id))
        .toList();
    final files = items.map((i) => XFile(i.filePath)).toList();
    // ignore: deprecated_member_use
    await Share.shareXFiles(files, text: '${files.length} ta video');
  }

  void _uploadSelected() async {
    final items = _videos
        .where(
            (v) => v.id != null && _selectedIds.contains(v.id) && !v.isUploaded)
        .toList();
    if (items.isEmpty) return;
    _exitMultiSelect();
    for (var item in items) {
      if (!mounted) break;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UploadScreen(
              filePath: item.filePath, isShorts: item.format == 'Shorts'),
        ),
      );
    }
    _loadHistory();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreHistory();
    }
  }

  Future<void> _loadViewMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = prefs.getString('history_view_mode');
      if (mode != null && mounted) {
        setState(() {
          _viewMode = mode;
        });
      }
    } catch (e) {
      secureLog('Error loading view mode from SharedPreferences: $e');
    }
  }

  Future<void> _saveViewMode(String mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('history_view_mode', mode);
      if (mounted) {
        setState(() {
          _viewMode = mode;
        });
      }
    } catch (e) {
      secureLog('Error saving view mode to SharedPreferences: $e');
    }
  }

  Future<void> _checkNetworkAndLoad() async {
    await _checkNetwork();
    await _loadHistory();
  }

  Future<void> _checkNetwork() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (mounted) {
        setState(() {
          _isOffline = results.isEmpty ||
              (results.length == 1 &&
                  results.first == ConnectivityResult.none);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isOffline = true);
    }
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      await DBHelper.instance.syncHistoryFromVideoFixerFolder();
      final items =
          await DBHelper.instance.getHistoryPaged(limit: _pageSize, offset: 0);
      if (mounted) {
        setState(() {
          _videos = items;
        });
      }
    } catch (e) {
      secureLog('Error loading history: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_isLoadMoreRunning || !_hasMore || _isLoading) return;

    setState(() {
      _isLoadMoreRunning = true;
    });

    try {
      final offset = _currentPage * _pageSize;
      final newItems = await DBHelper.instance
          .getHistoryPaged(limit: _pageSize, offset: offset);
      if (mounted) {
        if (newItems.isEmpty) {
          setState(() {
            _hasMore = false;
          });
        } else {
          setState(() {
            _currentPage++;
            _videos.addAll(newItems);
          });
        }
      }
    } catch (e) {
      secureLog('Error loading more history: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadMoreRunning = false;
        });
      }
    }
  }

  Future<void> _triggerManualSync() async {
    if (_isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tarmoqqa ulanib bo\'lmadi! 📵 Offline rejimdasiz.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final changed = await YouTubeUploader.syncYouTubeStatuses();
      if (mounted) {
        if (changed == -1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avtorizatsiya kerak — YouTube akkauntini tekshiring ⚠️'),
              backgroundColor: Colors.orange,
            ),
          );
        } else if (changed == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hammasi yangi, o\'zgarish yo\'q ✅'),
              backgroundColor: Color(0xFF1E1E1E),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$changed ta video yangilandi ✅'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xatolik: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      await _checkNetworkAndLoad();
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  List<HistoryItem> _getFilteredVideos() {
    List<HistoryItem> list = _videos.where((item) {
      // 1. Status Filter
      final state = _getVideoState(item);
      if (_statusFilter == 'Uploaded' && state != 'uploaded') {
        return false;
      }
      if (_statusFilter == 'Deleted' && (state != 'deleted' && state != 'failed')) {
        return false;
      }
      if (_statusFilter == 'Processing' && (state != 'processing' && state != 'uploading' && state != 'queued')) {
        return false;
      }
      if (_statusFilter == 'NotUploaded' && state != 'not_uploaded') {
        return false;
      }

      // 2. Time Filter
      final date = item.date;
      final now = DateTime.now();
      if (_timeFilter == 'Today') {
        if (date.year != now.year ||
            date.month != now.month ||
            date.day != now.day) {
          return false;
        }
      } else if (_timeFilter == 'ThisWeek') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        if (date.isBefore(
          DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
        )) {
          return false;
        }
      } else if (_timeFilter == 'ThisMonth') {
        if (date.year != now.year || date.month != now.month) {
          return false;
        }
      } else if (_timeFilter == 'ThisYear') {
        if (date.year != now.year) {
          return false;
        }
      } else if (_timeFilter == 'Custom' && _customDateRange != null) {
        if (date.isBefore(_customDateRange!.start) ||
            date.isAfter(_customDateRange!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }

      // 3. Channel Filter
      if (_selectedChannels.isNotEmpty) {
        if (!item.isUploaded ||
            !_selectedChannels.contains(item.uploadedChannel)) {
          return false;
        }
      }

      return true;
    }).toList();

    // 4. Sort Filter
    if (_sortFilter == 'Newest') {
      list.sort((a, b) => b.date.compareTo(a.date));
    } else if (_sortFilter == 'Oldest') {
      list.sort((a, b) => a.date.compareTo(b.date));
    } else if (_sortFilter == 'Largest') {
      list.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    } else if (_sortFilter == 'Smallest') {
      list.sort((a, b) => a.sizeBytes.compareTo(b.sizeBytes));
    }

    return list;
  }

  void _openVideo(HistoryItem item) {
    OpenFile.open(item.filePath);
  }

  void _shareVideo(HistoryItem item) {
    // ignore: deprecated_member_use
    Share.shareXFiles([XFile(item.filePath)], text: 'Video: ${item.videoName}');
  }

  Future<void> _deleteVideo(HistoryItem item) async {
    try {
      if (item.id != null) {
        await DBHelper.instance.deleteHistory(item.id!);
      }
      final file = File(item.filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Also delete thumbnail
      if (item.thumbnailPath.isNotEmpty) {
        final thumbFile = File(item.thumbnailPath);
        if (await thumbFile.exists()) {
          await thumbFile.delete();
        }
      }

      _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Video va tarixi o\'chirildi 🗑️'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<bool> _showDeleteConfirmation(
      BuildContext context, HistoryItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tasdiqlash ⚠️',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
            'Haqiqatan ham "${item.videoName}" videosini o\'chirmoqchimisiz?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Yo\'q', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ha, O\'chirish',
                style: TextStyle(
                    color: Color(0xFFFF4444), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }

  Future<void> _openYouTubeLink(String url) async {
    if (url.isEmpty) return;
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Havolani ochib bo\'lmadi ❌'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatShortUzbekDate(DateTime date) {
    final months = [
      'yanvar',
      'fevral',
      'mart',
      'aprel',
      'may',
      'iyun',
      'iyul',
      'avgust',
      'sentabr',
      'oktabr',
      'noyabr',
      'dekabr'
    ];
    return '${date.day}-${months[date.month - 1]}';
  }

  // ignore: unused_element
  Color _getStatusColor(String status) {
    if (status.contains('Public') || status.contains('Ommaviy')) {
      return Colors.greenAccent;
    }
    if (status.contains('Processing') || status.contains('Yuklanmoqda')) {
      return Colors.orangeAccent;
    }
    if (status.contains('Deleted') || status.contains('O\'chirilgan')) {
      return Colors.redAccent;
    }
    if (status.contains('Private') || status.contains('Shaxsiy')) {
      return Colors.blueAccent;
    }
    if (status.contains('Unlisted') || status.contains('Havolali')) {
      return Colors.purpleAccent;
    }
    if (status.contains('Rejected') || status.contains('Rad etilgan')) {
      return Colors.red;
    }
    return Colors.white54;
  }

  Widget _buildThumbnailWidget(HistoryItem item, double width, double height) {
    final isShorts = item.format == 'Shorts';
    final isLocal =
        item.thumbnailPath.isNotEmpty && !item.thumbnailPath.startsWith('http');

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isShorts
            ? const Color(0xFFFF0000).withValues(alpha: 0.1)
            : Colors.greenAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: item.thumbnailPath.isNotEmpty
            ? (isLocal
                ? (File(item.thumbnailPath).existsSync()
                    ? Image.file(
                        File(item.thumbnailPath),
                        fit: BoxFit.cover,
                        cacheWidth: 160,
                        cacheHeight: 160,
                      )
                    : Icon(
                        isShorts ? Icons.bolt : Icons.video_collection,
                        color: isShorts
                            ? const Color(0xFFFF4444)
                            : Colors.greenAccent,
                        size: width * 0.45,
                      ))
                : CachedNetworkImage(
                    imageUrl: item.thumbnailPath,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.white10,
                      child: const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: Colors.white24),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Icon(
                      isShorts ? Icons.bolt : Icons.video_collection,
                      color: isShorts
                          ? const Color(0xFFFF4444)
                          : Colors.greenAccent,
                      size: width * 0.45,
                    ),
                  ))
            : Icon(
                isShorts ? Icons.bolt : Icons.video_collection,
                color: isShorts ? const Color(0xFFFF4444) : Colors.greenAccent,
                size: width * 0.45,
              ),
      ),
    );
  }

  // Determine video state for badge display
  String _getVideoState(HistoryItem item) {
    // Queue states take priority
    if (item.uploadStatus == 'queued') return 'queued';
    if (item.uploadStatus == 'uploading') return 'uploading';
    if (item.uploadStatus == 'failed') return 'failed';

    final status = item.youtubeStatus.toLowerCase();
    if (status.contains('deleted') || status.contains('o\'chirilgan')) {
      return 'deleted';
    }
    if (status.contains('processing') ||
        status.contains('yuklanmoqda') ||
        status.contains('jarayonda') ||
        status.contains('kutilmoqda')) {
      return 'processing';
    }
    if (item.isUploaded) {
      return 'uploaded';
    }
    return 'not_uploaded';
  }

  void _showContextMenu(
      BuildContext context, HistoryItem item, VoidCallback onUpload) {
    final state = _getVideoState(item);
    final isShorts = item.format == 'Shorts';
    final fileExists = File(item.filePath).existsSync();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header: thumbnail + name + badge
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: _buildThumbnailWidget(item, 56, 56),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.videoName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            _buildStateBadge(state, item),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 16),

                // ── State 1: Not uploaded ──
                if (state == 'not_uploaded') ...[
                  _menuTile(ctx,
                      icon: Icons.rocket_launch,
                      color: const Color(0xFFFF0000),
                      label: '🚀 YouTube ga yuklash', onTap: () {
                    Navigator.pop(ctx);
                    onUpload();
                  }),
                  _menuTile(ctx,
                      icon: Icons.play_circle_fill,
                      color: Colors.white70,
                      label: '▶️ Media playerda ko\'rish', onTap: () {
                    Navigator.pop(ctx);
                    _openVideo(item);
                  }),
                  _menuTile(ctx,
                      icon: Icons.drive_file_rename_outline,
                      color: Colors.amberAccent,
                      label: '✏️ Nomini o\'zgartirish', onTap: () {
                    Navigator.pop(ctx);
                    _renameVideo(item);
                  }),
                  _menuTile(ctx,
                      icon: Icons.share,
                      color: Colors.blueAccent,
                      label: '📤 Ulashish', onTap: () {
                    Navigator.pop(ctx);
                    _shareVideo(item);
                  }),
                  _menuTile(ctx,
                      icon: Icons.movie_edit,
                      color: Colors.purpleAccent,
                      label: '🎬 Editorda ochish', onTap: () {
                    Navigator.pop(ctx);
                    _openInEditor(item, isShorts);
                  }),
                  const Divider(color: Colors.white12, height: 1),
                  _menuTile(ctx,
                      iconWidget: const ShakeWidget(
                          shake: true,
                          child: Icon(Icons.delete_forever,
                              color: Colors.redAccent, size: 20)),
                      color: Colors.redAccent,
                      label: '🗑️ O\'chirish',
                      isDestructive: true, onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await _showDeleteConfirmation(context, item);
                    if (ok) _deleteVideo(item);
                  }),
                ],

                // ── State: Queued for upload ──
                if (state == 'queued') ...[
                  _menuTile(ctx,
                      icon: Icons.cloud_upload,
                      color: Colors.blueAccent,
                      label: '☁️ Hozir yuklash', onTap: () {
                    Navigator.pop(ctx);
                    onUpload();
                  }),
                  _menuTile(ctx,
                      icon: Icons.remove_circle_outline,
                      color: Colors.orangeAccent,
                      label: '🗑 Navbatdan olib tashlash', onTap: () async {
                    Navigator.pop(ctx);
                    if (item.id != null) {
                      await UploadQueueService.instance.removeFromQueue(item.id!);
                      _loadHistory();
                    }
                  }),
                  const Divider(color: Colors.white12, height: 1),
                  _menuTile(ctx,
                      iconWidget: const ShakeWidget(
                          shake: true,
                          child: Icon(Icons.delete_forever,
                              color: Colors.redAccent, size: 20)),
                      color: Colors.redAccent,
                      label: '🗑️ O\'chirish',
                      isDestructive: true, onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await _showDeleteConfirmation(context, item);
                    if (ok) _deleteVideo(item);
                  }),
                ],

                // ── State: Upload failed ──
                if (state == 'failed') ...[
                  _menuTile(ctx,
                      icon: Icons.refresh,
                      color: const Color(0xFFFF8800),
                      label: '🔄 Qayta navbatga qo\'shish', onTap: () async {
                    Navigator.pop(ctx);
                    if (item.id != null) {
                      await UploadQueueService.instance.addToQueue(item);
                      _loadHistory();
                    }
                  }),
                  _menuTile(ctx,
                      icon: Icons.cloud_upload,
                      color: Colors.blueAccent,
                      label: '☁️ Hozir yuklash', onTap: () {
                    Navigator.pop(ctx);
                    onUpload();
                  }),
                  const Divider(color: Colors.white12, height: 1),
                  _menuTile(ctx,
                      iconWidget: const ShakeWidget(
                          shake: true,
                          child: Icon(Icons.delete_forever,
                              color: Colors.redAccent, size: 20)),
                      color: Colors.redAccent,
                      label: '🗑️ O\'chirish',
                      isDestructive: true, onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await _showDeleteConfirmation(context, item);
                    if (ok) _deleteVideo(item);
                  }),
                ],

                // ── State 2: Uploaded ──
                if (state == 'uploaded') ...[
                  _menuTile(ctx,
                      icon: Icons.play_circle_fill,
                      color: const Color(0xFFFF0000),
                      label: '▶️ YouTube da ko\'rish', onTap: () {
                    Navigator.pop(ctx);
                    _openYouTubeLink(item.youtubeLink);
                  }),
                  _menuTile(ctx,
                      icon: Icons.copy,
                      color: Colors.white70,
                      label: '📋 YouTube URL ni nusxalash', onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: item.youtubeLink));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('URL nusxalandi! 📋')));
                  }),
                  _menuTile(ctx,
                      icon: Icons.bar_chart,
                      color: Colors.greenAccent,
                      label: '📊 YouTube statistikasini ko\'rish', onTap: () {
                    Navigator.pop(ctx);
                    _openYouTubeLink('https://studio.youtube.com');
                  }),
                  const Divider(color: Colors.white12, height: 1),
                  _menuTile(ctx,
                      iconWidget: const ShakeWidget(
                          shake: true,
                          child: Icon(Icons.delete_forever,
                              color: Colors.redAccent, size: 20)),
                      color: Colors.redAccent,
                      label: '🗑️ Qurilmadan o\'chirish',
                      isDestructive: true, onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await _showDeleteConfirmation(context, item);
                    if (ok) _deleteVideo(item);
                  }),
                ],

                // ── State 3: Deleted from YouTube ──
                if (state == 'deleted') ...[
                  _menuTile(ctx,
                      icon: Icons.cloud_upload,
                      color: const Color(0xFFFF8800),
                      label: '🔄 YouTube ga qayta yuklash', onTap: () {
                    Navigator.pop(ctx);
                    onUpload();
                  }),
                  if (fileExists)
                    _menuTile(ctx,
                        icon: Icons.play_circle_fill,
                        color: Colors.white70,
                        label: '▶️ Media playerda ko\'rish', onTap: () {
                      Navigator.pop(ctx);
                      _openVideo(item);
                    }),
                  const Divider(color: Colors.white12, height: 1),
                  _menuTile(ctx,
                      iconWidget: const ShakeWidget(
                          shake: true,
                          child: Icon(Icons.delete_forever,
                              color: Colors.redAccent, size: 20)),
                      color: Colors.redAccent,
                      label: '🗑️ O\'chirish',
                      isDestructive: true, onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await _showDeleteConfirmation(context, item);
                    if (ok) _deleteVideo(item);
                  }),
                ],

                const Divider(color: Colors.white12, height: 1),
                _menuTile(ctx,
                    icon: Icons.checklist,
                    color: Colors.blueAccent,
                    label: '☑️ Ko\'p tanlash rejimi', onTap: () {
                  Navigator.pop(ctx);
                  _enterMultiSelect(item);
                }),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _menuTile(
    BuildContext ctx, {
    IconData? icon,
    Widget? iconWidget,
    required Color color,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            if (iconWidget != null)
              iconWidget
            else
              Icon(icon!,
                  color: isDestructive ? Colors.redAccent : color, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isDestructive ? Colors.redAccent : Colors.white,
                fontSize: 15,
                fontWeight: isDestructive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateBadge(String state, HistoryItem item) {
    Color color;
    String label;
    bool pulse = false;

    switch (state) {
      case 'queued':
        color = const Color(0xFF448AFF); // blue-accent
        label = 'Navbatda';
        pulse = true;
        break;
      case 'uploading':
        color = const Color(0xFFFF8800); // orange-500
        label = 'Yuklanmoqda';
        pulse = true;
        break;
      case 'failed':
        color = const Color(0xFFFF5252); // red-accent
        label = 'Xato';
        break;
      case 'processing':
        color = const Color(0xFFFFAB40); // orange-accent
        label = 'Jarayonda';
        break;
      case 'uploaded':
        color = const Color(0xFF69F0AE); // green-accent
        label = 'Yuklangan';
        break;
      case 'deleted':
        color = const Color(0xFFFF5252); // red-accent
        label = "O'chirilgan";
        break;
      default:
        color = Colors.white54;
        label = 'Qurilmada';
        break;
    }

    Widget chipContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    if (pulse) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.4, end: 1.0),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOut,
        builder: (context, opacity, child) {
          return Opacity(opacity: opacity, child: child);
        },
        child: chipContent,
      );
    }

    return chipContent;
  }

  Future<void> _renameVideo(HistoryItem item) async {
    final controller = TextEditingController(text: item.videoName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nomini o\'zgartirish ✏️',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFFF0000))),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Bekor', style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Saqlash',
                  style: TextStyle(
                      color: Color(0xFFFF0000), fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != item.videoName) {
      if (item.id != null) {
        await DBHelper.instance
            .updateHistory(item.copyWith(videoName: newName));
        _loadHistory();
      }
    }
  }

  void _openInEditor(HistoryItem item, bool isShorts) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoEditorScreen(filePath: item.filePath),
      ),
    ).then((_) => _loadHistory());
  }

  Future<String?> _showSwipeDeleteConfirmation(
      BuildContext context, HistoryItem item) async {
    final state = _getVideoState(item);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Videoni o\'chirishni tasdiqlaysizmi?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
            'Haqiqatan ham "${item.videoName}" videosini o\'chirmoqchimisiz?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Bekor qilish',
                style: TextStyle(color: Colors.white54)),
          ),
          if (state == 'uploaded') ...[
            TextButton(
              onPressed: () => Navigator.pop(context, 'delete_local'),
              child: const Text('Faqat qurilmadan o\'chirish',
                  style: TextStyle(color: Colors.orangeAccent)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'delete_both'),
              child: const Text('YouTubedan ham o\'chirish',
                  style: TextStyle(
                      color: Color(0xFFFF4444), fontWeight: FontWeight.bold)),
            ),
          ] else ...[
            TextButton(
              onPressed: () => Navigator.pop(context, 'delete'),
              child: const Text('O\'chirish',
                  style: TextStyle(
                      color: Color(0xFFFF4444), fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDismissibleItem({
    required HistoryItem item,
    required Widget child,
    required VoidCallback onUpload,
    required VoidCallback onDelete,
  }) {
    // In multi-select mode, swipe is disabled
    if (_isMultiSelectMode) return child;

    final state = _getVideoState(item);

    // Right-swipe: state-dependent color and action
    Color rightColor;
    IconData rightIcon;
    String rightLabel;
    if (state == 'uploaded') {
      rightColor = Colors.green;
      rightIcon = Icons.play_circle_fill;
      rightLabel = 'YouTube da ko\'rish';
    } else if (state == 'deleted') {
      rightColor = const Color(0xFFFF8800);
      rightIcon = Icons.refresh;
      rightLabel = 'Qayta yuklash';
    } else {
      rightColor = Colors.blue;
      rightIcon = Icons.rocket_launch;
      rightLabel = 'YouTube ga yuklash';
    }

    return Dismissible(
      key: Key(item.id?.toString() ?? UniqueKey().toString()),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.5,
        DismissDirection.endToStart: 0.5,
      },
      movementDuration: const Duration(milliseconds: 200),
      // Right → action
      background: Container(
        decoration: BoxDecoration(
          color: rightColor,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(rightIcon, color: Colors.white, size: 26),
            const SizedBox(width: 10),
            Text(rightLabel,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ],
        ),
      ),
      // Left → delete
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShakeWidget(
                shake: true,
                child:
                    Icon(Icons.delete_forever, color: Colors.white, size: 26)),
            SizedBox(width: 10),
            Text('O\'chirish',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Right swipe action
          if (state == 'uploaded') {
            _openYouTubeLink(item.youtubeLink);
          } else {
            onUpload();
          }
          return false; // Don't remove from list
        } else {
          // Left swipe → confirm delete
          final result = await _showSwipeDeleteConfirmation(context, item);
          if (result == 'delete' ||
              result == 'delete_local' ||
              result == 'delete_both') {
            onDelete();
            return true;
          }
          return false;
        }
      },
      child: child,
    );
  }

  Widget _buildGridItem(HistoryItem item, String formattedSize,
      String shortDate, String status, VoidCallback onUpload) {
    final state = _getVideoState(item);
    final isShorts = item.format == 'Shorts';
    final isSelected =
        _isMultiSelectMode && item.id != null && _selectedIds.contains(item.id);

    return GestureDetector(
      onTap: _isMultiSelectMode ? () => _toggleSelect(item) : null,
      onLongPress: _isMultiSelectMode
          ? () => _toggleSelect(item)
          : () => _showContextMenu(context, item, onUpload),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
          scale: _isMultiSelectMode ? _scaleAnim.value : 1.0,
          child: child,
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _isMultiSelectMode && !isSelected ? 0.7 : 1.0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildThumbnailWidget(item, double.infinity, double.infinity),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.transparent
                        ],
                      ),
                    ),
                    child: Text(
                      item.videoName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Positioned(
                    top: 6, right: 6, child: _buildStateBadge(state, item)),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: isShorts
                          ? const Color(0xFFFF0000)
                          : Colors.green.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(item.format,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                // Multi-select overlay
                if (_isMultiSelectMode)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: isSelected
                              ? Colors.greenAccent
                              : Colors.transparent,
                          width: 3),
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected
                          ? Colors.greenAccent.withValues(alpha: 0.15)
                          : Colors.transparent,
                    ),
                  ),
                if (isSelected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                          color: Colors.greenAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.check,
                          color: Colors.black, size: 16),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListItem(
      HistoryItem item,
      String formattedSize,
      String shortDate,
      String status,
      VoidCallback onUpload,
      VoidCallback onDelete) {
    final state = _getVideoState(item);
    final isDeleted = state == 'deleted';
    final isSelected =
        _isMultiSelectMode && item.id != null && _selectedIds.contains(item.id);

    return GestureDetector(
      onTap: _isMultiSelectMode ? () => _toggleSelect(item) : null,
      onLongPress: _isMultiSelectMode
          ? () => _toggleSelect(item)
          : () => _showContextMenu(context, item, onUpload),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
            scale: _isMultiSelectMode ? _scaleAnim.value : 1.0, child: child),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _isMultiSelectMode && !isSelected ? 0.7 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.greenAccent.withValues(alpha: 0.12)
                  : (isDeleted
                      ? const Color(0xFF2E1A1A)
                      : const Color(0xFF1A1A1A)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? Colors.greenAccent
                    : (isDeleted
                        ? Colors.redAccent.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.04)),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Selection indicator
                  if (_isMultiSelectMode)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? Colors.greenAccent
                            : Colors.transparent,
                        border: Border.all(
                            color: isSelected
                                ? Colors.greenAccent
                                : Colors.white38,
                            width: 2),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.black, size: 14)
                          : null,
                    ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: _buildThumbnailWidget(item, 72, 72),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.videoName,
                          style: TextStyle(
                              color: isDeleted
                                  ? const Color(0xFFFF8888)
                                  : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildStateBadge(state, item),
                            const SizedBox(width: 6),
                            if (item.isUploaded &&
                                item.uploadedChannel.isNotEmpty) ...[
                              const Icon(Icons.tv,
                                  color: Colors.blueAccent, size: 11),
                              const SizedBox(width: 3),
                              Flexible(
                                  child: Text(item.uploadedChannel,
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 10),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text('📅 $shortDate',
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 10)),
                            const SizedBox(width: 8),
                            Text(formattedSize,
                                style: const TextStyle(
                                    color: Colors.white24, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!_isMultiSelectMode)
                    const Icon(Icons.more_vert,
                        color: Colors.white24, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactItem(HistoryItem item, String formattedSize,
      String shortDate, String status, VoidCallback onUpload) {
    final state = _getVideoState(item);
    final isSelected =
        _isMultiSelectMode && item.id != null && _selectedIds.contains(item.id);
    return GestureDetector(
      onTap: _isMultiSelectMode ? () => _toggleSelect(item) : null,
      onLongPress: _isMultiSelectMode
          ? () => _toggleSelect(item)
          : () => _showContextMenu(context, item, onUpload),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
            scale: _isMultiSelectMode ? _scaleAnim.value : 1.0, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 56,
          color: isSelected
              ? Colors.greenAccent.withValues(alpha: 0.08)
              : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              children: [
                if (_isMultiSelectMode)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          isSelected ? Colors.greenAccent : Colors.transparent,
                      border: Border.all(
                          color:
                              isSelected ? Colors.greenAccent : Colors.white38,
                          width: 2),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.black, size: 13)
                        : null,
                  ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: _buildThumbnailWidget(item, 40, 52),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.videoName,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStateBadge(state, item),
                    const SizedBox(height: 2),
                    Text('📅 $shortDate',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _getFilteredVideos();

    return PopScope(
      canPop: !_isMultiSelectMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isMultiSelectMode) {
          _exitMultiSelect();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: _isMultiSelectMode
            ? AppBar(
                backgroundColor: const Color(0xFF1A1A1A),
                leadingWidth: 90,
                leading: TextButton.icon(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 20),
                  label: const Text('Bekor',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  onPressed: _exitMultiSelect,
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
                title: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    '${_selectedIds.length} ta video tanlandi',
                    key: ValueKey<int>(_selectedIds.length),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: _selectAll,
                    child: const Text('Barchasini tanlash',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                  IconButton(
                    icon: const ShakeWidget(
                        shake: true,
                        child: Icon(Icons.delete, color: Colors.redAccent)),
                    onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                    tooltip: 'O\'chirish',
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.blueAccent),
                    onPressed: _selectedIds.isEmpty ? null : _shareSelected,
                    tooltip: 'Ulashish',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.rocket_launch,
                      color: _selectedIds.isNotEmpty &&
                              _videos.any((v) =>
                                  _selectedIds.contains(v.id) && !v.isUploaded)
                          ? const Color(0xFFFF0000)
                          : Colors.white30,
                    ),
                    onPressed: _selectedIds.isNotEmpty &&
                            _videos.any((v) =>
                                _selectedIds.contains(v.id) && !v.isUploaded)
                        ? _uploadSelected
                        : null,
                    tooltip: 'YouTube ga yuklash',
                  ),
                ],
              )
            : AppBar(
                backgroundColor: const Color(0xFF1A1A1A),
                title: const Text('Videolar',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                iconTheme: const IconThemeData(color: Colors.white),
                elevation: 0,
                actions: [
                  Builder(builder: (context) {
                    int filterCount = 0;
                    if (_statusFilter != 'All') filterCount++;
                    if (_timeFilter != 'All') filterCount++;
                    if (_sortFilter != 'Newest') filterCount++;
                    filterCount += _selectedChannels.length;

                    Widget filterIcon =
                        const Icon(Icons.filter_list, color: Colors.white70);
                    if (filterCount > 0) {
                      filterIcon = Badge(
                        label: Text('$filterCount'),
                        backgroundColor: Colors.redAccent,
                        child: filterIcon,
                      );
                    }

                    return IconButton(
                      icon: filterIcon,
                      onPressed: () => _openFilterBottomSheet(),
                      tooltip: 'Filtrlash',
                    );
                  }),
                  IconButton(
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white70, strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, color: Colors.white70),
                    onPressed: _isSyncing ? null : _triggerManualSync,
                    tooltip: 'Sinxronlashtirish',
                  ),
                  // Yuqori o'ngda 3 ta ko'rinishni bitta tugmada aylantirish
                  IconButton(
                    icon: Icon(
                      _viewMode == 'grid'
                          ? Icons.grid_view
                          : _viewMode == 'compact'
                              ? Icons.view_headline
                              : Icons.view_list,
                      color: Colors.white70,
                    ),
                    tooltip: 'Ko\'rinishni o\'zgartirish',
                    onPressed: () {
                      String nextMode;
                      if (_viewMode == 'list') {
                        nextMode = 'grid';
                      } else if (_viewMode == 'grid') {
                        nextMode = 'compact';
                      } else {
                        nextMode = 'list';
                      }
                      _saveViewMode(nextMode);
                    },
                  ),
                ],
              ),
        body: Column(
          children: [
            // Network Offline Status Bar
            if (_isOffline)
              Container(
                width: double.infinity,
                color: Colors.orange.withValues(alpha: 0.85),
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                child: const Text(
                  '📵 Offline — So\'nggi saqlangan holatlar ko\'rsatilmoqda',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),

            // Segmented filter row
            _buildSegmentedFilterRow(),

            // Filter Chips
            _buildFilterChips(),

            Expanded(
              child: _isLoading
                  ? _buildShimmerContent()
                  : filteredList.isEmpty
                      ? _buildEmptyFilteredState()
                      : _buildHistoryContent(filteredList),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerContent() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2A2A2A),
      highlightColor: const Color(0xFF3A3A3A),
      child: _viewMode == 'grid'
          ? GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 9 / 16,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 6,
              itemBuilder: (context, index) => _buildGridShimmerItem(index),
            )
          : _viewMode == 'compact'
              ? ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  itemCount: 8,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white12, height: 1),
                  itemBuilder: (context, index) =>
                      _buildCompactShimmerItem(index),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: 6,
                  itemBuilder: (context, index) => _buildListShimmerItem(index),
                ),
    );
  }

  Widget _buildGridShimmerItem(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: Container(
        decoration: BoxDecoration(
            color: Colors.black, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Expanded(
                child: Container(
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(16))))),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 14, width: double.infinity, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 80, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListShimmerItem(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 100,
        decoration: BoxDecoration(
            color: Colors.black, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.horizontal(left: Radius.circular(12)))),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 14,
                        width: double.infinity,
                        color: Colors.white),
                    const SizedBox(height: 8),
                    Container(height: 12, width: 120, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(height: 12, width: 80, color: Colors.white),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactShimmerItem(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
        child: Row(
          children: [
            Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8))),
            const SizedBox(width: 12),
            Expanded(child: Container(height: 14, color: Colors.white)),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryContent(List<HistoryItem> filteredList) {
    if (_viewMode == 'grid') {
      return GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 9 / 16, // Shorts format
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: filteredList.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filteredList.length) {
            return const SizedBox.shrink();
          }

          final item = filteredList[index];
          final isShorts = item.format == 'Shorts';
          final formattedSize = _formatSize(item.sizeBytes);
          final shortDate = _formatShortUzbekDate(item.date);
          final status = item.youtubeStatus.isNotEmpty
              ? item.youtubeStatus
              : 'Tekshirilmagan';

          final gridWidget = _buildGridItem(
            item,
            formattedSize,
            shortDate,
            status,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UploadScreen(
                    filePath: item.filePath,
                    isShorts: isShorts,
                  ),
                ),
              ).then((_) => _loadHistory());
            },
          );

          // Wrap in Dismissible for Swipe Actions
          return _buildDismissibleItem(
            item: item,
            child: gridWidget,
            onUpload: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UploadScreen(
                    filePath: item.filePath,
                    isShorts: isShorts,
                  ),
                ),
              ).then((_) => _loadHistory());
            },
            onDelete: () => _deleteVideo(item),
          );
        },
      );
    } else if (_viewMode == 'compact') {
      return ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        itemCount: filteredList.length + (_hasMore ? 1 : 0),
        separatorBuilder: (context, index) =>
            const Divider(color: Colors.white12, height: 1),
        itemBuilder: (context, index) {
          if (index == filteredList.length) {
            return const SizedBox.shrink();
          }

          final item = filteredList[index];
          final isShorts = item.format == 'Shorts';
          final formattedSize = _formatSize(item.sizeBytes);
          final shortDate = _formatShortUzbekDate(item.date);
          final status = item.youtubeStatus.isNotEmpty
              ? item.youtubeStatus
              : 'Tekshirilmagan';

          final compactWidget = _buildCompactItem(
            item,
            formattedSize,
            shortDate,
            status,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UploadScreen(
                    filePath: item.filePath,
                    isShorts: isShorts,
                  ),
                ),
              ).then((_) => _loadHistory());
            },
          );

          // Wrap in Dismissible for Swipe Actions
          return _buildDismissibleItem(
            item: item,
            child: compactWidget,
            onUpload: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UploadScreen(
                    filePath: item.filePath,
                    isShorts: isShorts,
                  ),
                ),
              ).then((_) => _loadHistory());
            },
            onDelete: () => _deleteVideo(item),
          );
        },
      );
    } else {
      // Default: List view
      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        itemCount: filteredList.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filteredList.length) {
            return const SizedBox.shrink();
          }

          final item = filteredList[index];
          final isShorts = item.format == 'Shorts';
          final formattedSize = _formatSize(item.sizeBytes);
          final shortDate = _formatShortUzbekDate(item.date);
          final status = item.youtubeStatus.isNotEmpty
              ? item.youtubeStatus
              : 'Tekshirilmagan';

          final listWidget = _buildListItem(
            item,
            formattedSize,
            shortDate,
            status,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UploadScreen(
                    filePath: item.filePath,
                    isShorts: isShorts,
                  ),
                ),
              ).then((_) => _loadHistory());
            },
            () => _deleteVideo(item),
          );

          // Wrap in Dismissible for Swipe Actions
          return _buildDismissibleItem(
            item: item,
            child: listWidget,
            onUpload: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UploadScreen(
                    filePath: item.filePath,
                    isShorts: isShorts,
                  ),
                ),
              ).then((_) => _loadHistory());
            },
            onDelete: () => _deleteVideo(item),
          );
        },
      );
    }
  }

  Widget _buildEmptyFilteredState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'Bu filtr bo\'yicha video topilmadi',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _statusFilter = 'All';
                _timeFilter = 'All';
                _customDateRange = null;
                _selectedChannels.clear();
                _sortFilter = 'Newest';
              });
            },
            icon: const Icon(Icons.clear_all, color: Colors.redAccent),
            label: const Text('Filterni tozalash',
                style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    List<Widget> chips = [];

    Widget buildChip(String label, Color color, VoidCallback onRemove) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.close, size: 14, color: color),
              ),
            ],
          ),
        ),
      );
    }

    if (_statusFilter != 'All') {
      String label = '';
      Color color = Colors.white;
      if (_statusFilter == 'Uploaded') {
        label = '✅ Yuklangan';
        color = Colors.greenAccent;
      } else if (_statusFilter == 'Deleted') {
        label = '❌ O\'chirilgan';
        color = Colors.redAccent;
      } else if (_statusFilter == 'Processing') {
        label = '⏳ Jarayonda';
        color = Colors.orangeAccent;
      } else if (_statusFilter == 'NotUploaded') {
        label = '📂 Yuklanmagan';
        color = Colors.grey;
      }
      chips.add(
          buildChip(label, color, () => setState(() => _statusFilter = 'All')));
    }

    if (_timeFilter != 'All') {
      String label = '';
      if (_timeFilter == 'Today') {
        label = '📅 Bugun';
      } else if (_timeFilter == 'ThisWeek') {
        label = '📅 Bu hafta';
      } else if (_timeFilter == 'ThisMonth') {
        label = '📅 Bu oy';
      } else if (_timeFilter == 'ThisYear') {
        label = '📅 Bu yil';
      } else if (_timeFilter == 'Custom') {
        label = '📅 Tanlangan sana';
      }
      chips.add(buildChip(
          label,
          Colors.blueAccent,
          () => setState(() {
                _timeFilter = 'All';
                _customDateRange = null;
              })));
    }

    if (_sortFilter != 'Newest') {
      String label = '';
      if (_sortFilter == 'Oldest') {
        label = '🕐 Eski';
      } else if (_sortFilter == 'Largest') {
        label = '📦 Katta';
      } else if (_sortFilter == 'Smallest') {
        label = '📦 Kichik';
      }
      chips.add(buildChip(label, Colors.purpleAccent,
          () => setState(() => _sortFilter = 'Newest')));
    }

    for (String channel in _selectedChannels) {
      chips.add(buildChip('📺 $channel', Colors.orange,
          () => setState(() => _selectedChannels.remove(channel))));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF1A1A1A),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: chips,
      ),
    );
  }

  Widget _buildSegmentedFilterRow() {
    final segments = [
      {'value': 'All', 'label': 'Barchasi', 'color': const Color(0xFFFF0000), 'dot': false},
      {'value': 'Uploaded', 'label': 'Yuklangan', 'color': const Color(0xFF69F0AE), 'dot': true},
      {'value': 'NotUploaded', 'label': 'Qurilmada', 'color': Colors.white54, 'dot': true},
      {'value': 'Processing', 'label': 'Jarayonda', 'color': const Color(0xFFFFAB40), 'dot': true},
      {'value': 'Deleted', 'label': "O'chirilgan", 'color': const Color(0xFFFF5252), 'dot': true},
    ];

    return Container(
      height: 50,
      color: const Color(0xFF0F0F0F),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: segments.map((seg) {
            final String val = seg['value'] as String;
            final String label = seg['label'] as String;
            final Color color = seg['color'] as Color;
            final bool hasDot = seg['dot'] as bool;

            final isSelected = _statusFilter == val;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _statusFilter = val;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.15) : const Color(0xFF161616),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? color.withValues(alpha: 0.55) : Colors.white10,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasDot) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? color : Colors.white24,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? color : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_getSegmentCount(val)}',
                        style: TextStyle(
                          color: isSelected ? color : Colors.white30,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  int _getSegmentCount(String value) {
    if (value == 'All') return _videos.length;
    return _videos.where((item) {
      final state = _getVideoState(item);
      if (value == 'Uploaded') return state == 'uploaded';
      if (value == 'NotUploaded') return state == 'not_uploaded';
      if (value == 'Processing') return state == 'processing' || state == 'uploading' || state == 'queued';
      if (value == 'Deleted') return state == 'deleted' || state == 'failed';
      return false;
    }).length;
  }

  void _openFilterBottomSheet() {
    String tempStatus = _statusFilter;
    String tempTime = _timeFilter;
    DateTimeRange? tempCustomDateRange = _customDateRange;
    List<String> tempChannels = List.from(_selectedChannels);
    String tempSort = _sortFilter;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Widget buildSectionTitle(String title) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              );
            }

            Widget buildRadioButton(String title, String value,
                String groupValue, ValueChanged<String?> onChanged) {
              final isSelected = value == groupValue;
              return InkWell(
                onTap: () => onChanged(value),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected ? Colors.redAccent : Colors.white30,
                          size: 20),
                      const SizedBox(width: 12),
                      Text(title,
                          style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 14)),
                    ],
                  ),
                ),
              );
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, controller) {
                return Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        border:
                            Border(bottom: BorderSide(color: Colors.white10)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('🔽 Filtr',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempStatus = 'All';
                                tempTime = 'All';
                                tempCustomDateRange = null;
                                tempChannels.clear();
                                tempSort = 'Newest';
                              });
                            },
                            child: const Text('Tozalash',
                                style: TextStyle(color: Colors.white54)),
                          )
                        ],
                      ),
                    ),
                    // Content
                    Expanded(
                      child: ListView(
                        controller: controller,
                        children: [
                          const SizedBox(height: 8),
                          buildSectionTitle('Video holati'),
                          buildRadioButton('📱 Barchasi', 'All', tempStatus,
                              (v) => setModalState(() => tempStatus = v!)),
                          buildRadioButton(
                              '✅ Yuklangan',
                              'Uploaded',
                              tempStatus,
                              (v) => setModalState(() => tempStatus = v!)),
                          buildRadioButton(
                              '❌ O\'chirilgan',
                              'Deleted',
                              tempStatus,
                              (v) => setModalState(() => tempStatus = v!)),
                          buildRadioButton(
                              '⏳ Jarayonda',
                              'Processing',
                              tempStatus,
                              (v) => setModalState(() => tempStatus = v!)),
                          buildRadioButton(
                              '📂 Yuklanmagan',
                              'NotUploaded',
                              tempStatus,
                              (v) => setModalState(() => tempStatus = v!)),
                          const Divider(color: Colors.white10, height: 24),
                          buildSectionTitle('Vaqt bo\'yicha'),
                          buildRadioButton('📅 Barchasi', 'All', tempTime,
                              (v) => setModalState(() => tempTime = v!)),
                          buildRadioButton('📅 Bugun', 'Today', tempTime,
                              (v) => setModalState(() => tempTime = v!)),
                          buildRadioButton('📅 Bu hafta', 'ThisWeek', tempTime,
                              (v) => setModalState(() => tempTime = v!)),
                          buildRadioButton('📅 Bu oy', 'ThisMonth', tempTime,
                              (v) => setModalState(() => tempTime = v!)),
                          buildRadioButton('📅 Bu yil', 'ThisYear', tempTime,
                              (v) => setModalState(() => tempTime = v!)),
                          buildRadioButton(
                              '📅 Sana tanlash', 'Custom', tempTime, (v) async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              builder: (context, child) => Theme(
                                data: ThemeData.dark().copyWith(
                                  colorScheme: const ColorScheme.dark(
                                      primary: Colors.redAccent,
                                      onPrimary: Colors.white,
                                      surface: Color(0xFF1E1E1E),
                                      onSurface: Colors.white),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setModalState(() {
                                tempTime = 'Custom';
                                tempCustomDateRange = picked;
                              });
                            }
                          }),
                          const Divider(color: Colors.white10, height: 24),
                          buildSectionTitle('Kanal bo\'yicha'),
                          Consumer<SettingsProvider>(
                            builder: (context, settings, _) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Wrap(
                                  spacing: 8,
                                  children: settings.accounts.map((acc) {
                                    final isSelected =
                                        tempChannels.contains(acc.name);
                                    return ChoiceChip(
                                      label: Text(acc.name),
                                      selected: isSelected,
                                      selectedColor:
                                          Colors.orange.withValues(alpha: 0.3),
                                      backgroundColor: Colors.white10,
                                      labelStyle: TextStyle(
                                          color: isSelected
                                              ? Colors.orangeAccent
                                              : Colors.white70,
                                          fontSize: 12),
                                      side: BorderSide(
                                          color: isSelected
                                              ? Colors.orange
                                              : Colors.transparent),
                                      onSelected: (val) {
                                        setModalState(() {
                                          if (val) {
                                            tempChannels.add(acc.name);
                                          } else {
                                            tempChannels.remove(acc.name);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              );
                            },
                          ),
                          const Divider(color: Colors.white10, height: 24),
                          buildSectionTitle('Tartib bo\'yicha'),
                          buildRadioButton('🕐 Yangi', 'Newest', tempSort,
                              (v) => setModalState(() => tempSort = v!)),
                          buildRadioButton('🕐 Eski', 'Oldest', tempSort,
                              (v) => setModalState(() => tempSort = v!)),
                          buildRadioButton('📦 Katta', 'Largest', tempSort,
                              (v) => setModalState(() => tempSort = v!)),
                          buildRadioButton('📦 Kichik', 'Smallest', tempSort,
                              (v) => setModalState(() => tempSort = v!)),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    // Footer Apply button
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            setState(() {
                              _statusFilter = tempStatus;
                              _timeFilter = tempTime;
                              _customDateRange = tempCustomDateRange;
                              _selectedChannels = tempChannels;
                              _sortFilter = tempSort;
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text('Filterni qo\'llash',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
