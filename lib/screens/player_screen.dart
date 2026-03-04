import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import '../models/bookmark.dart';
import '../main.dart';
import '../services/instagram_api_service.dart';
import '../services/ig_metadata_extractor.dart';

class PlayerScreen extends StatefulWidget {
  final Bookmark bookmark;

  const PlayerScreen({Key? key, required this.bookmark}) : super(key: key);

  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  YoutubePlayerController? _ytController;
  VideoPlayerController? _videoController;
  bool _isLoading = true;
  bool _isPlaying = false;
  String? _errorMessage;
  bool _isRefreshing = false;
  int _retryCount = 0;
  final _dbService = globalDbService;
  late String _currentTitle;
  late String? _customTitle;

  @override
  void initState() {
    super.initState();

    if (widget.bookmark.platform == PlatformType.youtube) {
      _ytController = YoutubePlayerController(
        initialVideoId: widget.bookmark.videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
        ),
      );
      setState(() { _isLoading = false; });
    } else if (widget.bookmark.platform == PlatformType.instagram) {
      _fetchInstagramVideoUrl();
    } else if (widget.bookmark.platform == PlatformType.twitter) {
      // Twitter: if video URL exists, init video player; otherwise show static tweet
      final videoUrl = widget.bookmark.videoDirectUrl;
      if (videoUrl != null && videoUrl.isNotEmpty) {
        _initVideoPlayer(videoUrl);
      } else {
        setState(() { _isLoading = false; });
      }
    }
    
