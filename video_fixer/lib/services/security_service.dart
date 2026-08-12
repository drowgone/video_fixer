import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/io_client.dart';

class SecurityService {
  // 1. flutter_secure_storage — barcha tokens
  // HECH QACHON SharedPreferences da token saqlanmasin!
  static const storage = FlutterSecureStorage();

  // Release da log chiqmasin
  static void log(String message) {
    assert(() {
      debugPrint(message);
      return true;
    }());
  }

  // Keep platform TLS verification enabled.
  static HttpClient getSecureClient() {
    return HttpClient();
  }

  // HTTPClient wrapper with IOClient for high security connections
  static IOClient getSecureIOClient() {
    return IOClient(getSecureClient());
  }

  // Token muddatini doim tekshirish (JWT decoder)
  static bool isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return true;
      
      // Normalize base64Url encoding
      String normalizedSource = base64Url.normalize(parts[1]);
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(normalizedSource))
      );
      
      final exp = payload['exp'] as int?;
      if (exp == null) return false;
      
      return DateTime.now().millisecondsSinceEpoch / 1000 > exp;
    } catch (_) {
      // Agar JWT formati bo'lmasa, eskirgan deb hisoblaymiz yoki xavfsiz holatga o'tamiz
      return true;
    }
  }

  // Token yangilash va uning xavfsizligini ta'minlash
  static Future<String> getValidToken({
    required String key,
    required Future<String> Function() onRefresh,
  }) async {
    String? token = await storage.read(key: key);
    if (token == null || isTokenExpired(token)) {
      token = await onRefresh(); // Yangi token olish
      await storage.write(key: key, value: token);
    }
    
    final activeToken = token;
    // API tokenlarni xotirada ham himoyalash
    // Token ishlatilgandan keyin o'zgaruvchidan o'chirilsin
    token = null; 
    
    return activeToken;
  }
}

// Global secure log helper
void secureLog(String message) {
  assert(() {
    debugPrint(message);
    return true;
  }());
}
