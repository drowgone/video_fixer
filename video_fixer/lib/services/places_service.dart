import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'security_service.dart';

class PlacePrediction {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullText;

  const PlacePrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
  });
}

class PlacesService {
  // API key is supplied at build time via --dart-define=PLACES_API_KEY=<key>.
  // TODO: Enable "Places API" in Google Cloud Console (same project as google-services.json),
  //       then run the app with:
  //         flutter run --dart-define=PLACES_API_KEY=YOUR_KEY_HERE
  //       For a release build:
  //         flutter build apk --release --dart-define=PLACES_API_KEY=YOUR_KEY_HERE
  static const _apiKey =
      String.fromEnvironment('PLACES_API_KEY', defaultValue: '');

  static bool get isConfigured => _apiKey.isNotEmpty;

  static Future<List<PlacePrediction>> searchPlaces(String query) async {
    if (query.trim().length < 2 || !isConfigured) return const [];
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': query.trim(),
          'types': '(cities)',
          'language': 'uz',
          'key': _apiKey,
        },
      );

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return const [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';
      if (status != 'OK') {
        secureLog('PlacesService status: $status');
        return const [];
      }

      final predictions = data['predictions'] as List<dynamic>? ?? [];
      return predictions.take(5).map((p) {
        final structured =
            p['structured_formatting'] as Map<String, dynamic>?;
        final mainText =
            (structured?['main_text'] as String?) ??
            (p['description'] as String? ?? '');
        final secondaryText =
            (structured?['secondary_text'] as String?) ?? '';
        final fullText =
            secondaryText.isEmpty ? mainText : '$mainText, $secondaryText';
        return PlacePrediction(
          placeId: (p['place_id'] as String?) ?? '',
          mainText: mainText,
          secondaryText: secondaryText,
          fullText: fullText,
        );
      }).toList();
    } catch (e) {
      secureLog('PlacesService.searchPlaces error: $e');
      return const [];
    }
  }
}
