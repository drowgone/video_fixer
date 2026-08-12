import 'dart:async';
import 'notification_service.dart';

class ForegroundUploaderService {
  ForegroundUploaderService._();
  static final ForegroundUploaderService instance = ForegroundUploaderService._();

  static const int _notificationId = 8888;
  Timer? _progressTimer;

  /// Starts a simulated resilient background foreground upload task.
  /// Shows a persistent, non-dismissible notification indicating progress.
  Future<void> startBackgroundUpload({
    required String videoName,
    required Future<bool> Function(Function(double progress)) uploadCallback,
  }) async {
    _progressTimer?.cancel();

    double currentProgress = 0.0;
    await NotificationService.showPersistentProgressNotification(
      id: _notificationId,
      title: 'YouTube-ga yuklanmoqda',
      body: '$videoName: 0%',
      progress: 0,
    );

    // Call the actual upload operation, updating our persistent notification
    try {
      final success = await uploadCallback((prog) {
        currentProgress = prog * 100;
        NotificationService.showPersistentProgressNotification(
          id: _notificationId,
          title: 'YouTube-ga yuklanmoqda',
          body: '$videoName: ${currentProgress.toInt()}%',
          progress: currentProgress.toInt(),
        );
      });

      await NotificationService.cancelNotification(_notificationId);

      if (success) {
        await NotificationService.showNotification(
          id: 9999,
          title: 'Yuklash Muvaffaqiyatli yakunlandi! 🎉',
          body: '$videoName YouTube kanaliga yuklandi.',
        );
      } else {
        await NotificationService.showNotification(
          id: 9999,
          title: 'Yuklashda xatolik ❌',
          body: '$videoName yuklanmadi.',
        );
      }
    } catch (e) {
      await NotificationService.cancelNotification(_notificationId);
      await NotificationService.showNotification(
        id: 9999,
        title: 'Yuklashda kutilmagan xatolik ❌',
        body: '$videoName yuklash jarayonida xato yuz berdi.',
      );
    }
  }

  /// Cancels the ongoing foreground task and dismisses the notification.
  Future<void> stopBackgroundUpload() async {
    _progressTimer?.cancel();
    await NotificationService.cancelNotification(_notificationId);
  }
}
