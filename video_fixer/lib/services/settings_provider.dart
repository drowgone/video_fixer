import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/youtube_account.dart';
import 'security_service.dart';

class SettingsProvider extends ChangeNotifier {
  final _storage = SecurityService.storage;
  final String _storageKey = 'youtube_accounts';

  List<YouTubeAccount> _accounts = [];
  List<YouTubeAccount> get accounts => _accounts;

  String _defaultTags = '';
  String get defaultTags => _defaultTags;

  String _defaultDescription = '';
  String get defaultDescription => _defaultDescription;

  String _defaultHashtags = '';
  String get defaultHashtags => _defaultHashtags;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  // Speech-to-Text (STT) Settings
  bool _sttEnabled = false;
  bool get sttEnabled => _sttEnabled;

  String _sttApiKey = '';
  String get sttApiKey => _sttApiKey;

  String _sttEndpoint = 'https://api.openai.com/v1/audio/transcriptions';
  String get sttEndpoint => _sttEndpoint;

  SettingsProvider() {
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _storage.read(key: _storageKey);
      if (data != null) {
        final List<dynamic> jsonList = json.decode(data);
        _accounts = jsonList.map((j) => YouTubeAccount.fromJson(j)).toList();
      }

      _defaultTags = await _storage.read(key: 'default_tags') ?? '';
      _defaultDescription = await _storage.read(key: 'default_description') ?? '';
      _defaultHashtags = await _storage.read(key: 'default_hashtags') ?? '';

      _sttEnabled = (await _storage.read(key: 'stt_enabled') ?? 'false') == 'true';
      _sttApiKey = await _storage.read(key: 'stt_api_key') ?? '';
      _sttEndpoint = await _storage.read(key: 'stt_endpoint') ?? 'https://api.openai.com/v1/audio/transcriptions';

    } catch (e) {
      secureLog('Error loading settings: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveSTTSettings({
    required bool enabled,
    required String apiKey,
    required String endpoint,
  }) async {
    _sttEnabled = enabled;
    _sttApiKey = apiKey;
    _sttEndpoint = endpoint;

    await _storage.write(key: 'stt_enabled', value: enabled.toString());
    await _storage.write(key: 'stt_api_key', value: apiKey);
    await _storage.write(key: 'stt_endpoint', value: endpoint);

    notifyListeners();
  }

  Future<void> _saveAccounts() async {
    final List<String> jsonList = _accounts.map((a) => a.toJson()).toList();
    await _storage.write(key: _storageKey, value: json.encode(jsonList));
    notifyListeners();
  }

  Future<void> saveDefaultSettings({
    required String tags,
    required String description,
    required String hashtags,
  }) async {
    _defaultTags = tags;
    _defaultDescription = description;
    _defaultHashtags = hashtags;

    await _storage.write(key: 'default_tags', value: tags);
    await _storage.write(key: 'default_description', value: description);
    await _storage.write(key: 'default_hashtags', value: hashtags);
    
    notifyListeners();
  }

  Future<void> addAccount(YouTubeAccount account) async {
    _accounts.add(account);
    await _saveAccounts();
  }

  Future<void> updateAccount(YouTubeAccount updatedAccount) async {
    final index = _accounts.indexWhere((a) => a.id == updatedAccount.id);
    if (index != -1) {
      _accounts[index] = updatedAccount;
      await _saveAccounts();
    }
  }

  Future<void> deleteAccount(String id) async {
    _accounts.removeWhere((a) => a.id == id);
    await _saveAccounts();
  }

  Future<void> toggleAccountActive(String id, bool isActive) async {
    final index = _accounts.indexWhere((a) => a.id == id);
    if (index != -1) {
      _accounts[index] = _accounts[index].copyWith(isActive: isActive);
      await _saveAccounts();
    }
  }

  Future<Map<String, String>> getChannelSettings(String channelId) async {
    final tags = await _storage.read(key: 'tags_$channelId') ?? '';
    final description = await _storage.read(key: 'desc_$channelId') ?? '';
    final hashtags = await _storage.read(key: 'hash_$channelId') ?? '';
    final titleTemplate = await _storage.read(key: 'title_$channelId') ?? '';
    final privacy = await _storage.read(key: 'privacy_$channelId') ?? 'public';
    final category = await _storage.read(key: 'cat_$channelId') ?? '22';
    final audience = await _storage.read(key: 'audience_$channelId') ?? 'false';
    final language = await _storage.read(key: 'lang_$channelId') ?? 'uz';
    final location = await _storage.read(key: 'loc_$channelId') ?? '';
    
    return {
      'tags': tags,
      'description': description,
      'hashtags': hashtags,
      'titleTemplate': titleTemplate,
      'privacy': privacy,
      'category': category,
      'audience': audience,
      'language': language,
      'location': location,
    };
  }

  Future<void> saveChannelSettings(String channelId, Map<String, String> settings) async {
    await _storage.write(key: 'tags_$channelId', value: settings['tags']);
    await _storage.write(key: 'desc_$channelId', value: settings['description']);
    await _storage.write(key: 'hash_$channelId', value: settings['hashtags']);
    await _storage.write(key: 'title_$channelId', value: settings['titleTemplate']);
    await _storage.write(key: 'privacy_$channelId', value: settings['privacy']);
    await _storage.write(key: 'cat_$channelId', value: settings['category']);
    await _storage.write(key: 'audience_$channelId', value: settings['audience']);
    await _storage.write(key: 'lang_$channelId', value: settings['language']);
    await _storage.write(key: 'loc_$channelId', value: settings['location']);
    notifyListeners();
  }

  Future<Map<String, dynamic>> loadDefaultUploadMetadata({
    required String filePath,
    required bool isShorts,
    required String channelId,
  }) async {
    final channelSettings = await getChannelSettings(channelId);
    
    // Title
    String titleText = '';
    final template = channelSettings['titleTemplate'] ?? '';
    if (template.isNotEmpty) {
      final basename = p.basenameWithoutExtension(filePath);
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      titleText = template
          .replaceAll('{filename}', basename)
          .replaceAll('{title}', basename)
          .replaceAll('{date}', dateStr)
          .replaceAll('{index}', '1');
    } else {
      titleText = p.basenameWithoutExtension(filePath);
    }
    
    // Description & Hashtags
    String finalDesc = channelSettings['description'] ?? '';
    finalDesc = finalDesc.isEmpty ? 'Uploaded via VideoFixer' : finalDesc;
    if (isShorts && !finalDesc.toLowerCase().contains('#shorts')) {
      finalDesc = '$finalDesc\n\n#Shorts';
    }
    
    // Tags
    final tagsStr = channelSettings['tags'] ?? '';
    List<String> tagsList = tagsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (isShorts && !tagsList.contains('shorts')) {
      tagsList.add('shorts');
    }
    
    return {
      'title': titleText,
      'description': finalDesc,
      'tags': tagsList,
      'privacy': channelSettings['privacy'] ?? 'unlisted',
      'category': channelSettings['category'] ?? '22',
      'audience': channelSettings['audience'] ?? 'false',
      'language': channelSettings['language'] ?? 'uz',
      'location': channelSettings['location'] ?? '',
    };
  }
}

