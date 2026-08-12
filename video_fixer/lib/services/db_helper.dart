import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/history_item.dart';
import 'security_service.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;
  static const String _historySnapshotFileName = '.videofixer_history_v1.json';
  static const int _historySnapshotVersion = 1;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('history.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE history (
  id $idType,
  videoName $textType,
  thumbnailPath $textType,
  filePath $textType,
  sizeBytes $intType,
  format $textType,
  date $textType,
  isUploaded $intType,
  uploadedChannel $textType,
  youtubeLink $textType,
  youtubeStatus TEXT NOT NULL DEFAULT "",
  lastSynced TEXT NOT NULL DEFAULT "",
  uploadStatus TEXT NOT NULL DEFAULT "not_uploaded",
  queueAddedAt TEXT NOT NULL DEFAULT "",
  uploadError TEXT NOT NULL DEFAULT ""
)
''');

    // Create indices to speed up queries and sorting
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_history_date ON history(date DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_history_format ON history(format)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_history_is_uploaded ON history(isUploaded)');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
            'ALTER TABLE history ADD COLUMN youtubeStatus TEXT NOT NULL DEFAULT ""');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE history ADD COLUMN lastSynced TEXT NOT NULL DEFAULT ""');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute(
            'ALTER TABLE history ADD COLUMN uploadStatus TEXT NOT NULL DEFAULT "not_uploaded"');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE history ADD COLUMN queueAddedAt TEXT NOT NULL DEFAULT ""');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE history ADD COLUMN uploadError TEXT NOT NULL DEFAULT ""');
      } catch (_) {}
    }
    // Always make sure indices exist during upgrade/migration
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_history_date ON history(date DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_history_format ON history(format)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_history_is_uploaded ON history(isUploaded)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_history_upload_status ON history(uploadStatus)');
  }

  Future<HistoryItem> insertHistory(HistoryItem item) async {
    try {
      final db = await instance.database;
      final id = await db.insert('history', item.toMap());
      await _writeHistorySnapshot(db);
      return item.copyWith(id: id);
    } catch (e) {
      secureLog('DBHelper.insertHistory error: $e');
      return item;
    }
  }

  Future<List<HistoryItem>> getAllHistory() async {
    final db = await instance.database;
    final result = await db.query('history', orderBy: 'date DESC');
    return result.map((json) => HistoryItem.fromMap(json)).toList();
  }

  Future<List<HistoryItem>> getHistoryPaged(
      {required int limit, required int offset}) async {
    final db = await instance.database;
    final result = await db.query(
      'history',
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
    return result.map((json) => HistoryItem.fromMap(json)).toList();
  }

  Future<int> updateHistory(HistoryItem item,
      {bool syncSnapshot = true}) async {
    try {
      final db = await instance.database;
      final changed = await db.update(
        'history',
        item.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );
      if (changed > 0 && syncSnapshot) {
        await _writeHistorySnapshot(db);
      }
      return changed;
    } catch (e) {
      secureLog('DBHelper.updateHistory error: $e');
      return 0;
    }
  }

  Future<int> deleteHistory(int id, {bool syncSnapshot = true}) async {
    try {
      final db = await instance.database;
      final deleted = await db.delete(
        'history',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (deleted > 0 && syncSnapshot) {
        await _writeHistorySnapshot(db);
      }
      return deleted;
    } catch (e) {
      secureLog('DBHelper.deleteHistory error: $e');
      return 0;
    }
  }

  Future<Directory> ensureVideoFixerDirectory() async {
    Directory dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download/VideoFixer');
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      } catch (_) {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          dir = Directory(join(extDir.path, 'VideoFixer'));
        } else {
          final docs = await getApplicationDocumentsDirectory();
          dir = Directory(join(docs.path, 'VideoFixer'));
        }
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }
    } else {
      final docs = await getApplicationDocumentsDirectory();
      dir = Directory(join(docs.path, 'VideoFixer'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
    return dir;
  }

  Future<int> syncHistoryFromVideoFixerFolder() async {
    final dir = await ensureVideoFixerDirectory();
    final db = await instance.database;
    final existing = await db.query('history');
    final existingByPath = <String, Map<String, dynamic>>{};
    for (final row in existing) {
      final rawPath = row['filePath'];
      if (rawPath is String && rawPath.isNotEmpty) {
        existingByPath[_normalizePath(rawPath)] = row;
      }
    }
    final snapshotIndex = await _loadHistorySnapshotIndex(dir);

    final entities =
        await dir.list(recursive: false, followLinks: false).toList();
    int inserted = 0;
    int repaired = 0;

    // First, repair existing DB items if snapshot has richer upload status.
    for (final row in existing) {
      final id = row['id'];
      final rawPath = row['filePath'];
      if (id is! int || rawPath is! String || rawPath.isEmpty) continue;

      final snap = _findSnapshotMatch(
        snapshotIndex,
        filePath: rawPath,
        videoName: (row['videoName'] as String?) ?? basename(rawPath),
        sizeBytes: _toInt(row['sizeBytes']),
      );
      if (snap == null) continue;

      final shouldUpdate =
          (_toInt(row['isUploaded']) == 0 && _asBool(snap['isUploaded'])) ||
              _preferSnapshotString(
                  dbValue: row['uploadedChannel'],
                  snapValue: snap['uploadedChannel']) ||
              _preferSnapshotString(
                  dbValue: row['youtubeLink'],
                  snapValue: snap['youtubeLink']) ||
              _preferSnapshotString(
                  dbValue: row['youtubeStatus'],
                  snapValue: snap['youtubeStatus']) ||
              _preferSnapshotString(
                  dbValue: row['lastSynced'], snapValue: snap['lastSynced']) ||
              _preferSnapshotString(
                  dbValue: row['thumbnailPath'],
                  snapValue: snap['thumbnailPath']);

      if (!shouldUpdate) continue;

      final updated = HistoryItem.fromMap(row).copyWith(
        isUploaded:
            _toInt(row['isUploaded']) == 1 ? true : _asBool(snap['isUploaded']),
        uploadedChannel:
            _pickString(row['uploadedChannel'], snap['uploadedChannel']),
        youtubeLink: _pickString(row['youtubeLink'], snap['youtubeLink']),
        youtubeStatus: _pickString(row['youtubeStatus'], snap['youtubeStatus']),
        lastSynced: _pickString(row['lastSynced'], snap['lastSynced']),
        thumbnailPath: _pickString(row['thumbnailPath'], snap['thumbnailPath']),
      );
      final changed = await updateHistory(updated, syncSnapshot: false);
      if (changed > 0) {
        repaired++;
      }
    }

    for (final entity in entities) {
      if (entity is! File) continue;
      final path = entity.path;
      if (!_isSupportedVideo(path)) {
        continue;
      }
      if (existingByPath.containsKey(_normalizePath(path))) continue;

      final stat = await entity.stat();
      final fileName = basename(path);
      final format =
          fileName.toLowerCase().contains('_shorts') ? 'Shorts' : 'Normal';
      final snap = _findSnapshotMatch(
        snapshotIndex,
        filePath: path,
        videoName: fileName,
        sizeBytes: stat.size,
      );
      final item = _buildImportedItem(
        filePath: path,
        stat: stat,
        fallbackVideoName: fileName,
        fallbackFormat: format,
        snapshot: snap,
      );
      await db.insert('history', item.toMap());
      existingByPath[_normalizePath(path)] = item.toMap();
      inserted++;
    }

    if (inserted > 0 || repaired > 0) {
      await _writeHistorySnapshot(db);
    }

    return inserted;
  }

  Future<void> refreshHistorySnapshot() async {
    final db = await instance.database;
    await _writeHistorySnapshot(db);
  }

  Future<void> _writeHistorySnapshot(Database db) async {
    try {
      final dir = await ensureVideoFixerDirectory();
      final file = File(join(dir.path, _historySnapshotFileName));
      final rows = await db.query('history', orderBy: 'date DESC');

      final items = rows.map((row) {
        return {
          'videoName': row['videoName'],
          'thumbnailPath': row['thumbnailPath'],
          'filePath': row['filePath'],
          'sizeBytes': row['sizeBytes'],
          'format': row['format'],
          'date': row['date'],
          'isUploaded': row['isUploaded'],
          'uploadedChannel': row['uploadedChannel'],
          'youtubeLink': row['youtubeLink'],
          'youtubeStatus': row['youtubeStatus'] ?? '',
          'lastSynced': row['lastSynced'] ?? '',
          'uploadStatus': row['uploadStatus'] ?? 'not_uploaded',
          'queueAddedAt': row['queueAddedAt'] ?? '',
          'uploadError': row['uploadError'] ?? '',
        };
      }).toList();

      final payload = {
        'version': _historySnapshotVersion,
        'updatedAt': DateTime.now().toIso8601String(),
        'items': items,
      };
      await file.writeAsString(jsonEncode(payload), flush: true);
    } catch (_) {}
  }

  Future<Map<String, Map<String, dynamic>>> _loadHistorySnapshotIndex(
      Directory dir) async {
    try {
      final file = File(join(dir.path, _historySnapshotFileName));
      if (!await file.exists()) return {};
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return {};

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      final items = decoded['items'];
      if (items is! List) return {};

      final index = <String, Map<String, dynamic>>{};
      for (final rawItem in items) {
        if (rawItem is! Map) continue;
        final item = Map<String, dynamic>.from(rawItem);
        final path = _asString(item['filePath']);
        final name = _asString(item['videoName']);
        final size = _toInt(item['sizeBytes']);

        if (path.isNotEmpty) {
          index[_normalizePath(path)] = item;
        }
        if (name.isNotEmpty && size > 0) {
          index[_fallbackSnapshotKey(videoName: name, sizeBytes: size)] = item;
        }
      }
      return index;
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic>? _findSnapshotMatch(
    Map<String, Map<String, dynamic>> index, {
    required String filePath,
    required String videoName,
    required int sizeBytes,
  }) {
    final direct = index[_normalizePath(filePath)];
    if (direct != null) return direct;
    if (sizeBytes <= 0) return null;
    return index[
        _fallbackSnapshotKey(videoName: videoName, sizeBytes: sizeBytes)];
  }

  HistoryItem _buildImportedItem({
    required String filePath,
    required FileStat stat,
    required String fallbackVideoName,
    required String fallbackFormat,
    Map<String, dynamic>? snapshot,
  }) {
    DateTime date = stat.modified;
    final snapDate = _asString(snapshot?['date']);
    if (snapDate.isNotEmpty) {
      date = DateTime.tryParse(snapDate) ?? date;
    }

    final format = _asString(snapshot?['format']);
    final cleanedFormat =
        format == 'Shorts' || format == 'Normal' ? format : fallbackFormat;
    return HistoryItem(
      videoName: _pickString(null, snapshot?['videoName'],
          fallback: fallbackVideoName),
      thumbnailPath: _pickString(null, snapshot?['thumbnailPath']),
      filePath: filePath,
      sizeBytes: stat.size,
      format: cleanedFormat,
      date: date,
      isUploaded: _asBool(snapshot?['isUploaded']),
      uploadedChannel: _pickString(null, snapshot?['uploadedChannel']),
      youtubeLink: _pickString(null, snapshot?['youtubeLink']),
      youtubeStatus: _pickString(null, snapshot?['youtubeStatus']),
      lastSynced: _pickString(null, snapshot?['lastSynced']),
    );
  }

  bool _isSupportedVideo(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm');
  }

  String _normalizePath(String path) => path.trim();

  String _fallbackSnapshotKey(
      {required String videoName, required int sizeBytes}) {
    return '${videoName.toLowerCase()}::$sizeBytes';
  }

  String _asString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase().trim() ?? '';
    return text == '1' || text == 'true';
  }

  bool _preferSnapshotString({dynamic dbValue, dynamic snapValue}) {
    return _asString(dbValue).isEmpty && _asString(snapValue).isNotEmpty;
  }

  String _pickString(dynamic dbValue, dynamic snapValue,
      {String fallback = ''}) {
    final dbText = _asString(dbValue);
    if (dbText.isNotEmpty) return dbText;
    final snapText = _asString(snapValue);
    if (snapText.isNotEmpty) return snapText;
    return fallback;
  }

  Future<int> setUploadStatus(
    int id,
    String status, {
    String? queueAddedAt,
    String? uploadError,
  }) async {
    try {
      final db = await instance.database;
      final values = <String, dynamic>{'uploadStatus': status};
      if (queueAddedAt != null) values['queueAddedAt'] = queueAddedAt;
      if (uploadError != null) values['uploadError'] = uploadError;
      return await db.update('history', values, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      secureLog('DBHelper.setUploadStatus error: $e');
      return 0;
    }
  }

  Future<List<HistoryItem>> getQueuedUploads() async {
    final db = await instance.database;
    final result = await db.query(
      'history',
      where: 'uploadStatus = ?',
      whereArgs: ['queued'],
      orderBy: 'queueAddedAt ASC',
    );
    return result.map((row) => HistoryItem.fromMap(row)).toList();
  }

  Future<int> getQueueCount() async {
    final db = await instance.database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM history WHERE uploadStatus = "queued"');
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
