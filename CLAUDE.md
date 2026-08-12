# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**VideoFixer** is a Flutter Android app (`video_fixer/`) that fixes audio format issues in videos for YouTube compliance, converts horizontal videos to Shorts format (9:16), and uploads them directly to YouTube via the Data API v3.

The app is Android-only (no iOS targets). UI text is in Uzbek.

## Common Commands

All commands are run from within `video_fixer/`:

```bash
# Run on connected Android device
flutter run

# Build release APK
flutter build apk --release

# Analyze for lint errors
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Regenerate launcher icons and splash screen
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Architecture

The app uses the **Provider** pattern for state management with two providers registered at root:

- `SettingsProvider` — manages YouTube accounts (stored in `flutter_secure_storage`) and per-channel upload defaults (tags, description, title template, privacy, category, language, location).
- `VideoProcessingProvider` — drives the entire video processing pipeline. Holds `ProcessState` enum (`idle → picking → processing → uploading → done/error`) and all transient processing state. This is the central coordinator between UI and services.

### Navigation

`SplashScreen` → `MainTabScreen` (3-tab bottom nav: Home / History / Settings). `MainTabScreen.onSwitchTab` is a static callback used to programmatically switch tabs from anywhere (e.g. snackbar action after processing completes).

### Processing Pipeline (`VideoProcessingProvider.startProcessing`)

1. `FFmpegRunner.probeVideo` — uses FFprobe to inspect codec, resolution, fps, bitrate, channels, sample rate.
2. Compliance checks determine which transcoding branches to take:
   - **Normal mode**: always re-encodes audio to AAC 44100 Hz stereo 128 kbps; copies video stream.
   - **Shorts mode**: additionally enforces 1080×1920 resolution, 30fps, H.264 video. Horizontal videos are letterboxed (blur background) or cropped depending on `shortsStyle`. Falls back from `h264_mediacodec` to `libx264` on Android if hardware encoding fails.
3. All FFmpeg work writes to a secure temp path first, then copies to the public output directory (`/storage/emulated/0/Download/VideoFixer/` with fallback to app external storage).
4. On success, a thumbnail is extracted and a `HistoryItem` is persisted via `DBHelper`.

### Services

| File | Role |
|---|---|
| `ffmpeg_runner.dart` | Static wrapper around `ffmpeg_kit_flutter_new`. Serializes concurrent calls with a mutex queue. Exposes `probeVideo`, `execute`, and compliance helpers. |
| `youtube_uploader.dart` | Handles Google Sign-In, YouTube channel listing, resumable upload via `googleapis`, background status sync (`syncYouTubeStatuses` runs via Workmanager every 15 min). |
| `db_helper.dart` | SQLite singleton via `sqflite` (version 2). Stores history with YouTube upload metadata. Also writes a JSON snapshot file (`.videofixer_history_v1.json`) to the VideoFixer output folder so history survives app reinstalls; `syncHistoryFromVideoFixerFolder` re-imports orphaned files on startup. |
| `settings_provider.dart` | All sensitive data (accounts, tokens) stored exclusively in `flutter_secure_storage`, never `SharedPreferences`. Per-channel settings keyed by `channelId`. |
| `security_service.dart` | Provides the shared `FlutterSecureStorage` instance, `secureLog` (only prints in debug builds), JWT expiry check, and secure HTTP client. |
| `notification_service.dart` | Local push notifications for processing-done and YouTube status-changed events. |
| `thumbnail_cache.dart` | In-memory LRU cache for video thumbnails shown in the history list. |

### Key Invariants

- **Never store tokens in SharedPreferences** — always use `SecurityService.storage` (`flutter_secure_storage`).
- **FFmpeg calls must go through `FFmpegRunner.execute`** — it enforces the mutex so only one FFmpeg session runs at a time.
- All FFmpeg work happens in temp paths; the final file is copied to the public output path only after success.
- The `secureLog` / `SecurityService.log` helpers are no-ops in release builds — use them instead of `print` or bare `debugPrint`.
- `DBHelper` is a singleton (`DBHelper.instance`); never instantiate it directly.

### Android Permissions

Declared in `android/app/src/main/AndroidManifest.xml`:
- `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO` (Android 13+)
- `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` (≤ Android 12)
- `MANAGE_EXTERNAL_STORAGE` (Android 11+)
- `POST_NOTIFICATIONS`
- `android:usesCleartextTraffic="false"` — all network traffic must be HTTPS.
- The activity declares an `android.intent.action.SEND` intent filter for `video/*` so the app can receive shared videos from the system share sheet.

### Google OAuth Setup

The app uses `google_sign_in` with scopes `youtubeUploadScope` and `youtubeReadonlyScope`. For a new build environment you must:
1. Register the app in Google Cloud Console and add the debug/release SHA-1 fingerprints.
2. Download `google-services.json` and place it at `android/app/google-services.json`.
3. The OAuth client ID is embedded in `google-services.json`; no manual string configuration is needed in Dart code.
