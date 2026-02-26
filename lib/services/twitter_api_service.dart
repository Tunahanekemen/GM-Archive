import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TwitterApiService {
  static Future<Map<String, String>> fetchTweetData(String tweetId) async {
    final apiUrl = 'https://api.fxtwitter.com/i/status/$tweetId';

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final tweet = json['tweet'];

        if (tweet == null) return _fallbackResult(tweetId);

        final author = tweet['author'] ?? {};
        final String authorName = author['name'] ?? 'Bilinmeyen';
        final String authorHandle = author['screen_name'] ?? '';
        final String authorAvatar = author['avatar_url'] ?? '';
        final String tweetText = tweet['text'] ?? '';

        String thumbnailUrl = '';
        String videoDirectUrl = '';
        _extractMedia(tweet, (thumb, video) {
          thumbnailUrl = thumb;
          videoDirectUrl = video;
        });

        String quotedText = '';
        String quotedAuthor = '';

        final quote = tweet['quote'];
        if (quote != null) {
          final qAuthor = quote['author'] ?? {};
          quotedAuthor = '@${qAuthor['screen_name'] ?? ''} (${qAuthor['name'] ?? ''})';
          quotedText = quote['text'] ?? '';

          String quotedThumbnail = '';
          String quotedVideoUrl = '';
          _extractMedia(quote, (thumb, video) {
            quotedThumbnail = thumb;
            quotedVideoUrl = video;
          });

          if (thumbnailUrl.isEmpty && quotedThumbnail.isNotEmpty) {
            thumbnailUrl = quotedThumbnail;
          }
          if (videoDirectUrl.isEmpty && quotedVideoUrl.isNotEmpty) {
            videoDirectUrl = quotedVideoUrl;
          }
        }

        if (thumbnailUrl.isEmpty) thumbnailUrl = authorAvatar;

        String fullDescription = tweetText;
        if (quotedText.isNotEmpty) {
          fullDescription += '\n\n━━━ Alıntılanan Post ━━━\n$quotedAuthor:\n$quotedText';
        }

        return {
          'title': '@$authorHandle ($authorName)',
          'description': fullDescription,
          'thumbnailUrl': thumbnailUrl,
          'videoDirectUrl': videoDirectUrl,
          'authorName': authorName,
          'authorAvatar': authorAvatar,
        };
      } else {
        debugPrint('FxTwitter API Error: ${response.statusCode}');
        return _fallbackResult(tweetId);
      }
    } catch (e) {
      debugPrint('FxTwitter API Exception: $e');
      return _fallbackResult(tweetId);
    }
  }

  static void _extractMedia(Map<String, dynamic> tweetObj, void Function(String thumb, String video) callback) {
    String thumb = '';
    String video = '';

    final media = tweetObj['media'];
    if (media != null) {
      final videos = media['videos'] as List?;
      if (videos != null && videos.isNotEmpty) {
        final v = videos[0];
        thumb = v['thumbnail_url'] ?? '';
        video = v['url'] ?? '';
      }

      if (thumb.isEmpty) {
        final photos = media['photos'] as List?;
        if (photos != null && photos.isNotEmpty) {
          thumb = photos[0]['url'] ?? '';
        }
      }
    }

    callback(thumb, video);
  }

  static Map<String, String> _fallbackResult(String tweetId) {
    return {
      'title': 'X Post',
      'description': '',
      'thumbnailUrl': '',
      'videoDirectUrl': '',
      'authorName': '',
      'authorAvatar': '',
    };
  }
}
