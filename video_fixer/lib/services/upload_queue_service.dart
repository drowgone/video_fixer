import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/history_item.dart';
import 'db_helper.dart';
import 'security_service.dart';

/// Tracks the offline upload queue and connectivity state.
/// Handles queue management only; the actual upload is performed through UploadScreen.
class UploadQueueService extends ChangeNotifier {
  UploadQueueService._();
  static final UploadQueueService instance = UploadQueueService._();

  bool _isOnline = true;
  int _queueCount = 0;

  bool get isOnline => _isOnline;
  int get queueCount => _queueCount;

  Future<void> initialize() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _isOnline = results.any((r) => r != ConnectivityResult.none);

      Connectivity().onConnectivityChanged.listen((results) {
        final online = results.any((r) => r != ConnectivityResult.none);
        if (online != _isOnline) {
          _isOnline = online;
          notifyListeners();
        }
      });
    } catch (e) {
      secureLog('UploadQueueService.initialize error: $e');
    }

    await refreshQueueCount();
  }

  Future<void> refreshQueueCount() async {
    try {
      _queueCount = await DBHelper.instance.getQueueCount();
      notifyListeners();
    } catch (e) {
      secureLog('UploadQueueService.refreshQueueCount error: $e');
    }
  }

  /// Marks a history item as queued for upload.
  Future<bool> addToQueue(HistoryItem item) async {
    if (item.id == null) return false;
    try {
      await DBHelper.instance.setUploadStatus(
        item.id!,
        'queued',
        queueAddedAt: DateTime.now().toIso8601String(),
        uploadError: '',
      );
      await refreshQueueCount();
      return true;
    } catch (e) {
      secureLog('UploadQueueService.addToQueue error: $e');
      return false;
    }
  }

  /// Removes an item from the queue (back to not_uploaded).
  Future<void> removeFromQueue(int id) async {
    try {
      await DBHelper.instance.setUploadStatus(id, 'not_uploaded',
          queueAddedAt: '', uploadError: '');
      await refreshQueueCount();
    } catch (e) {
      secureLog('UploadQueueService.removeFromQueue error: $e');
    }
  }

  Future<List<HistoryItem>> getQueuedUploads() {
    return DBHelper.instance.getQueuedUploads();
  }
}
