import 'package:cloud_firestore/cloud_firestore.dart';

enum PlatformType { youtube, instagram, twitter, unknown }
enum VideoType { normal, shorts, reels, post, tweet, unknown }

class Bookmark {
  final String id;
  final String originalUrl;
  final PlatformType platform;
  final VideoType type;
  final String videoId;
  final String title;
  final String? customTitle;
  final String description;
  final String thumbnailUrl;
  final String? videoDirectUrl;
  final bool isStarred;
  final String? folderId;
  final DateTime addedAt;

  Bookmark({
    required this.id,
    required this.originalUrl,
    required this.platform,
    required this.type,
    required this.videoId,
    required this.title,
    this.customTitle,
    required this.description,
    required this.thumbnailUrl,
    this.videoDirectUrl,
    this.isStarred = false,
    this.folderId,
    required this.addedAt,
  });

  factory Bookmark.fromMap(Map<String, dynamic> map, String id) {
    return Bookmark(
      id: id,
      originalUrl: map['originalUrl'] ?? '',
      platform: PlatformType.values.byName(map['platform'] ?? 'unknown'),
      type: VideoType.values.byName(map['type'] ?? 'unknown'),
      videoId: map['videoId'] ?? '',
      title: map['title'] ?? '',
      customTitle: map['customTitle'],
      description: map['description'] ?? '',
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      videoDirectUrl: map['videoDirectUrl'],
      isStarred: map['isStarred'] ?? false,
      folderId: map['folderId'],
      addedAt: (map['addedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'originalUrl': originalUrl,
      'platform': platform.name,
      'type': type.name,
      'videoId': videoId,
      'title': title,
      if (customTitle != null && customTitle!.isNotEmpty) 'customTitle': customTitle,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      if (videoDirectUrl != null) 'videoDirectUrl': videoDirectUrl,
      'isStarred': isStarred,
      if (folderId != null) 'folderId': folderId,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }
}
