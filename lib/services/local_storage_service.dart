import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/bookmark.dart';

class LocalStorageService {
  static const String _downloadPath = '/storage/emulated/0/Download';

  /// Cihazın Download klasöründe bu videoya ait inmiş bir dosya olup olmadığını kontrol eder.
  /// Varsa dosyanın tam yolunu (Path) döndürür, yoksa null döndürür.
  static Future<String?> findLocalVideo(PlatformType platform, String videoId) async {
    try {
      final dir = Directory(_downloadPath);
      if (!await dir.exists()) {
        return null; // Klasör yoksa inmiş bir şey de olamaz
      }

      String fileName;
      switch (platform) {
        case PlatformType.youtube:
          fileName = 'youtube_$videoId.mp4';
          break;
        case PlatformType.instagram:
          fileName = 'instagram_$videoId.mp4';
          break;
        case PlatformType.twitter:
          fileName = 'x_$videoId.mp4';
          break;
        default:
          return null;
      }

      final file = File('$_downloadPath/$fileName');
      if (await file.exists()) {
        debugPrint('Local dosya bulundu: ${file.path}');
        return file.path;
      }
      
      return null;
    } catch (e) {
      debugPrint('Local scanner hatası: $e');
      return null;
    }
  }

  /// Cihazın Download klasöründe bu videoya ait inmiş bir kapak fotoğrafı (thumbnail) olup olmadığını kontrol eder.
  /// Varsa dosyanın tam yolunu (Path) döndürür, yoksa null döndürür.
  static Future<String?> findLocalThumbnail(PlatformType platform, String videoId) async {
    try {
      final dir = Directory(_downloadPath);
      if (!await dir.exists()) {
        return null;
      }

      String fileName;
      switch (platform) {
        case PlatformType.youtube:
          fileName = 'youtube_$videoId\_thumb.jpg';
          break;
        case PlatformType.instagram:
          fileName = 'instagram_$videoId\_thumb.jpg';
          break;
        case PlatformType.twitter:
          fileName = 'x_$videoId\_thumb.jpg';
          break;
        default:
          return null;
      }

      final file = File('$_downloadPath/$fileName');
      if (await file.exists()) {
        debugPrint('Local thumbnail bulundu: ${file.path}');
        return file.path;
      }
      
      return null;
    } catch (e) {
      debugPrint('Local thumbnail scanner hatası: $e');
      return null;
    }
  }
}
