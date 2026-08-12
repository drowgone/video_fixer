import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/youtube/v3.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/youtube_account.dart';
import '../models/history_item.dart';
import 'db_helper.dart';
import 'notification_service.dart';
import 'security_service.dart';

class YouTubeUploader {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      YouTubeApi.youtubeUploadScope,
      YouTubeApi.youtubeReadonlyScope,
    ],
  );

  static Future<List<YouTubeAccount>> connectAndFetchChannels(
      BuildContext context) async {
    try {
      // Har safar akkaunt tanlash oynasi chiqishi uchun tizimdan chiqib yuboramiz
      await _googleSignIn.signOut();
      final googleAccount = await _googleSignIn.signIn();
      if (googleAccount == null) throw Exception('Avtorizatsiya bekor qilindi');

      final authClient = await _googleSignIn.authenticatedClient();
      if (authClient == null) throw Exception('Google auth client olinmadi');

      final youtubeApi = YouTubeApi(authClient);

      final response = await youtubeApi.channels.list(
        ['snippet', 'statistics'],
        mine: true,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Vaqt tugadi'),
      );

      if (response.items == null || response.items!.isEmpty) {
        throw Exception('Bu Google akkauntda YouTube kanal topilmadi.');
      }

      // Extract tokens to fulfill storage requirement (even though google_sign_in handles it internally)
      final auth = await googleAccount.authentication;
      final dummyCredentials = json.encode({
        'access_token': auth.accessToken,
        'id_token': auth.idToken,
      });

      List<YouTubeAccount> fetchedAccounts = [];
      for (var channel in response.items!) {
        final snippet = channel.snippet;
        final stats = channel.statistics;
        fetchedAccounts.add(YouTubeAccount(
          id: channel.id ?? const Uuid().v4(),
          name: snippet?.title ?? googleAccount.displayName ?? 'Noma\'lum',
          clientId:
              googleAccount.email, // Use clientId to store the Google email
          clientSecret: '', // Not needed anymore
          channelId: channel.id ?? '',
          channelProfilePic:
              snippet?.thumbnails?.default_?.url ?? googleAccount.photoUrl,
          connectionDate: DateTime.now(),
          status: 'active',
          isActive: true,
          savedCredentials: dummyCredentials,
          subscriberCount: stats?.subscriberCount?.toString() ?? '0',
          videoCount: stats?.videoCount?.toString() ?? '0',
        ));
      }
      return fetchedAccounts;
    } on PlatformException catch (e) {
      throw Exception(_mapGoogleSignInPlatformError(e));
    } catch (e) {
      throw Exception('Kanallarni olishda xatolik: $e');
    }
  }

  static String _mapGoogleSignInPlatformError(PlatformException e) {
    final code = e.code.toLowerCase();
    final msg = (e.message ?? '').toLowerCase();

    if (code.contains('network_error') || msg.contains('network')) {
      return 'Internet bilan bog\'lanishda xatolik. Tarmoqni tekshirib qayta urinib ko\'ring.';
    }
    if (msg.contains('10') ||
        code.contains('sign_in_failed') ||
        msg.contains('developer_error')) {
      return 'Google Sign-In konfiguratsiyasi to\'liq emas (OAuth/SHA-1). '
          'Android uchun SHA-1 ni Google Cloud/Firebase’da qo\'shing va google-services.json ni yangilang.';
    }
    if (msg.contains('12500') || msg.contains('12501')) {
      return 'Google akkauntga kirish bekor qilindi yoki ruxsat rad etildi. Qayta urinib ko\'ring.';
    }
    return 'Google orqali ulashda xatolik: ${e.code}${e.message != null ? ' - ${e.message}' : ''}';
  }

  static Future<String> upload({
    required YouTubeAccount account,
    required File videoFile,
    required String title,
    required String description,
    required List<String> tags,
    required String privacyStatus,
    required String categoryId,
    required bool isMadeForKids,
    required String language,
    required String location,
    DateTime? publishAt,
    String videoType = 'short',
    required Function(int bytesSent, int totalBytes) onProgress,
  }) async {
    var googleAccount = _googleSignIn.currentUser;

    if (googleAccount == null || googleAccount.email != account.clientId) {
      // Try silently first
      googleAccount = await _googleSignIn.signInSilently();

      if (googleAccount == null || googleAccount.email != account.clientId) {
        // If it's a different account or no account, force interactive sign in
        await _googleSignIn.signOut();
        googleAccount = await _googleSignIn.signIn();

        if (googleAccount == null) {
          throw Exception('Avtorizatsiya bekor qilindi.');
        }
        if (googleAccount.email != account.clientId) {
          throw Exception(
              'Iltimos, aynan ${account.clientId} akkauntiga kiring!');
        }
      }
    }

    final authClient = await _googleSignIn.authenticatedClient();
    if (authClient == null) throw Exception('Avtorizatsiya mavjud emas.');

    final youtubeApi = YouTubeApi(authClient);

    final videoStatus = VideoStatus()..privacyStatus = privacyStatus;
    if (publishAt != null) {
      videoStatus.publishAt = publishAt;
      videoStatus.privacyStatus = 'private'; // Required for scheduling
    }
    videoStatus.selfDeclaredMadeForKids = isMadeForKids;

    final videoSnippet = VideoSnippet()
      ..title = title
      ..description = description
      ..tags = tags
      ..categoryId = categoryId
      ..defaultLanguage = language
      ..defaultAudioLanguage = language;

    final video = Video()
      ..snippet = videoSnippet
      ..status = videoStatus;

    if (location.isNotEmpty) {
      video.recordingDetails = VideoRecordingDetails()
        ..locationDescription = location;
    }

    final fileLength = await videoFile.length();
    int uploadedBytes = 0;

    Stream<List<int>> byteStream = videoFile.openRead().transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (List<int> data, EventSink<List<int>> sink) {
          uploadedBytes += data.length;
          onProgress(uploadedBytes, fileLength);
          sink.add(data);
        },
      ),
    );

    final media = Media(byteStream, fileLength);

    try {
      final result = await youtubeApi.videos.insert(
        video,
        ['snippet', 'status', 'recordingDetails'],
        uploadMedia: media,
        uploadOptions: UploadOptions.resumable,
      );

      if (result.id != null) {
        return 'https://youtu.be/${result.id}';
      } else {
        throw Exception(
            'Video ID qaytmadi, yuklashda xatolik bo\'lishi mumkin.');
      }
    } catch (e) {
      throw Exception('Yuklash xatosi: $e');
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  static Future<String> checkVideoStatus(String videoUrl) async {
    try {
      final videoId = _extractVideoId(videoUrl);
      if (videoId == null) return 'No URL';

      var googleAccount = await _googleSignIn.signInSilently();
      googleAccount ??= _googleSignIn.currentUser;
      if (googleAccount == null) {
        return 'Auth Required';
      }

      final authClient = await _googleSignIn.authenticatedClient();
      if (authClient == null) return 'Auth Required';

      final youtubeApi = YouTubeApi(authClient);
      final response = await youtubeApi.videos
          .list(['status', 'snippet'], id: [videoId]).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Vaqt tugadi'),
      );

      if (response.items == null || response.items!.isEmpty) {
        return 'Not Found / Deleted';
      }

      final video = response.items!.first;
      final uploadStatus = video.status
          ?.uploadStatus; // 'uploaded', 'processed', 'failed', 'rejected'
      final failureReason = video.status?.failureReason;
      final rejectReason = video.status?.rejectionReason;

      if (uploadStatus == 'processed') {
        return 'Published ✅';
      } else if (uploadStatus == 'uploaded') {
        return 'Processing ⏳';
      } else if (uploadStatus == 'failed') {
        return 'Failed ❌ (${failureReason ?? "Unknown Error"})';
      } else if (uploadStatus == 'rejected') {
        return 'Rejected ❌ (${rejectReason ?? "Violation"})';
      }

      return 'Status: $uploadStatus';
    } catch (e) {
      return 'Status unavailable';
    }
  }

  static String? _extractVideoId(String url) {
    final regExp = RegExp(
      r'^.*((youtu.be\/)|(v\/)|(\/u\/\w\/)|(embed\/)|(watch\?))\??v?=?([^#\&\?]*).*',
      caseSensitive: false,
      multiLine: false,
    );
    final match = regExp.firstMatch(url);
    if (match != null &&
        match.group(7) != null &&
        match.group(7)!.length == 11) {
      return match.group(7);
    }
    return null;
  }

  /// Returns the number of items whose status changed, or -1 on failure.
  static Future<int> syncYouTubeStatuses() async {
    try {
      final historyList = await DBHelper.instance.getAllHistory();
      final uploadedItems = historyList
          .where((item) => item.isUploaded && item.youtubeLink.isNotEmpty)
          .toList();
      if (uploadedItems.isEmpty) return 0;
      int changedCount = 0;

      // Silently sign in to retrieve authorized client (also refreshes expired tokens)
      var googleAccount = await _googleSignIn.signInSilently();
      googleAccount ??= _googleSignIn.currentUser;
      if (googleAccount == null) {
        secureLog("Sync status: No logged-in account — skipping background sync.");
        return 0;
      }

      final authClient = await _googleSignIn.authenticatedClient();
      if (authClient == null) {
        secureLog("Sync status: Could not acquire authenticated client — skipping.");
        return 0;
      }

      final youtubeApi = YouTubeApi(authClient);

      // Batch in chunks of 50
      const int chunkSize = 50;
      for (int i = 0; i < uploadedItems.length; i += chunkSize) {
        final chunk = uploadedItems.sublist(
            i,
            i + chunkSize > uploadedItems.length
                ? uploadedItems.length
                : i + chunkSize);
        final idToItem = <String, HistoryItem>{};
        final idsList = <String>[];

        for (var item in chunk) {
          final vidId = _extractVideoId(item.youtubeLink);
          if (vidId != null) {
            idToItem[vidId] = item;
            idsList.add(vidId);
          }
        }

        if (idsList.isEmpty) continue;

        final response = await youtubeApi.videos.list(
          ['status', 'snippet'],
          id: idsList,
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException('Vaqt tugadi'),
        );

        final foundIds = <String>{};
        if (response.items != null) {
          for (var video in response.items!) {
            final vidId = video.id;
            if (vidId == null) continue;
            foundIds.add(vidId);

            final oldItem = idToItem[vidId]!;
            final oldStatus = oldItem.youtubeStatus;

            final uploadStatus = video.status?.uploadStatus;
            final privacyStatus = video.status?.privacyStatus;

            String newStatus = '';
            if (uploadStatus == 'uploaded') {
              newStatus = '⏳ Yuklanmoqda';
            } else if (uploadStatus == 'processed') {
              if (privacyStatus == 'public') {
                newStatus = '✅ Ommaviy';
              } else if (privacyStatus == 'unlisted') {
                newStatus = '🔗 Havolali';
              } else {
                newStatus = '🔒 Shaxsiy';
              }
            } else if (uploadStatus == 'rejected' || uploadStatus == 'failed') {
              newStatus = '⛔ Rad etilgan';
            } else {
              newStatus = '🔒 Shaxsiy';
            }

            final updatedItem = oldItem.copyWith(
              youtubeStatus: newStatus,
              lastSynced: DateTime.now().toIso8601String(),
            );

            final changed = await DBHelper.instance
                .updateHistory(updatedItem, syncSnapshot: false);
            if (changed > 0) {
              changedCount++;
            }

            if (oldStatus.isNotEmpty && oldStatus != newStatus) {
              final notifBody = _statusNotifBody(newStatus);
              if (notifBody.isNotEmpty) {
                await NotificationService.showNotification(
                  id: updatedItem.id ?? 100,
                  title: updatedItem.videoName,
                  body: notifBody,
                  payload: 'history',
                );
              }
            }
          }
        }

        // Detect deleted videos (those in queried list but not returned by YouTube)
        for (var vidId in idsList) {
          if (!foundIds.contains(vidId)) {
            final oldItem = idToItem[vidId]!;
            final oldStatus = oldItem.youtubeStatus;
            const newStatus = '❌ O\'chirilgan';

            final updatedItem = oldItem.copyWith(
              youtubeStatus: newStatus,
              lastSynced: DateTime.now().toIso8601String(),
            );

            final changed = await DBHelper.instance
                .updateHistory(updatedItem, syncSnapshot: false);
            if (changed > 0) {
              changedCount++;
            }

            if (oldStatus.isNotEmpty && oldStatus != newStatus) {
              await NotificationService.showNotification(
                id: updatedItem.id ?? 100,
                title: updatedItem.videoName,
                body: 'YouTube\'dan o\'chirildi ❌',
                payload: 'history',
              );
            }
          }
        }
      }
      if (changedCount > 0) {
        await DBHelper.instance.refreshHistorySnapshot();
      }
      return changedCount;
    } catch (e) {
      secureLog("YouTube status sync failed: $e");
      return -1;
    }
  }

  static String _statusNotifBody(String status) {
    switch (status) {
      case '✅ Ommaviy':
        return 'Ommaviy holatga o\'tdi ✅';
      case '⏳ Yuklanmoqda':
        return 'YouTube\'da qayta ishlanmoqda ⏳';
      case '⛔ Rad etilgan':
        return 'YouTube tomonidan rad etildi ⛔';
      case '🔒 Shaxsiy':
        return 'Shaxsiy rejimga o\'tkazildi 🔒';
      case '🔗 Havolali':
        return 'Havolali rejimga o\'zgartirildi 🔗';
      default:
        return '';
    }
  }
}
