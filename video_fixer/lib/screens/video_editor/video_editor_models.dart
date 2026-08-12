import 'package:flutter/material.dart';


class TextLayer {
  final String id;
  String text;
  Offset position; // relative coordinates (0.0 to 1.0)
  double fontSize;
  Color textColor;
  Color bgColor;
  bool hasBg;
  bool hasShadow;
  Color shadowColor;
  String fontFamily; // e.g., 'Roboto', 'Poppins', 'Pacifico'
  String fontStyle; // 'normal', 'bold', 'italic'
  double startTime;
  double duration;
  double scale;
  double rotation; // radians
  String animation; // 'Fade', 'Slide', 'Bounce', 'Typewriter', 'Zoom'

  TextLayer({
    required this.id,
    required this.text,
    required this.position,
    this.fontSize = 22.0,
    this.textColor = Colors.white,
    this.bgColor = Colors.black54,
    this.hasBg = false,
    this.hasShadow = true,
    this.shadowColor = Colors.black45,
    this.fontFamily = 'Roboto',
    this.fontStyle = 'normal',
    this.startTime = 0.0,
    this.duration = 5.0,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.animation = 'Fade',
  });

  TextLayer copyWith({
    String? text,
    Offset? position,
    double? fontSize,
    Color? textColor,
    Color? bgColor,
    bool? hasBg,
    bool? hasShadow,
    Color? shadowColor,
    String? fontFamily,
    String? fontStyle,
    double? startTime,
    double? duration,
    double? scale,
    double? rotation,
    String? animation,
  }) {
    return TextLayer(
      id: id,
      text: text ?? this.text,
      position: position ?? this.position,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      bgColor: bgColor ?? this.bgColor,
      hasBg: hasBg ?? this.hasBg,
      hasShadow: hasShadow ?? this.hasShadow,
      shadowColor: shadowColor ?? this.shadowColor,
      fontFamily: fontFamily ?? this.fontFamily,
      fontStyle: fontStyle ?? this.fontStyle,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      animation: animation ?? this.animation,
    );
  }
}

class StickerLayer {
  final String id;
  final String emoji;
  Offset position;
  double startTime;
  double duration;
  double scale;
  double rotation; // radians

  StickerLayer({
    required this.id,
    required this.emoji,
    required this.position,
    this.startTime = 0.0,
    this.duration = 5.0,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  StickerLayer copyWith({
    String? emoji,
    Offset? position,
    double? startTime,
    double? duration,
    double? scale,
    double? rotation,
  }) {
    return StickerLayer(
      id: id,
      emoji: emoji ?? this.emoji,
      position: position ?? this.position,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }
}

class AudioLayer {
  final String id;
  final String path;
  final String title;
  double volume; // 0.0 to 2.0
  double startTime;
  double trimStart;
  double duration;
  double fadeIn; // seconds
  double fadeOut; // seconds
  bool loop;
  bool isVocalRemoved;

  AudioLayer({
    required this.id,
    required this.path,
    required this.title,
    this.volume = 1.0,
    this.startTime = 0.0,
    this.trimStart = 0.0,
    this.duration = 10.0,
    this.fadeIn = 0.0,
    this.fadeOut = 0.0,
    this.loop = false,
    this.isVocalRemoved = false,
  });

  AudioLayer copyWith({
    String? path,
    String? title,
    double? volume,
    double? startTime,
    double? trimStart,
    double? duration,
    double? fadeIn,
    double? fadeOut,
    bool? loop,
    bool? isVocalRemoved,
  }) {
    return AudioLayer(
      id: id,
      path: path ?? this.path,
      title: title ?? this.title,
      volume: volume ?? this.volume,
      startTime: startTime ?? this.startTime,
      trimStart: trimStart ?? this.trimStart,
      duration: duration ?? this.duration,
      fadeIn: fadeIn ?? this.fadeIn,
      fadeOut: fadeOut ?? this.fadeOut,
      loop: loop ?? this.loop,
      isVocalRemoved: isVocalRemoved ?? this.isVocalRemoved,
    );
  }
}

class VideoLayer {
  final double startCut;
  final double endCut;
  final double speed;
  final double originalVolume; // 0.0 to 1.0 (original sound mute state)
  final List<TextLayer> texts;
  final List<StickerLayer> stickers;
  final List<AudioLayer> audios;

  VideoLayer({
    this.startCut = 0.0,
    this.endCut = 0.0,
    this.speed = 1.0,
    this.originalVolume = 1.0,
    required this.texts,
    required this.stickers,
    required this.audios,
  });

  VideoLayer copyWith({
    double? startCut,
    double? endCut,
    double? speed,
    double? originalVolume,
    List<TextLayer>? texts,
    List<StickerLayer>? stickers,
    List<AudioLayer>? audios,
  }) {
    return VideoLayer(
      startCut: startCut ?? this.startCut,
      endCut: endCut ?? this.endCut,
      speed: speed ?? this.speed,
      originalVolume: originalVolume ?? this.originalVolume,
      texts: texts != null ? List.from(texts) : List.from(this.texts),
      stickers: stickers != null ? List.from(stickers) : List.from(this.stickers),
      audios: audios != null ? List.from(audios) : List.from(this.audios),
    );
  }
}

final List<Color> pickerColors = [
  Colors.white,
  Colors.black,
  Colors.red,
  Colors.pink,
  Colors.purple,
  Colors.deepPurple,
  Colors.indigo,
  Colors.blue,
  Colors.lightBlue,
  Colors.cyan,
  Colors.teal,
  Colors.green,
  Colors.lightGreen,
  Colors.lime,
  Colors.yellow,
  Colors.amber,
  Colors.orange,
  Colors.deepOrange,
  Colors.brown,
  Colors.grey,
  Colors.blueGrey,
];

// --- VIDEO EDITOR SCREEN ---


enum TimelineItemType { video, audio, text, sticker }

class TimelineItem {
  final String id;
  final TimelineItemType type;
  double startSeconds;
  double durationSeconds;
  final Color color;
  final String label;
  bool isSelected;

  TimelineItem({
    required this.id,
    required this.type,
    required this.startSeconds,
    required this.durationSeconds,
    required this.color,
    required this.label,
    this.isSelected = false,
  });
}

class TimelineState {
  List<TimelineItem> items;
  double pixelsPerSecond; // zoom
  double playheadPosition;
  TimelineItem? selectedItem;

  TimelineState({
    required this.items,
    required this.pixelsPerSecond,
    required this.playheadPosition,
    this.selectedItem,
  });
}
