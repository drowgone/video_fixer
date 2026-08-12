class HistoryItem {
  final int? id;
  final String videoName;
  final String thumbnailPath;
  final String filePath;
  final int sizeBytes;
  final String format; // 'Normal' or 'Shorts'
  final DateTime date;
  final bool isUploaded;
  final String uploadedChannel;
  final String youtubeLink;
  final String youtubeStatus; // Processing, Public, Unlisted, Private, Deleted, Rejected
  final String lastSynced; // ISO DateTime string of last successful sync
  // Upload queue fields
  final String uploadStatus; // 'not_uploaded', 'queued', 'uploading', 'uploaded', 'failed'
  final String queueAddedAt; // ISO DateTime when added to queue, or empty
  final String uploadError; // last error message, or empty

  HistoryItem({
    this.id,
    required this.videoName,
    required this.thumbnailPath,
    required this.filePath,
    required this.sizeBytes,
    required this.format,
    required this.date,
    this.isUploaded = false,
    this.uploadedChannel = '',
    this.youtubeLink = '',
    this.youtubeStatus = '',
    this.lastSynced = '',
    this.uploadStatus = 'not_uploaded',
    this.queueAddedAt = '',
    this.uploadError = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'videoName': videoName,
      'thumbnailPath': thumbnailPath,
      'filePath': filePath,
      'sizeBytes': sizeBytes,
      'format': format,
      'date': date.toIso8601String(),
      'isUploaded': isUploaded ? 1 : 0,
      'uploadedChannel': uploadedChannel,
      'youtubeLink': youtubeLink,
      'youtubeStatus': youtubeStatus,
      'lastSynced': lastSynced,
      'uploadStatus': uploadStatus,
      'queueAddedAt': queueAddedAt,
      'uploadError': uploadError,
    };
  }

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      id: map['id'] as int?,
      videoName: map['videoName'] as String,
      thumbnailPath: map['thumbnailPath'] as String,
      filePath: map['filePath'] as String,
      sizeBytes: map['sizeBytes'] as int,
      format: map['format'] as String,
      date: DateTime.parse(map['date'] as String),
      isUploaded: map['isUploaded'] == 1,
      uploadedChannel: map['uploadedChannel'] as String,
      youtubeLink: map['youtubeLink'] as String,
      youtubeStatus: (map['youtubeStatus'] as String?) ?? '',
      lastSynced: (map['lastSynced'] as String?) ?? '',
      uploadStatus: (map['uploadStatus'] as String?) ?? 'not_uploaded',
      queueAddedAt: (map['queueAddedAt'] as String?) ?? '',
      uploadError: (map['uploadError'] as String?) ?? '',
    );
  }

  HistoryItem copyWith({
    int? id,
    String? videoName,
    String? thumbnailPath,
    String? filePath,
    int? sizeBytes,
    String? format,
    DateTime? date,
    bool? isUploaded,
    String? uploadedChannel,
    String? youtubeLink,
    String? youtubeStatus,
    String? lastSynced,
    String? uploadStatus,
    String? queueAddedAt,
    String? uploadError,
  }) {
    return HistoryItem(
      id: id ?? this.id,
      videoName: videoName ?? this.videoName,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      filePath: filePath ?? this.filePath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      format: format ?? this.format,
      date: date ?? this.date,
      isUploaded: isUploaded ?? this.isUploaded,
      uploadedChannel: uploadedChannel ?? this.uploadedChannel,
      youtubeLink: youtubeLink ?? this.youtubeLink,
      youtubeStatus: youtubeStatus ?? this.youtubeStatus,
      lastSynced: lastSynced ?? this.lastSynced,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      queueAddedAt: queueAddedAt ?? this.queueAddedAt,
      uploadError: uploadError ?? this.uploadError,
    );
  }
}
