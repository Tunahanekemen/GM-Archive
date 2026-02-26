import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_keys.dart';

class InstagramApiService {
  static const _api1Host = 'instagram120.p.rapidapi.com';
  static const _api2Host = 'instagram-scraper-stable-api.p.rapidapi.com';

  static Future<Map<String, String>> fetchMediaData(String shortcode) async {
    try {
      final result = await _fetchFromInstagram120(shortcode);
      if (result != null) return result;
    } catch (e) {
      debugPrint('IG API 1 failed: $e');
    }

    try {
      final result = await _fetchFromScraperStable(shortcode);
      if (result != null) return result;
    } catch (e) {
      debugPrint('IG API 2 failed: $e');
    }

    return {'title': '', 'description': '', 'thumbnailUrl': '', 'videoDirectUrl': ''};
  }

  static Future<Map<String, String>?> _fetchFromInstagram120(String shortcode) async {
    final response = await http.post(
      Uri.parse('https://$_api1Host/api/instagram/links'),
      headers: {
        'x-rapidapi-host': _api1Host,
        'x-rapidapi-key': ApiKeys.rapidApiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'url': 'https://www.instagram.com/reel/$shortcode/'}),
    );

    if (response.statusCode == 429) return null;
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    return _extractFromInstagram120Response(data);
  }

  static Future<Map<String, String>?> _fetchFromScraperStable(String shortcode) async {
    final response = await http.get(
      Uri.parse('https://$_api2Host/get_media_data_v2.php?media_code=$shortcode'),
      headers: {
        'x-rapidapi-host': _api2Host,
        'x-rapidapi-key': ApiKeys.rapidApiKey,
      },
    );

    if (response.statusCode == 429) return null;
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    if (data is Map && data.containsKey('error')) return null;

    return _extractFromScraperStableResponse(data);
  }

  static Map<String, String> _extractFromScraperStableResponse(dynamic data) {
    String title = 'Instagram';
    String description = '';
    String thumbnailUrl = '';
    String videoDirectUrl = '';

    String username = '';
    if (data['user'] != null && data['user']['username'] != null) {
      username = data['user']['username'];
    } else if (data['owner'] != null && data['owner']['username'] != null) {
      username = data['owner']['username'];
    }
    if (username.isNotEmpty) title = '@$username';

    if (data['caption'] != null) {
      if (data['caption'] is Map && data['caption']['text'] != null) {
        description = data['caption']['text'];
      } else if (data['caption'] is String) {
        description = data['caption'];
      }
    }

    if (data['display_url'] != null) {
      thumbnailUrl = data['display_url'].toString().replaceAll(r'\/', '/');
    } else if (data['image_versions2'] != null) {
      var candidates = data['image_versions2']['candidates'];
      if (candidates != null && candidates is List && candidates.isNotEmpty) {
        thumbnailUrl = candidates[0]['url'].toString().replaceAll(r'\/', '/');
      }
    } else if (data['thumbnail_url'] != null) {
      thumbnailUrl = data['thumbnail_url'].toString().replaceAll(r'\/', '/');
    }

    if (data['video_url'] != null) {
      videoDirectUrl = data['video_url'].toString().replaceAll(r'\/', '/').replaceAll(r'\u0026', '&');
    } else if (data['video_versions'] != null && data['video_versions'] is List) {
      var versions = data['video_versions'] as List;
      if (versions.isNotEmpty) {
        videoDirectUrl = versions[0]['url'].toString().replaceAll(r'\/', '/').replaceAll(r'\u0026', '&');
      }
    }

    return {'title': title, 'description': description, 'thumbnailUrl': thumbnailUrl, 'videoDirectUrl': videoDirectUrl};
  }

  static Map<String, String> _extractFromInstagram120Response(dynamic data) {
    String title = 'Instagram';
    String description = '';
    String thumbnailUrl = '';
    String videoDirectUrl = '';

    dynamic item;
    if (data is List && data.isNotEmpty) {
      item = data[0];
    } else if (data is Map) {
      item = data;
    }

    if (item == null || item is! Map) {
      return {'title': title, 'description': description, 'thumbnailUrl': thumbnailUrl, 'videoDirectUrl': videoDirectUrl};
    }

    if (item['pictureUrl'] != null) {
      thumbnailUrl = item['pictureUrl'].toString();
    } else if (item['pictureUrlWrapped'] != null) {
      thumbnailUrl = item['pictureUrlWrapped'].toString();
    }

    if (item['urls'] != null && item['urls'] is List) {
      var urls = item['urls'] as List;
      if (urls.isNotEmpty && urls[0] is Map) {
        videoDirectUrl = (urls[0]['url'] ?? '').toString();
      }
    }

    if (item['meta'] != null && item['meta'] is Map) {
      var meta = item['meta'] as Map;
      
      String username = (meta['username'] ?? '').toString();
      if (username.isNotEmpty) title = '@$username';
      
      if (meta['text'] != null && meta['text'].toString().isNotEmpty) {
        description = meta['text'].toString();
      } else if (meta['title'] != null && meta['title'].toString().isNotEmpty) {
        description = meta['title'].toString();
      }
    }

    return {'title': title, 'description': description, 'thumbnailUrl': thumbnailUrl, 'videoDirectUrl': videoDirectUrl};
  }
}
