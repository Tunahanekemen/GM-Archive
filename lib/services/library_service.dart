import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/library.dart';

class LibraryService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _librariesCollection = 'libraries';
  static const String _prefsKey = 'saved_libraries';
  static const String _activeKey = 'active_library_id';

  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  static Future<String> _generateUniqueCode() async {
    for (int i = 0; i < 10; i++) {
      final code = _generateCode();
      final existing = await _db
          .collection(_librariesCollection)
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return code;
    }
    return _generateCode() + _generateCode().substring(0, 2);
  }

  static Future<Library> createLibrary(String name, String ownerPassword) async {
    final code = await _generateUniqueCode();
    final ownerHash = hashPassword(ownerPassword);

    final docRef = await _db.collection(_librariesCollection).add({
      'code': code,
      'name': name,
      'ownerPasswordHash': ownerHash,
      'guestPasswordHash': null,
      'createdAt': Timestamp.now(),
    });

    final library = Library(
      id: docRef.id,
      code: code,
      name: name,
      accessLevel: 'owner',
    );

    await _saveLibraryLocally(library);
    await setActiveLibrary(library.id);

    return library;
  }

  static Future<Library?> joinLibrary(String code, String password) async {
    final query = await _db
        .collection(_librariesCollection)
        .where('code', isEqualTo: code.toUpperCase().trim())
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    final data = doc.data();
    final passwordHash = hashPassword(password);

    String accessLevel;
    if (data['ownerPasswordHash'] == passwordHash) {
      accessLevel = 'owner';
    } else if (data['guestPasswordHash'] != null &&
        data['guestPasswordHash'] == passwordHash) {
      accessLevel = 'guest';
    } else {
      return null;
    }

    final library = Library(
      id: doc.id,
      code: data['code'],
      name: data['name'] ?? 'Kütüphane',
      accessLevel: accessLevel,
    );

    await _saveLibraryLocally(library);
    return library;
  }

  static Future<bool> changeOwnerPassword(String libraryId, String oldPassword, String newPassword) async {
    try {
      final doc = await _db.collection(_librariesCollection).doc(libraryId).get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      if (data['ownerPasswordHash'] != hashPassword(oldPassword)) return false;

      await _db.collection(_librariesCollection).doc(libraryId).update({
        'ownerPasswordHash': hashPassword(newPassword),
      });
      return true;
    } catch (e) {
      debugPrint('Error changing owner password: $e');
      return false;
    }
  }

  static Future<bool> setGuestPassword(String libraryId, String guestPassword) async {
    try {
      await _db.collection(_librariesCollection).doc(libraryId).update({
        'guestPasswordHash': hashPassword(guestPassword),
        'guestPassword': guestPassword,
      });
      return true;
    } catch (e) {
      debugPrint('Error setting guest password: $e');
      return false;
    }
  }

  static Future<String?> getGuestPassword(String libraryId) async {
    try {
      final doc = await _db.collection(_librariesCollection).doc(libraryId).get();
      return doc.data()?['guestPassword'];
    } catch (e) {
      return null;
    }
  }

  static Future<String?> getLibraryCode(String libraryId) async {
    try {
      final doc = await _db.collection(_librariesCollection).doc(libraryId).get();
      return doc.data()?['code'];
    } catch (e) {
      return null;
    }
  }

  static Future<bool> hasGuestPassword(String libraryId) async {
    try {
      final doc = await _db.collection(_librariesCollection).doc(libraryId).get();
      final guestHash = doc.data()?['guestPasswordHash'];
      return guestHash != null && guestHash.toString().isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _saveLibraryLocally(Library library) async {
    final prefs = await SharedPreferences.getInstance();
    final libraries = await getSavedLibraries();

    libraries.removeWhere((l) => l.id == library.id);
    libraries.add(library);

    final jsonList = libraries.map((l) => l.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(jsonList));
  }

  static Future<List<Library>> getSavedLibraries() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefsKey);
    if (jsonStr == null) return [];

    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList.map((j) => Library.fromJson(j)).toList();
  }

  static Future<void> setActiveLibrary(String libraryId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, libraryId);
  }

  static Future<String?> getActiveLibraryId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }

  static Future<Library?> getActiveLibrary() async {
    final activeId = await getActiveLibraryId();
    if (activeId == null) return null;

    final libraries = await getSavedLibraries();
    try {
      return libraries.firstWhere((l) => l.id == activeId);
    } catch (_) {
      return null;
    }
  }

  static Future<void> removeLibraryLocally(String libraryId) async {
    final prefs = await SharedPreferences.getInstance();
    final libraries = await getSavedLibraries();
    libraries.removeWhere((l) => l.id == libraryId);

    final jsonList = libraries.map((l) => l.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(jsonList));

    final activeId = await getActiveLibraryId();
    if (activeId == libraryId && libraries.isNotEmpty) {
      await setActiveLibrary(libraries.first.id);
    }
  }

  static Future<bool> deleteLibraryFromFirestore(String libraryId) async {
    try {
      final bookmarks = await _db.collection('libraries/$libraryId/bookmarks').get();
      for (final doc in bookmarks.docs) {
        await doc.reference.delete();
      }

      final folders = await _db.collection('libraries/$libraryId/folders').get();
      for (final doc in folders.docs) {
        await doc.reference.delete();
      }

      await _db.collection(_librariesCollection).doc(libraryId).delete();
      await removeLibraryLocally(libraryId);

      return true;
    } catch (e) {
      debugPrint('Error deleting library: $e');
      return false;
    }
  }

  static Future<bool> isFirstLaunch() async {
    final libraries = await getSavedLibraries();
    return libraries.isEmpty;
  }
}
