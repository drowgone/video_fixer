import 'package:flutter/material.dart';

class HashtagHighlightController extends TextEditingController {
  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final List<InlineSpan> children = [];
    final RegExp hashRegExp = RegExp(r'#\S+');

    text.splitMapJoin(
      hashRegExp,
      onMatch: (Match match) {
        final matchText = match[0]!;
        // Valid hashtag: # followed by alphanumeric, Cyrillic, and underscores only
        final isCorrect = RegExp(r'^#[a-zA-Z0-9_\u0400-\u04FF]+$').hasMatch(matchText);
        if (isCorrect) {
          children.add(TextSpan(
            text: matchText,
            style: style?.copyWith(color: Colors.blueAccent, fontWeight: FontWeight.bold) ??
                const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
          ));
        } else {
          children.add(TextSpan(
            text: matchText,
            style: style?.copyWith(
              color: Colors.redAccent, 
              decoration: TextDecoration.underline,
              decorationColor: Colors.redAccent,
            ) ?? const TextStyle(
              color: Colors.redAccent, 
              decoration: TextDecoration.underline,
              decorationColor: Colors.redAccent,
            ),
          ));
        }
        return '';
      },
      onNonMatch: (String nonMatch) {
        children.add(TextSpan(text: nonMatch, style: style));
        return '';
      },
    );

    return TextSpan(style: style, children: children);
  }
}

class YouTubeInputValidator {
  static String deduplicateDescription(String text) {
    if (text.isEmpty) return text;
    
    final List<String> lines = text.split('\n');
    final List<String> cleanLines = [];
    final Set<String> uniqueLines = {};
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        cleanLines.add('');
        continue;
      }
      
