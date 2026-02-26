import 'package:flutter/material.dart';
import '../models/bookmark.dart';
import '../services/link_parser.dart';
import '../services/metadata_service.dart';
import '../services/ig_metadata_extractor.dart';
import '../main.dart';

class AddBookmarkDialog extends StatefulWidget {
  const AddBookmarkDialog({Key? key}) : super(key: key);

  @override
  _AddBookmarkDialogState createState() => _AddBookmarkDialogState();
}

class _AddBookmarkDialogState extends State<AddBookmarkDialog> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _customTitleController = TextEditingController();
  final _dbService = globalDbService;
  bool _isLoading = false;
  String _errorMsg = '';
  String _statusMsg = '';

  Future<void> _processUrl() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
      _statusMsg = 'Link analiz ediliyor...';
    });

    String url = _urlController.text.trim();
    String customTitle = _customTitleController.text.trim();
    
    if (url.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMsg = 'Lütfen bir link girin.';
        _statusMsg = '';
      });
      return;
    }

    try {
      ParseResult parsed = LinkParser.parse(url);

      if (parsed.platform == PlatformType.unknown || parsed.type == VideoType.unknown || parsed.videoId.isEmpty) {
        throw Exception('Geçersiz link. YouTube, Instagram veya X linki olduğundan emin olun.');
      }

      Map<String, String> metadata;

      setState(() {
        if (parsed.platform == PlatformType.instagram) {
          _statusMsg = 'Instagram verisi çekiliyor...';
        } else if (parsed.platform == PlatformType.twitter) {
          _statusMsg = 'X (Twitter) verisi çekiliyor...';
        } else {
          _statusMsg = 'YouTube verisi çekiliyor...';
        }
      });

      // Fetch metadata (for Instagram this tries dual-API fallback)
      metadata = await MetadataFetcher.fetchMetadata(url, parsed);

      // If Instagram APIs both failed (empty title), try WebView scraping
      if (parsed.platform == PlatformType.instagram && 
          (metadata['title'] ?? '').isEmpty) {
        setState(() {
          _statusMsg = 'API başarısız, WebView ile deneniyor...';
        });
        final webviewData = await InstagramMetadataExtractor.extract(
          context,
          parsed.videoId,
          url,
        );
        // Merge: use WebView data for missing fields, keep API video URL if available
        metadata = {
          'title': (webviewData['title'] ?? '').isNotEmpty ? webviewData['title']! : 'Instagram Gönderi',
          'description': (webviewData['description'] ?? '').isNotEmpty ? webviewData['description']! : metadata['description'] ?? '',
          'thumbnailUrl': (webviewData['thumbnailUrl'] ?? '').isNotEmpty ? webviewData['thumbnailUrl']! : metadata['thumbnailUrl'] ?? '',
          'videoDirectUrl': metadata['videoDirectUrl'] ?? '',
        };
      }

      // Check for duplicate before saving
      final isDuplicate = await _dbService.isDuplicate(parsed.videoId);
      if (isDuplicate) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Bu video zaten kayıtlı!';
          _statusMsg = '';
        });
        return;
      }

      Bookmark newBookmark = Bookmark(
        id: '', // Firestore auto-generates
        originalUrl: url,
        platform: parsed.platform,
        type: parsed.type,
        videoId: parsed.videoId,
        title: (metadata['title'] ?? '').isNotEmpty ? metadata['title']! : 'Bilinmeyen Başlık',
        customTitle: customTitle.isNotEmpty ? customTitle : null,
        description: metadata['description'] ?? '',
        thumbnailUrl: metadata['thumbnailUrl'] ?? '',
        videoDirectUrl: (metadata['videoDirectUrl'] ?? '').isNotEmpty ? metadata['videoDirectUrl'] : null,
        isStarred: false,
        addedAt: DateTime.now(),
      );

      setState(() {
        _statusMsg = 'Kaydediliyor...';
      });

      await _dbService.addBookmark(newBookmark);

      if (mounted) {
        Navigator.pop(context, true); // Success
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = 'Hata: $e';
        _statusMsg = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni Link Ekle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              hintText: 'YouTube, Instagram veya X linkini yapıştırın',
              border: OutlineInputBorder(),
            ),
            maxLines: null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _customTitleController,
            decoration: const InputDecoration(
              hintText: 'İsteğe bağlı özel başlık',
              border: OutlineInputBorder(),
            ),
          ),
          if (_statusMsg.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(_statusMsg, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
          if (_errorMsg.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_errorMsg, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _processUrl,
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Kaydet'),
        ),
      ],
    );
  }
}
