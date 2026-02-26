import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MigrationService {
  static Future<bool> isMigrationDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('migration_done') ?? false;
  }

  static Future<void> migrateToLibrary(String libraryId) async {
    if (await isMigrationDone()) return;

    final db = FirebaseFirestore.instance;

    debugPrint('Starting migration to library: $libraryId');

    try {
      final bookmarks = await db.collection('bookmarks').get();
      int bookmarkCount = 0;
      for (final doc in bookmarks.docs) {
        await db
            .collection('libraries/$libraryId/bookmarks')
            .doc(doc.id)
            .set(doc.data());
        bookmarkCount++;
      }
      debugPrint('Migrated $bookmarkCount bookmarks');

      final folders = await db.collection('folders').get();
      int folderCount = 0;
      for (final doc in folders.docs) {
        await db
            .collection('libraries/$libraryId/folders')
            .doc(doc.id)
            .set(doc.data());
        folderCount++;
      }
      debugPrint('Migrated $folderCount folders');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('migration_done', true);

      debugPrint('Migration complete');
    } catch (e) {
      debugPrint('Migration error: $e');
    }
  }
}
