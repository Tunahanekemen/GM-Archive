import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bookmark.dart';
import '../models/folder.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _activeLibraryId = '';
  String _accessLevel = 'owner';

  void setActiveLibrary(String libraryId, String accessLevel) {
    _activeLibraryId = libraryId;
    _accessLevel = accessLevel;
  }

  String get activeLibraryId => _activeLibraryId;
  bool get isReadOnly => _accessLevel == 'guest';

  String get collectionPath => 'libraries/$_activeLibraryId/bookmarks';
  String get foldersPath => 'libraries/$_activeLibraryId/folders';

  Future<bool> isDuplicate(String videoId) async {
    final query = await _db.collection(collectionPath)
        .where('videoId', isEqualTo: videoId)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  Future<void> addBookmark(Bookmark bookmark) async {
    if (isReadOnly) return;
    try {
      await _db.collection(collectionPath).add(bookmark.toMap());
    } catch (e) {
      debugPrint('Error adding bookmark: $e');
    }
  }

  Future<void> updateBookmarkTitle(String id, String newTitle) async {
    if (isReadOnly) return;
    try {
      await _db.collection(collectionPath).doc(id).update({'customTitle': newTitle});
    } catch (e) {
      debugPrint('Error updating title: $e');
    }
  }

  Future<void> updateBookmarkMediaUrls(String id, String thumbnailUrl, {String? videoDirectUrl}) async {
    if (isReadOnly) return;
    try {
      final Map<String, dynamic> updates = {'thumbnailUrl': thumbnailUrl};
      if (videoDirectUrl != null && videoDirectUrl.isNotEmpty) {
        updates['videoDirectUrl'] = videoDirectUrl;
      }
      await _db.collection(collectionPath).doc(id).update(updates);
    } catch (e) {
      debugPrint('Error updating media urls: $e');
    }
  }

  Stream<List<Bookmark>> getBookmarks() {
    return _db.collection(collectionPath)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Bookmark.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> deleteBookmark(String id) async {
    if (isReadOnly) return;
    try {
      await _db.collection(collectionPath).doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting bookmark: $e');
    }
  }

  Future<void> toggleStar(String id, bool currentStatus) async {
    if (isReadOnly) return;
    try {
      await _db.collection(collectionPath).doc(id).update({'isStarred': !currentStatus});
    } catch (e) {
      debugPrint('Error toggling star: $e');
    }
  }

  Future<String> createFolder(String name, List<String> bookmarkIds, {String? thumbnailUrl}) async {
    if (isReadOnly) return '';
    try {
      final docRef = await _db.collection(foldersPath).add({
        'name': name,
        'bookmarkIds': bookmarkIds,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        'createdAt': Timestamp.now(),
      });

      for (final bid in bookmarkIds) {
        await _db.collection(collectionPath).doc(bid).update({'folderId': docRef.id});
      }

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating folder: $e');
      rethrow;
    }
  }

  Stream<List<Folder>> getFolders() {
    return _db.collection(foldersPath)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Folder.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> addBookmarkToFolder(String bookmarkId, String folderId) async {
    if (isReadOnly) return;
    try {
      await _db.collection(foldersPath).doc(folderId).update({
        'bookmarkIds': FieldValue.arrayUnion([bookmarkId]),
      });
      await _db.collection(collectionPath).doc(bookmarkId).update({'folderId': folderId});
    } catch (e) {
      debugPrint('Error adding bookmark to folder: $e');
    }
  }

  Future<void> removeBookmarkFromFolder(String bookmarkId, String folderId) async {
    if (isReadOnly) return;
    try {
      await _db.collection(foldersPath).doc(folderId).update({
        'bookmarkIds': FieldValue.arrayRemove([bookmarkId]),
      });
      await _db.collection(collectionPath).doc(bookmarkId).update({'folderId': FieldValue.delete()});
    } catch (e) {
      debugPrint('Error removing bookmark from folder: $e');
    }
  }

  Future<void> deleteFolder(String folderId) async {
    if (isReadOnly) return;
    try {
      final folderDoc = await _db.collection(foldersPath).doc(folderId).get();
      if (folderDoc.exists) {
        final data = folderDoc.data()!;
        final bookmarkIds = List<String>.from(data['bookmarkIds'] ?? []);
        for (final bid in bookmarkIds) {
          await _db.collection(collectionPath).doc(bid).update({'folderId': FieldValue.delete()});
        }
      }
      await _db.collection(foldersPath).doc(folderId).delete();
    } catch (e) {
      debugPrint('Error deleting folder: $e');
    }
  }

  Future<void> renameFolder(String folderId, String newName) async {
    if (isReadOnly) return;
    try {
      await _db.collection(foldersPath).doc(folderId).update({'name': newName});
    } catch (e) {
      debugPrint('Error renaming folder: $e');
    }
  }
}
