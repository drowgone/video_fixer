import 'package:flutter/material.dart';
import '../services/video_processing_provider.dart';
import '../services/ffmpeg_runner.dart';

/// Shows a bottom sheet asking what to do with a horizontal video.
/// Returns the chosen [ProcessMode] or null if cancelled.
Future<ProcessMode?> showOrientationChoiceSheet(
  BuildContext context,
  VideoFormatInfo info,
) {
  return showModalBottomSheet<ProcessMode>(
    context: context,
    backgroundColor: const Color(0xFF1A1A1A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _OrientationChoiceSheet(info: info),
  );
}

class _OrientationChoiceSheet extends StatelessWidget {
  final VideoFormatInfo info;
  const _OrientationChoiceSheet({required this.info});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Gorizontal video aniqlandi',
              style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '${info.width}×${info.height} • ${info.fps.toStringAsFixed(0)}fps • ${info.videoCodec.toUpperCase()}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 20),
            const Text(
              'Qanday qayta ishlash kerak?',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 14),

            // Shorts option
            _OptionTile(
              icon: Icons.bolt,
              iconColor: Colors.amber,
              title: 'Shorts (9:16) ga aylantirish',
              subtitle: 'Gorizontal videoni vertikal Shorts formatiga o\'giradi',
              onTap: () => Navigator.pop(context, ProcessMode.horizontalToShorts),
            ),
            const SizedBox(height: 10),

            // Direct upload option
            _OptionTile(
              icon: Icons.cloud_upload_outlined,
              iconColor: const Color(0xFF1DB954),
              title: 'Asl formatda (16:9) yuklash',
              subtitle: 'Faqat audio tuzatadi, video o\'lchamini saqlab qoladi',
              onTap: () =>
                  Navigator.pop(context, ProcessMode.horizontalDirectUpload),
            ),
            const SizedBox(height: 12),

            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Bekor qilish',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2A2A2A),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12, height: 1.3)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
