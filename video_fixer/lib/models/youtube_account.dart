import 'dart:convert';

class YouTubeAccount {
  final String id;
  final String name;
  final String clientId;
  final String clientSecret;
  final String channelId;
  final bool isActive;
  final String? savedCredentials; // serialized googleapis auth credentials
  final String? channelProfilePic;
  final DateTime? connectionDate;
  final String status; // 'active', 'error', 'pending'
  final String? subscriberCount;
  final String? videoCount;

  YouTubeAccount({
    required this.id,
    required this.name,
    required this.clientId,
    required this.clientSecret,
    required this.channelId,
    this.isActive = true,
    this.savedCredentials,
    this.channelProfilePic,
    this.connectionDate,
    this.status = 'pending',
    this.subscriberCount,
    this.videoCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'clientId': clientId,
      'clientSecret': clientSecret,
      'channelId': channelId,
      'isActive': isActive,
      'savedCredentials': savedCredentials,
      'channelProfilePic': channelProfilePic,
      'connectionDate': connectionDate?.toIso8601String(),
      'status': status,
      'subscriberCount': subscriberCount,
      'videoCount': videoCount,
    };
  }

  factory YouTubeAccount.fromMap(Map<String, dynamic> map) {
    return YouTubeAccount(
      id: map['id'] as String,
      name: map['name'] as String,
      clientId: map['clientId'] as String,
      clientSecret: map['clientSecret'] as String? ?? '',
      channelId: map['channelId'] as String,
      isActive: map['isActive'] as bool? ?? true,
      savedCredentials: map['savedCredentials'] as String?,
      channelProfilePic: map['channelProfilePic'] as String?,
      connectionDate: map['connectionDate'] != null ? DateTime.tryParse(map['connectionDate']) : null,
      status: map['status'] as String? ?? 'pending',
      subscriberCount: map['subscriberCount'] as String?,
      videoCount: map['videoCount'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory YouTubeAccount.fromJson(String source) =>
      YouTubeAccount.fromMap(json.decode(source) as Map<String, dynamic>);

  YouTubeAccount copyWith({
    String? id,
    String? name,
    String? clientId,
    String? clientSecret,
    String? channelId,
    bool? isActive,
    String? savedCredentials,
    String? channelProfilePic,
    DateTime? connectionDate,
    String? status,
    String? subscriberCount,
    String? videoCount,
  }) {
    return YouTubeAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      clientId: clientId ?? this.clientId,
      clientSecret: clientSecret ?? this.clientSecret,
      channelId: channelId ?? this.channelId,
      isActive: isActive ?? this.isActive,
      savedCredentials: savedCredentials ?? this.savedCredentials,
      channelProfilePic: channelProfilePic ?? this.channelProfilePic,
      connectionDate: connectionDate ?? this.connectionDate,
      status: status ?? this.status,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      videoCount: videoCount ?? this.videoCount,
    );
  }
}