      if (!uniqueLines.contains(trimmed)) {
        uniqueLines.add(trimmed);
        cleanLines.add(line);
      }
    }
    
    String processed = cleanLines.join('\n');
    
    final RegExp hashtagRegex = RegExp(r'#\S+');
    final Set<String> seenHashtags = {};
    
    processed = processed.replaceAllMapped(hashtagRegex, (match) {
      final tag = match.group(0)!;
      final lowerTag = tag.toLowerCase();
      if (seenHashtags.contains(lowerTag)) {
        return '';
      } else {
        seenHashtags.add(lowerTag);
        return tag;
      }
    });
    
    processed = processed.replaceAll(RegExp(r' +'), ' ');
    processed = processed.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    return processed.trim();
  }

  static Map<String, dynamic> validateTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return {'valid': false, 'warning': false, 'message': 'Sarlavha bo\'sh bo\'lmasligi kerak'};
    }
    if (title.length > 100) {
      return {'valid': false, 'warning': false, 'message': 'Sarlavha 100 belgidan oshmasligi kerak'};
    }
    
    final prohibited = ['<', '>'];
    for (final char in prohibited) {
      if (title.contains(char)) {
        return {'valid': false, 'warning': false, 'message': 'Sarlavhada "$char" belgisi taqiqlangan'};
      }
    }

    // Word repetition check (>3 times)
    final words = trimmed.toLowerCase().split(RegExp(r'\s+'));
    final counts = <String, int>{};
    for (final word in words) {
      final cleanWord = word.replaceAll(RegExp(r'[.,\/#!$%\^&\*;:{}=\-_`~()?]'), '');
      if (cleanWord.isEmpty) continue;
      counts[cleanWord] = (counts[cleanWord] ?? 0) + 1;
      if (counts[cleanWord]! > 3) {
        return {'valid': false, 'warning': false, 'message': 'Spam taqiqi: "$cleanWord" so\'zi 3 martadan ortiq takrorlandi'};
      }
    }

    if (title.length >= 80) {
      return {'valid': true, 'warning': true, 'message': '⚠️ Limitga yaqinlashmoqda'};
    }

    return {'valid': true, 'warning': false, 'message': '✅ To\'g\'ri'};
  }

  static Map<String, dynamic> validateDescription(String desc) {
    if (desc.length > 5000) {
      return {'valid': false, 'warning': false, 'message': 'Tavsif 5000 belgidan oshmasligi kerak'};
    }

    final prohibited = ['<', '>'];
    for (final char in prohibited) {
      if (desc.contains(char)) {
        return {'valid': false, 'warning': false, 'message': 'Tavsifda "$char" belgisi taqiqlangan'};
      }
    }

    final RegExp hashReg = RegExp(r'#\S+');
    final matches = hashReg.allMatches(desc).map((m) => m.group(0)!).toList();

    final standaloneHashCount = RegExp(r'#(?=\s|$)').allMatches(desc).length;
    if (standaloneHashCount > 0) {
      return {'valid': false, 'warning': false, 'message': 'Noto\'g\'ri hashtag formati: Bo\'sh "#" belgisi'};
    }

    final invalidHashtags = <String>[];
    final uniqueHashtags = <String>{};
    final duplicateHashtags = <String>[];

    for (final tag in matches) {
      final isCorrect = RegExp(r'^#[a-zA-Z0-9_\u0400-\u04FF]+$').hasMatch(tag);
      if (!isCorrect) {
        invalidHashtags.add(tag);
      }
      
      final normalized = tag.toLowerCase();
      if (uniqueHashtags.contains(normalized)) {
        duplicateHashtags.add(tag);
      } else {
        uniqueHashtags.add(normalized);
      }
    }

    if (invalidHashtags.isNotEmpty) {
      return {'valid': false, 'warning': false, 'message': 'Hashtag formati xato (faqat harf, raqam, tagchiziq): ${invalidHashtags.first}'};
    }

    if (duplicateHashtags.isNotEmpty) {
      return {'valid': false, 'warning': false, 'message': 'Takroriy hashtaglar taqiqlangan: ${duplicateHashtags.first}'};
    }

    if (matches.length > 30) {
      return {
        'valid': false,
        'warning': false,
        'message': '❌ 30 dan ortiq hashtag taqiqlangan. Iltimos kamaytirib qayta urinib ko\'ring.'
      };
    }

    if (matches.length > 15) {
      return {
        'valid': true,
        'warning': true,
        'message': '⚠️ Diqqat: 15 dan ko\'p hashtag. Yuklashda tasodifiy 5 tasi tanlab yuboriladi!'
      };
    }

    return {'valid': true, 'warning': false, 'message': '✅ To\'g\'ri'};
  }

  static Map<String, dynamic> validateTags(List<String> tags) {
    final combinedLength = tags.join(',').length;
    if (combinedLength > 500) {
      return {'valid': false, 'warning': false, 'message': 'Teglar umumiy uzunligi 500 belgidan oshmasligi kerak'};
    }

    final prohibited = ['<', '>'];
    for (final tag in tags) {
      for (final char in prohibited) {
        if (tag.contains(char)) {
          return {'valid': false, 'warning': false, 'message': 'Tegda "$char" belgisi taqiqlangan: $tag'};
        }
      }
    }

    if (combinedLength >= 400) {
      return {
        'valid': true,
        'warning': true,
        'message': '⚠️ Teglar limitiga yaqinlashmoqda ($combinedLength/500)',
      };
    }

    return {'valid': true, 'warning': false, 'message': '✅ To\'g\'ri'};
  }
}

class YouTubeValidationFeedback extends StatelessWidget {
  final Map<String, dynamic> validation;
  final int currentLength;
  final int maxLength;

  const YouTubeValidationFeedback({
    super.key,
    required this.validation,
    required this.currentLength,
    required this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    final bool isValid = validation['valid'] ?? false;
    final bool isWarning = validation['warning'] ?? false;
    final String message = validation['message'] ?? '';

    Color color = const Color(0xFF1DB954); // green
    IconData icon = Icons.check_circle_outline;

    if (!isValid) {
      color = Colors.redAccent;
      icon = Icons.cancel_outlined;
    } else if (isWarning) {
      color = Colors.amberAccent;
      icon = Icons.warning_amber_outlined;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$currentLength/$maxLength',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
