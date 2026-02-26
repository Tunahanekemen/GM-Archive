import 'package:cloud_firestore/cloud_firestore.dart';

class Folder {
  final String id;
  final String name;
  final List<String> bookmarkIds;
  final String? thumbnailUrl;
  final DateTime createdAt;

  Folder({
    required this.id,
    required this.name,
    required this.bookmarkIds,
    this.thumbnailUrl,
    required this.createdAt,
  });

  factory Folder.fromMap(Map<String, dynamic> map, String id) {
    return Folder(
      id: id,
      name: map['name'] ?? 'Klasör',
      bookmarkIds: List<String>.from(map['bookmarkIds'] ?? []),
      thumbnailUrl: map['thumbnailUrl'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'bookmarkIds': bookmarkIds,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
