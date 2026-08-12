import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import '../main.dart';

enum NotifChannel { sync, ready }

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    try {
      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload == 'home') {
            MainTabScreen.onSwitchTab?.call(0);
          } else if (response.payload == 'history') {
            MainTabScreen.onSwitchTab?.call(1);
          }
        },
      );
      _initialized = true;
    } on MissingPluginException {
      _initialized = false;
      return;
    }

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotifChannel channel = NotifChannel.sync,
  }) async {
    if (!_initialized) return;

    final AndroidNotificationDetails androidDetails = channel == NotifChannel.ready
        ? const AndroidNotificationDetails(
            'video_ready_channel',
            'Video Tayyor',
            channelDescription: 'Video qayta ishlash tugaganligi haqida bildirishnoma',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            playSound: false,
            enableVibration: false,
          )
        : const AndroidNotificationDetails(
            'youtube_sync_channel',
            'YouTube Status',
            channelDescription: 'YouTube video holati yangilanishlari',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
          );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } on MissingPluginException {
      // Ignore when plugin is unavailable on this runtime.
    }
  }

  static Future<void> showPersistentProgressNotification({
    required int id,
    required String title,
    required String body,
    required int progress, // 0 to 100
  }) async {
    if (!_initialized) return;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'youtube_upload_foreground_channel',
      'Video Yuklash (Fonda)',
      channelDescription: 'Fonda video yuklash jarayoni bildirishnomasi',
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
      enableVibration: false,
      ongoing: true, // Non-dismissible
      showProgress: true,
      maxProgress: 100,
      progress: progress,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
      );
    } on MissingPluginException {
      // Ignore
    }
  }

  static Future<void> cancelNotification(int id) async {
    if (!_initialized) return;
    try {
      await _notificationsPlugin.cancel(id);
    } on MissingPluginException {
      // Ignore
    }
  }
}
