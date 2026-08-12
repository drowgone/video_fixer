import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'video_editor_models.dart';

class TextEditPanel extends StatelessWidget {
  final TextLayer text;
  final VoidCallback onDelete;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onFontChanged;
  final ValueChanged<Color> onColorChanged;
  final List<String> fonts;

  const TextEditPanel({
    super.key,
    required this.text,
    required this.onDelete,
    required this.onChanged,
    required this.onFontChanged,
    required this.onColorChanged,
    required this.fonts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.text_fields, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text('Matnni tahrirlash', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: onDelete,
                tooltip: 'O\'chirish',
              ),
              IconButton(
                icon: const Icon(Icons.check, color: Colors.greenAccent),
                onPressed: () {
                  // Deselect
                  onColorChanged(text.textColor);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(border: InputBorder.none, hintText: 'Matnni yozing...'),
              controller: TextEditingController(text: text.text)
                ..selection = TextSelection.fromPosition(TextPosition(offset: text.text.length)),
              onChanged: onChanged,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: fonts.length,
              itemBuilder: (context, index) {
                final font = fonts[index];
                final isSelected = text.fontFamily == font;
                return GestureDetector(
                  onTap: () => onFontChanged(font),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFF0000) : Colors.black38,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? Colors.redAccent : Colors.white12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      font,
                      style: GoogleFonts.getFont(font, textStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AudioEditPanel extends StatelessWidget {
  final AudioLayer audio;
  final VoidCallback onDelete;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<bool> onVocalToggle;

  const AudioEditPanel({
    super.key,
    required this.audio,
    required this.onDelete,
    required this.onVolumeChanged,
    required this.onVocalToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.music_note, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  audio.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: onDelete,
                tooltip: 'O\'chirish',
              ),
              IconButton(
                icon: const Icon(Icons.check, color: Colors.greenAccent),
                onPressed: () {
                  onVolumeChanged(audio.volume);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Hajmi:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: audio.volume,
                  min: 0.0,
                  max: 2.0,
                  activeColor: Colors.green,
                  onChanged: onVolumeChanged,
                ),
              ),
              Text('${(audio.volume * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Vokalni o\'chirish (AI):', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Switch(
                value: audio.isVocalRemoved,
                activeThumbColor: Colors.greenAccent,
                onChanged: onVocalToggle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StickerEditPanel extends StatelessWidget {
  final StickerLayer sticker;
  final VoidCallback onDelete;
  final ValueChanged<double> onScaleChanged;
  final ValueChanged<double> onRotationChanged;

  const StickerEditPanel({
    super.key,
    required this.sticker,
    required this.onDelete,
    required this.onScaleChanged,
    required this.onRotationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_emotions, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Sticker: ${sticker.emoji}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: onDelete,
                tooltip: 'O\'chirish',
              ),
              IconButton(
                icon: const Icon(Icons.check, color: Colors.greenAccent),
                onPressed: () {
                  onScaleChanged(sticker.scale);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('O\'lchami:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: sticker.scale,
                  min: 0.2,
                  max: 3.0,
                  activeColor: Colors.orange,
                  onChanged: onScaleChanged,
                ),
              ),
              Text('${(sticker.scale * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Burish:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: sticker.rotation,
                  min: -3.14,
                  max: 3.14,
                  activeColor: Colors.orange,
                  onChanged: onRotationChanged,
                ),
              ),
              Text('${(sticker.rotation * 180 / 3.14).toInt()}°', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
