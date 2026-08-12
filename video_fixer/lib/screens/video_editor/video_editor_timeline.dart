import 'dart:typed_data';
import 'package:video_fixer/services/thumbnail_cache.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'video_editor_models.dart';

class AudioWaveformPainter extends CustomPainter {
  final Color color;

  AudioWaveformPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final double width = size.width;
    final double height = size.height;
    final int bars = (width / 5).floor();

    for (int i = 0; i < bars; i++) {
      final double x = i * 5.0 + 2.5;
      final double barHeight = (math.sin(i * 0.35) * 0.4 + 0.5) * height * 0.8;
      final double y1 = (height - barHeight) / 2;
      final double y2 = y1 + barHeight;
      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- TIMELINE ROW WIDGET ---

class TimelineRow extends StatelessWidget {
  final String type;
  final TimelineItem? item;
  final List<TimelineItem>? items;
  final String? videoPath;
  final double pixelsPerSecond;
  final double maxDuration;
  final ValueChanged<TimelineItem> onSelect;
  final Function(TimelineItem, double, double) onUpdate;

  const TimelineRow({
    super.key,
    required this.type,
    this.item,
    this.items,
    this.videoPath,
    required this.pixelsPerSecond,
    required this.maxDuration,
    required this.onSelect,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final List<TimelineItem> list = [];
    if (item != null) list.add(item!);
    if (items != null) list.addAll(items!);

    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: list.map((item) {
          final isSelected = item.isSelected;
          final double left = item.startSeconds * pixelsPerSecond;
          final double width = item.durationSeconds * pixelsPerSecond;

          return Positioned(
            left: left,
            width: width.clamp(30.0, double.infinity),
            top: 6,
            bottom: 6,
            child: GestureDetector(
              onTap: () => onSelect(item),
              onHorizontalDragUpdate: (details) {
                double newStart = item.startSeconds + details.delta.dx / pixelsPerSecond;
                newStart = newStart.clamp(0.0, maxDuration - item.durationSeconds);
                onUpdate(item, newStart, item.durationSeconds);
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Main Item block
                  Container(
                    decoration: BoxDecoration(
                      color: isSelected ? item.color : item.color.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                    ),
                    child: item.type == TimelineItemType.video && videoPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              children: List.generate(
                                (item.durationSeconds / 2.0).ceil(),
                                (idx) {
                                  const double stepSec = 2.0;
                                  final int sec = (item.startSeconds + idx * stepSec).toInt();
                                  final double remainingSec = item.durationSeconds - (idx * stepSec);
                                  final double thumbWidth = (remainingSec >= stepSec ? stepSec : remainingSec) * pixelsPerSecond;
                                  return TimelineVideoThumb(
                                    videoPath: videoPath!,
                                    seconds: sec,
                                    width: thumbWidth,
                                  );
                                },
                              ),
                            ),
                          )
                        : Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14.0),
                              child: Text(
                                item.label,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                  ),

                  // Left edge resize handle
                  if (item.type != TimelineItemType.video)
                    Positioned(
                      left: -4,
                      top: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          double delta = details.delta.dx / pixelsPerSecond;
                          double newStart = item.startSeconds + delta;
                          double newDuration = item.durationSeconds - delta;
                          if (newStart >= 0 && newDuration >= 1.0) {
                            onUpdate(item, newStart, newDuration);
                          }
                        },
                        child: const _ResizeHandle(),
                      ),
                    ),

                  // Right edge resize handle
                  if (item.type != TimelineItemType.video)
                    Positioned(
                      right: -4,
                      top: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          double delta = details.delta.dx / pixelsPerSecond;
                          double newDuration = item.durationSeconds + delta;
                          if (newDuration >= 1.0) {
                            onUpdate(item, item.startSeconds, newDuration);
                          }
                        },
                        child: const _ResizeHandle(),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class TimelineVideoThumb extends StatelessWidget {
  final String videoPath;
  final int seconds;
  final double width;

  const TimelineVideoThumb({
    super.key,
    required this.videoPath,
    required this.seconds,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: ThumbnailCache.get(videoPath, seconds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            width: width,
            height: 48,
            fit: BoxFit.cover,
            cacheWidth: 100,
            cacheHeight: 56,
          );
        }
        return Container(
          width: width,
          height: 48,
          color: Colors.white.withValues(alpha: 0.05),
          child: const Center(
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1, color: Colors.white24),
            ),
          ),
        );
      },
    );
  }
}

// --- RESIZE HANDLE ---

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: const Center(
        child: Icon(Icons.drag_handle, size: 8, color: Colors.black87),
      ),
    );
  }
}

// --- PLAYHEAD POINTER ---

class PlayheadWidget extends StatelessWidget {
  final double position;
  final double height;

  const PlayheadWidget({super.key, required this.position, required this.height});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position,
      top: 0,
      bottom: 0,
      child: Container(
        width: 2,
        color: Colors.redAccent,
        child: Column(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- EDIT PANEL WIDGETS ---