    _currentTitle = widget.bookmark.title;
    _customTitle = widget.bookmark.customTitle;
  }

  Future<void> _fetchInstagramVideoUrl() async {
    String? videoUrl = widget.bookmark.videoDirectUrl;

    if (videoUrl != null && videoUrl.isNotEmpty) {
      debugPrint('Using cached video URL for: ${widget.bookmark.videoId}');
      _initVideoPlayer(videoUrl);
      return;
    }

    debugPrint('No cached URL, fetching from API for: ${widget.bookmark.videoId}');
    try {
      final igData = await InstagramApiService.fetchMediaData(widget.bookmark.videoId);
      videoUrl = igData['videoDirectUrl'];

      if (videoUrl != null && videoUrl.isNotEmpty) {
        _initVideoPlayer(videoUrl);
      } else {
        _attemptWebViewRefresh();
      }
    } catch (e) {
      _attemptWebViewRefresh();
    }
  }

  Future<void> _attemptWebViewRefresh() async {
    if (_isRefreshing || _retryCount >= 2) return;

    if (mounted) {
      setState(() {
        _isRefreshing = true;
        _errorMessage = 'Video URL yenileniyor...';
      });
    }

    try {
      debugPrint('Attempting to refresh Instagram video URL via WebView...');
      _retryCount++;
      
      final newData = await InstagramMetadataExtractor.extract(
        context,
        widget.bookmark.videoId,
        widget.bookmark.originalUrl,
      );

      final newVideo = newData['videoDirectUrl'];
      final newThumb = newData['thumbnailUrl'];

      if (newVideo != null && newVideo.isNotEmpty) {
        debugPrint('Successfully refreshed video URL');
        
        await _dbService.updateBookmarkMediaUrls(
          widget.bookmark.id,
          newThumb ?? widget.bookmark.thumbnailUrl,
          videoDirectUrl: newVideo,
        );

        if (mounted) {
          setState(() {
            _isRefreshing = false;
            _errorMessage = null;
          });
          _initVideoPlayer(newVideo);
        }
      } else {
        if (mounted) {
          setState(() {
            _isRefreshing = false;
            _errorMessage = 'Güncel video URL\'si bulunamadı.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _errorMessage = 'Yenileme hatası: $e';
        });
      }
    }
  }

  void _initVideoPlayer(String videoUrl) {
    debugPrint('Video URL: $videoUrl');
    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          _videoController!.setVolume(1.0);
          setState(() { _isLoading = false; });
        }
      }).catchError((e) {
        debugPrint('Video player init error: $e');
        if (widget.bookmark.platform == PlatformType.instagram && _retryCount < 2) {
          // If Instagram video playback fails, it's likely expired. Try to refresh.
          debugPrint('Instagram video expired. Attempting refresh...');
          if (mounted) {
            setState(() {
              _videoController?.dispose();
              _videoController = null;
            });
            _attemptWebViewRefresh();
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Video yüklenemedi: $e';
            });
          }
        }
      });
  }

  @override
  void dispose() {
    _ytController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _launchOriginalUrl() async {
    final Uri url = Uri.parse(widget.bookmark.originalUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bağlantı açılamadı: ${widget.bookmark.originalUrl}')),
        );
      }
    }
  }

  void _shareLink() {
    final title = widget.bookmark.customTitle ?? widget.bookmark.title;
    SharePlus.instance.share(
      ShareParams(
        text: '$title\n${widget.bookmark.originalUrl}',
      ),
    );
  }

  Future<void> _downloadVideo() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video indiriliyor...')),
      );

      // Save to Downloads folder (publicly visible)
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      final dir = downloadDir;

      if (widget.bookmark.platform == PlatformType.youtube) {
        // YouTube: show quality picker then download
        final ytClient = yt.YoutubeExplode();
        try {
          final manifest = await ytClient.videos.streamsClient.getManifest(widget.bookmark.videoId);
          final streams = manifest.muxed.toList()
            ..sort((a, b) => b.videoQuality.index.compareTo(a.videoQuality.index));

          if (streams.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('İndirilebilir stream bulunamadı.')),
              );
            }
            return;
          }

          if (!mounted) return;

          // Show quality picker
          final selected = await showDialog<yt.MuxedStreamInfo>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Kalite Seç'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: streams.map((s) {
                  final sizeMB = (s.size.totalBytes / (1024 * 1024)).toStringAsFixed(1);
                  return ListTile(
                    leading: const Icon(Icons.high_quality),
                    title: Text(s.videoQualityLabel),
                    subtitle: Text('$sizeMB MB • ${s.container.name}'),
                    onTap: () => Navigator.pop(ctx, s),
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('İptal'),
                ),
              ],
            ),
          );

          if (selected == null) return; // User cancelled

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${selected.videoQualityLabel} indiriliyor...')),
            );
          }

          final fileName = 'youtube_${widget.bookmark.videoId}_${selected.videoQualityLabel}_${DateTime.now().millisecondsSinceEpoch}.mp4';
          final filePath = '${dir.path}/$fileName';

          final stream = ytClient.videos.streamsClient.get(selected);
          final file = File(filePath);
          final fileStream = file.openWrite();
          await stream.pipe(fileStream);
          await fileStream.flush();
          await fileStream.close();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Video indirildi: $fileName'),
                action: SnackBarAction(
                  label: 'AÇ',
                  onPressed: () {
                    OpenFilex.open(filePath);
                  },
                ),
              ),
            );
          }
        } finally {
          ytClient.close();
        }
      } else if (widget.bookmark.platform == PlatformType.instagram) {
        // Instagram: use cached direct URL
        final videoUrl = widget.bookmark.videoDirectUrl;
        if (videoUrl == null || videoUrl.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('İndirilebilir video URL\'si bulunamadı.')),
            );
          }
          return;
        }
        final fileName = 'instagram_${widget.bookmark.videoId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final filePath = '${dir.path}/$fileName';
        final response = await http.get(Uri.parse(videoUrl));
        await File(filePath).writeAsBytes(response.bodyBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video indirildi: $fileName'),
              action: SnackBarAction(
                label: 'AÇ',
                onPressed: () {
                  OpenFilex.open(filePath);
                },
              ),
            ),
          );
        }
      } else if (widget.bookmark.platform == PlatformType.twitter) {
        // Twitter: use cached direct URL
        final videoUrl = widget.bookmark.videoDirectUrl;
        if (videoUrl == null || videoUrl.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bu tweet\'te indirilebilir video yok.')),
            );
          }
          return;
        }
        final fileName = 'x_${widget.bookmark.videoId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final filePath = '${dir.path}/$fileName';
        final response = await http.get(Uri.parse(videoUrl));
        await File(filePath).writeAsBytes(response.bodyBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video indirildi: $fileName'),
              action: SnackBarAction(
                label: 'AÇ',
                onPressed: () {
                  OpenFilex.open(filePath);
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İndirme hatası: $e')),
        );
      }
    }
  }

  Widget _buildInstagramPlayer() {
    if (_isLoading) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.6,
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Video yükleniyor...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        height: 300,
        color: Colors.grey[900],
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Instagram\'da Aç'),
                onPressed: _launchOriginalUrl,
              ),
            ],
          ),
        ),
      );
    }

    if (_videoController != null && _videoController!.value.isInitialized) {
      return Column(
        children: [
          // Video with play/pause overlay
          GestureDetector(
            onTap: () {
              setState(() {
                if (_videoController!.value.isPlaying) {
                  _videoController!.pause();
                  _isPlaying = false;
                } else {
                  _videoController!.play();
                  _isPlaying = true;
                }
              });
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
                if (!_isPlaying)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
                  ),
              ],
            ),
          ),
          // Progress bar
          VideoProgressIndicator(
            _videoController!,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: Color(0xFFE1306C), // Instagram pink
              bufferedColor: Colors.white24,
              backgroundColor: Colors.grey,
            ),
          ),
        ],
      );
    }

    return const Center(child: Text("Oynatıcı Yüklenemedi"));
  }

  Widget _buildPlayer() {
    if (widget.bookmark.platform == PlatformType.youtube && _ytController != null) {
      if (widget.bookmark.type == VideoType.shorts) {
        return Center(
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: YoutubePlayer(
              controller: _ytController!,
              showVideoProgressIndicator: true,
            ),
          ),
        );
      } else {
        return YoutubePlayer(
          controller: _ytController!,
          showVideoProgressIndicator: true,
        );
      }
    } else if (widget.bookmark.platform == PlatformType.instagram) {
      return _buildInstagramPlayer();
    } else if (widget.bookmark.platform == PlatformType.twitter) {
      return _buildTwitterContent();
    }
    return const Center(child: Text("Oynatıcı Yüklenemedi"));
  }

  Widget _buildTwitterContent() {
    // If video exists and player is initialized, show video player (reuse Instagram player UI)
    if (_videoController != null && _videoController!.value.isInitialized) {
      return Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                if (_videoController!.value.isPlaying) {
                  _videoController!.pause();
                  _isPlaying = false;
                } else {
                  _videoController!.play();
                  _isPlaying = true;
                }
              });
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
                if (!_isPlaying)
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
                  ),
              ],
            ),
          ),
          VideoProgressIndicator(
            _videoController!,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: Color(0xFF1DA1F2), // X/Twitter blue
              bufferedColor: Colors.white24,
              backgroundColor: Colors.grey,
            ),
          ),
        ],
      );
    }

    if (_isLoading) {
      return Container(
        height: 200,
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // Static tweet: show thumbnail image if available
    if (widget.bookmark.thumbnailUrl.isNotEmpty) {
      return Image.network(
        widget.bookmark.thumbnailUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          height: 200,
          color: Colors.grey[900],
          child: const Center(
            child: Icon(Icons.image_not_supported, color: Colors.white38, size: 48),
          ),
        ),
      );
    }

    // No media at all
    return Container(
      height: 120,
      color: Colors.grey[900],
      child: const Center(
        child: Icon(Icons.article, color: Colors.white24, size: 48),
      ),
    );
  }

  /// Builds description text with clickable URLs
  Widget _buildDescriptionText(String text) {
    final urlRegex = RegExp(
      r'(https?://[^\s<>\"\)]+)',
      caseSensitive: false,
    );

    final matches = urlRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(text, style: const TextStyle(fontSize: 14));
    }

    List<InlineSpan> spans = [];
    int lastEnd = 0;

    for (var match in matches) {
      // Text before URL
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(fontSize: 14),
        ));
      }
      // Clickable URL
      final url = match.group(0)!;
      spans.add(WidgetSpan(
        child: GestureDetector(
          onTap: () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Text(
            url,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ));
      lastEnd = match.end;
    }

    // Remaining text after last URL
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(fontSize: 14),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  void _showEditTitleDialog() {
    final controller = TextEditingController(text: _customTitle ?? _currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Başlığı Düzenle'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Yeni video başlığı',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          minLines: 1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                _dbService.updateBookmarkTitle(widget.bookmark.id, newTitle);
                setState(() {
                  _customTitle = newTitle;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookmark.platform.name.toUpperCase()),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Paylaş',
            onPressed: _shareLink,
          ),
          if (widget.bookmark.videoDirectUrl != null && widget.bookmark.videoDirectUrl!.isNotEmpty ||
              widget.bookmark.platform == PlatformType.youtube)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'İndir',
              onPressed: _downloadVideo,
            ),
          IconButton(
            icon: Icon(
              widget.bookmark.platform == PlatformType.twitter
                  ? Icons.open_in_new
                  : Icons.open_in_new,
            ),
            tooltip: widget.bookmark.platform == PlatformType.twitter
                ? 'X\'te Aç'
                : 'Orijinale Git',
            onPressed: _launchOriginalUrl,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPlayer(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_customTitle != null && _customTitle!.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _customTitle!,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: _showEditTitleDialog,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentTitle,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.grey),
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _currentTitle,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: _showEditTitleDialog,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    "Açıklama:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (widget.bookmark.description.isNotEmpty)
                    _buildDescriptionText(widget.bookmark.description)
                  else
                    const Text(
                      'Açıklama yok',
                      style: TextStyle(fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
