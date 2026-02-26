import '../models/bookmark.dart';

class ParseResult {
  final PlatformType platform;
  final VideoType type;
  final String videoId;

  ParseResult({required this.platform, required this.type, required this.videoId});
}

class LinkParser {
  /// Extracts platform, video type and the unique video ID from a given URL.
  static ParseResult parse(String url) {
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      return _parseYouTube(url);
    } else if (url.contains('instagram.com')) {
      return _parseInstagram(url);
    } else if (url.contains('x.com') || url.contains('twitter.com')) {
      return _parseTwitter(url);
    }

    return ParseResult(
      platform: PlatformType.unknown,
      type: VideoType.unknown,
      videoId: '',
    );
  }

  static ParseResult _parseYouTube(String url) {
    String videoId = '';
    VideoType type = VideoType.normal;

    // Check for shorts
    if (url.contains('/shorts/')) {
      type = VideoType.shorts;
      final RegExp regex = RegExp(r'/shorts/([a-zA-Z0-9_-]+)');
      final match = regex.firstMatch(url);
      if (match != null && match.groupCount >= 1) {
        videoId = match.group(1)!;
      }
    } else {
      // Normal video (watch?v= or youtu.be/)
      final RegExp regExp1 = RegExp(r'(?:v=|/)([0-9A-Za-z_-]{11}).*');
      final match = regExp1.firstMatch(url);
      if (match != null && match.groupCount >= 1) {
        videoId = match.group(1)!;
      }
    }

    // Clean up query parameters if they accidentally got caught in shorts parsing
    if (videoId.contains('?')) {
      videoId = videoId.split('?').first;
    }

    return ParseResult(
      platform: PlatformType.youtube,
      type: type,
      videoId: videoId,
    );
  }

  static ParseResult _parseInstagram(String url) {
    String videoId = '';
    VideoType type = VideoType.unknown;

    // Instagram URL formats:
    // https://www.instagram.com/reel/CXYZ123ABC/?igshid=...
    // https://www.instagram.com/reels/CXYZ123ABC/?igshid=...
    // https://www.instagram.com/p/CXYZ123ABC/?igshid=...

    final RegExp igRegex = RegExp(r'/(?:reel|reels|p)/([a-zA-Z0-9_-]+)');
    final match = igRegex.firstMatch(url);

    if (match != null && match.groupCount >= 1) {
      videoId = match.group(1)!;
      if (url.contains('/p/')) {
        type = VideoType.post;
      } else {
        type = VideoType.reels;
      }
    }

    return ParseResult(
      platform: PlatformType.instagram,
      type: type,
      videoId: videoId,
    );
  }

  static ParseResult _parseTwitter(String url) {
    String tweetId = '';

    // Twitter/X URL formats:
    // https://x.com/username/status/1234567890
    // https://twitter.com/username/status/1234567890
    // https://x.com/username/status/1234567890?s=20
    final RegExp tweetRegex = RegExp(r'/status/(\d+)');
    final match = tweetRegex.firstMatch(url);

    if (match != null && match.groupCount >= 1) {
      tweetId = match.group(1)!;
    }

    return ParseResult(
      platform: PlatformType.twitter,
      type: VideoType.tweet,
      videoId: tweetId,
    );
  }
}
