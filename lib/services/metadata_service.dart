import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'link_parser.dart';
import 'instagram_api_service.dart';
import 'twitter_api_service.dart';
import '../models/bookmark.dart';
import '../config/api_keys.dart';

class MetadataFetcher {
  static Future<Map<String, String>> fetchMetadata(String url, ParseResult parsed) async {
    String title = 'Bilinmeyen Başlık';
    String description = 'Açıklama bulunamadı';
    String thumbnailUrl = '';
    String videoDirectUrl = '';

    try {
      if (parsed.platform == PlatformType.youtube) {
        final ytApiUrl = 'https://www.googleapis.com/youtube/v3/videos?part=snippet&id=${parsed.videoId}&key=${ApiKeys.youtubeDataApiKey}';
        
        try {
          var response = await http.get(Uri.parse(ytApiUrl));
          if (response.statusCode == 200) {
            var jsonResponse = jsonDecode(response.body);
            if (jsonResponse['items'] != null && jsonResponse['items'].isNotEmpty) {
              var snippet = jsonResponse['items'][0]['snippet'];
              title = snippet['title'] ?? title;
              description = snippet['description'] ?? description;
              
              if (snippet['thumbnails'] != null) {
                var thumbnails = snippet['thumbnails'];
                thumbnailUrl = 
                    thumbnails['maxres']?['url'] ?? 
                    thumbnails['high']?['url'] ?? 
                    thumbnails['standard']?['url'] ?? 
                    thumbnails['medium']?['url'] ?? 
                    thumbnails['default']?['url'] ?? 
                    'https://img.youtube.com/vi/${parsed.videoId}/hqdefault.jpg';
              } else {
                thumbnailUrl = 'https://img.youtube.com/vi/${parsed.videoId}/maxresdefault.jpg';
              }
            } else {
               thumbnailUrl = 'https://img.youtube.com/vi/${parsed.videoId}/maxresdefault.jpg';
            }
          } else {
            thumbnailUrl = 'https://img.youtube.com/vi/${parsed.videoId}/maxresdefault.jpg';
          }
        } catch (e) {
          debugPrint('YouTube API Error: $e');
          thumbnailUrl = 'https://img.youtube.com/vi/${parsed.videoId}/maxresdefault.jpg';
        }
      } else if (parsed.platform == PlatformType.instagram) {
        final igData = await InstagramApiService.fetchMediaData(parsed.videoId);
        title = igData['title'] ?? 'Instagram';
        description = igData['description'] ?? '';
        thumbnailUrl = igData['thumbnailUrl'] ?? '';
        videoDirectUrl = igData['videoDirectUrl'] ?? '';
      } else if (parsed.platform == PlatformType.twitter) {
        final twitterData = await TwitterApiService.fetchTweetData(parsed.videoId);
        title = twitterData['title'] ?? 'X Post';
        description = twitterData['description'] ?? '';
        thumbnailUrl = twitterData['thumbnailUrl'] ?? '';
        videoDirectUrl = twitterData['videoDirectUrl'] ?? '';
      }
    } catch (e) {
      debugPrint('Error fetching metadata: $e');
    }

    return {
      'title': title,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'videoDirectUrl': videoDirectUrl,
    };
  }
}
