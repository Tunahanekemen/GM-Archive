class Library {
  final String id;
  final String code;
  final String name;
  final String accessLevel; // "owner" | "guest"

  Library({
    required this.id,
    required this.code,
    required this.name,
    required this.accessLevel,
  });

  bool get isOwner => accessLevel == 'owner';
  bool get isGuest => accessLevel == 'guest';

  Map<String, dynamic> toJson() {
    return {
      'libraryId': id,
      'code': code,
      'name': name,
      'accessLevel': accessLevel,
    };
  }

  factory Library.fromJson(Map<String, dynamic> json) {
    return Library(
      id: json['libraryId'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      accessLevel: json['accessLevel'] ?? 'guest',
    );
  }
}
