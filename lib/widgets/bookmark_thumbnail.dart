import 'dart:io';
import 'package:flutter/material.dart';
import '../models/bookmark.dart';
import '../services/db_service.dart';
import '../services/ig_metadata_extractor.dart';
import '../services/local_storage_service.dart';
import '../main.dart'; // for globalDbService

class BookmarkThumbnail extends StatefulWidget {
  final Bookmark bookmark;
  final BoxFit fit;

  const BookmarkThumbnail({
    Key? key,
    required this.bookmark,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  _BookmarkThumbnailState createState() => _BookmarkThumbnailState();
}

class _BookmarkThumbnailState extends State<BookmarkThumbnail> {
  late String _currentUrl;
  bool _isRefreshing = false;
  int _retryCount = 0;
  String? _localThumbPath;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.bookmark.thumbnailUrl;
    _checkLocalThumbnail();
  }

  Future<void> _checkLocalThumbnail() async {
    final path = await LocalStorageService.findLocalThumbnail(
      widget.bookmark.platform,
      widget.bookmark.videoId,
    );
    if (path != null && mounted) {
      setState(() {
        _localThumbPath = path;
      });
    }
  }

  @override
  void didUpdateWidget(covariant BookmarkThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookmark.thumbnailUrl != widget.bookmark.thumbnailUrl) {
      setState(() {
        _currentUrl = widget.bookmark.thumbnailUrl;
        _retryCount = 0; // Reset retry on new url 
        _localThumbPath = null;
      });
      _checkLocalThumbnail();
    }
  }

  Future<void> _refreshInstagramUrl() async {
    if (_isRefreshing || _retryCount >= 2 || widget.bookmark.platform != PlatformType.instagram) {
      return; // Prevent infinite loops or refreshing non-IG links
    }

    setState(() {
      _isRefreshing = true;
      _retryCount++;
    });

    try {
      debugPrint('Thumbnail expired for ${widget.bookmark.videoId}. Refreshing via WebView...');
      final newData = await InstagramMetadataExtractor.extract(
        context,
        widget.bookmark.videoId,
        widget.bookmark.originalUrl,
      );

      final newThumb = newData['thumbnailUrl'];
      final newVideo = newData['videoDirectUrl'];

      if (newThumb != null && newThumb.isNotEmpty && newThumb != _currentUrl) {
        debugPrint('Successfully refreshed thumbnail URL for ${widget.bookmark.videoId}');
        
        // Update database silently
        await globalDbService.updateBookmarkMediaUrls(
          widget.bookmark.id,
          newThumb,
          videoDirectUrl: newVideo,
        );

        if (mounted) {
          setState(() {
            _currentUrl = newThumb;
            _isRefreshing = false;
          });
        }
      } else {
        debugPrint('Failed to get a new thumbnail URL for ${widget.bookmark.videoId}');
        if (mounted) setState(() => _isRefreshing = false);
      }
    } catch (e) {
      debugPrint('Error refreshing thumbnail: $e');
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_localThumbPath != null) {
      return Image.file(
        File(_localThumbPath!),
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          // If local file fails (e.g. deleted), fallback to network flow
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _localThumbPath = null);
          });
          return const SizedBox();
        },
      );
    }

    if (_currentUrl.isEmpty) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Icon(Icons.image_not_supported, color: Colors.white38),
        ),
      );
    }

    if (_isRefreshing) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Image.network(
      _currentUrl,
      fit: widget.fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey[900],
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        // Automatically attempt to refresh if we haven't maxed out retries
        if (widget.bookmark.platform == PlatformType.instagram && _retryCount < 2) {
          // Add post frame callback because we can't build/setState during build 
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _refreshInstagramUrl();
          });
          
          return Container(
            color: Colors.grey[900],
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        // Final fallback if refresh also fails
        return Container(
          color: Colors.grey[900],
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.white38),
          ),
        );
      },
    );
  }
}
