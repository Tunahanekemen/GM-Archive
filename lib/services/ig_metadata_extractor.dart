import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';

/// Extracts Instagram metadata (thumbnail, caption, videoUrl) by loading the embed
/// page in a hidden WebView and extracting data via JavaScript after render.
class InstagramMetadataExtractor {
  /// Extracts metadata from an Instagram post/reel by loading its embed page.
  /// Returns a map with 'title', 'description', 'thumbnailUrl', and 'videoDirectUrl'.
  /// Must be called from a widget context (needs WebView).
  static Future<Map<String, String>> extract(
    BuildContext context,
    String videoId,
    String originalUrl,
  ) async {
    final completer = Completer<Map<String, String>>();
    
    // Show a tiny overlay with hidden WebView to extract metadata
    final overlay = OverlayEntry(
      builder: (context) => _HiddenWebView(
        videoId: videoId,
        onDataExtracted: (data) {
          if (!completer.isCompleted) {
            completer.complete(data);
          }
        },
      ),
    );
    
    Overlay.of(context).insert(overlay);
    
    // Timeout after 8 seconds
    Timer(const Duration(seconds: 12), () {
      if (!completer.isCompleted) {
        completer.complete({
          'title': 'Instagram Gönderi',
          'description': '',
          'thumbnailUrl': '',
          'videoDirectUrl': '',
        });
      }
    });
    
    final result = await completer.future;
    overlay.remove();
    return result;
  }
}

class _HiddenWebView extends StatefulWidget {
  final String videoId;
  final Function(Map<String, String>) onDataExtracted;

  const _HiddenWebView({
    required this.videoId,
    required this.onDataExtracted,
  });

  @override
  State<_HiddenWebView> createState() => _HiddenWebViewState();
}

class _HiddenWebViewState extends State<_HiddenWebView> {
  late final WebViewController _controller;
  bool _extracted = false;

  @override
  void initState() {
    super.initState();
    
    final embedUrl = 'https://www.instagram.com/p/${widget.videoId}/embed/captioned/';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
      ..addJavaScriptChannel(
        'MetadataChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (!_extracted) {
            _extracted = true;
            try {
              // Parse the JSON message from JS
              final parts = message.message.split('|||');
              widget.onDataExtracted({
                'title': parts.length > 0 && parts[0].isNotEmpty ? parts[0] : 'Instagram Gönderi',
                'description': parts.length > 1 ? parts[1] : '',
                'thumbnailUrl': parts.length > 2 ? parts[2] : '',
                'videoDirectUrl': parts.length > 3 ? parts[3] : '',
              });
            } catch (e) {
              widget.onDataExtracted({
                'title': 'Instagram Gönderi',
                'description': '',
                'thumbnailUrl': '',
                'videoDirectUrl': '',
              });
            }
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // Wait a moment for Instagram's JS to render, then extract
            Future.delayed(const Duration(seconds: 2), () {
              _extractMetadata();
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(embedUrl));
  }

  void _extractMetadata() {
    _controller.runJavaScript('''
      (function() {
        var title = '';
        var caption = '';
        var thumbnail = '';
        var videoUrl = '';
        
        // Try to get the caption from the embed
        var captionEl = document.querySelector('.Caption');
        if (captionEl) {
          caption = captionEl.textContent.trim();
        }
        
        // Try to get owner name
        var userEl = document.querySelector('.UsernameText');
        if (userEl) {
          title = userEl.textContent.trim();
        }
        
        // Find video URL
        var video = document.querySelector('video');
        if (video) {
          videoUrl = video.src || '';
          if (video.poster) {
            thumbnail = video.poster;
          }
        }
        
        // Try to find any alternative image (thumbnail)
        if (!thumbnail) {
          var imgs = document.querySelectorAll('img');
          for (var i = 0; i < imgs.length; i++) {
            var src = imgs[i].src;
            if (src && (src.includes('cdninstagram') || src.includes('scontent') || src.includes('fbcdn'))) {
              thumbnail = src;
              break;
            }
          }
        }
        
        // Also try background-image
        if (!thumbnail) {
          var mediaEl = document.querySelector('.EmbeddedMediaImage');
          if (mediaEl) {
            var bg = window.getComputedStyle(mediaEl).backgroundImage;
            if (bg && bg !== 'none') {
              thumbnail = bg.replace(/url\\(["']?/, '').replace(/["']?\\)/, '');
            }
          }
        }
        
        // Send back to Dart
        MetadataChannel.postMessage(title + '|||' + caption + '|||' + thumbnail + '|||' + videoUrl);
      })();
    ''');
  }

  @override
  Widget build(BuildContext context) {
    // Hidden: 1x1 pixel, off-screen
    return Positioned(
      left: -1000,
      top: -1000,
      child: SizedBox(
        width: 1,
        height: 1,
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
