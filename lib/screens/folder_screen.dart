import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/bookmark.dart';
import '../models/folder.dart';
import '../main.dart';
import '../widgets/bookmark_thumbnail.dart';
import 'player_screen.dart';

class FolderScreen extends StatefulWidget {
  final Folder folder;
  final int platformFilter; // 0: All, 1: YouTube, 2: Instagram
  const FolderScreen({Key? key, required this.folder, this.platformFilter = 0}) : super(key: key);

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  final _dbService = globalDbService;
  late String _folderName;

  @override
  void initState() {
    super.initState();
    _folderName = widget.folder.name;
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _folderName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Klasör Adını Düzenle'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Klasör adı',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                _dbService.renameFolder(widget.folder.id, newName);
                setState(() => _folderName = newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFolder() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Klasörü Sil'),
        content: const Text(
          'Klasör silinecek ve içindeki videolar ana listeye geri dönecek. Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _dbService.deleteFolder(widget.folder.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _removeFromFolder(String bookmarkId) {
    _dbService.removeBookmarkFromFolder(bookmarkId, widget.folder.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _dbService.isReadOnly ? null : _showRenameDialog,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _folderName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!_dbService.isReadOnly) ...[const SizedBox(width: 6), const Icon(Icons.edit, size: 16)],
            ],
          ),
        ),
        actions: [
          if (!_dbService.isReadOnly)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Klasörü Sil',
              onPressed: _confirmDeleteFolder,
            ),
        ],
      ),
      body: StreamBuilder<List<Bookmark>>(
        stream: _dbService.getBookmarks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          List<Bookmark> bookmarks = (snapshot.data ?? [])
              .where((b) => b.folderId == widget.folder.id)
              .toList();

          // Apply platform filter
          if (widget.platformFilter == 1) {
            bookmarks = bookmarks
                .where((b) => b.platform == PlatformType.youtube)
                .toList();
          } else if (widget.platformFilter == 2) {
            bookmarks = bookmarks
                .where((b) => b.platform == PlatformType.instagram)
                .toList();
          }

          if (bookmarks.isEmpty) {
            return const Center(
              child: Text('Bu klasörde video bulunmuyor.'),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.56,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: bookmarks.length,
            itemBuilder: (context, index) {
              final bookmark = bookmarks[index];
              final hasCustomTitle =
                  bookmark.customTitle != null && bookmark.customTitle!.isNotEmpty;

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlayerScreen(bookmark: bookmark),
                    ),
                  );
                },
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      bookmark.thumbnailUrl.isNotEmpty
                          ? BookmarkThumbnail(bookmark: bookmark)
                          : Container(
                              color: Colors.grey[900],
                              child: Center(
                                child: Icon(
                                  bookmark.platform == PlatformType.instagram
                                      ? Icons.camera_alt
                                      : Icons.video_library,
                                  size: 50,
                                  color: Colors.white24,
                                ),
                              ),
                            ),

                      // Title area at the bottom
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.black87, Colors.transparent],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasCustomTitle)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2.0),
                                  child: Text(
                                    bookmark.customTitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              Text(
                                bookmark.title,
                                maxLines: hasCustomTitle ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: hasCustomTitle
                                      ? Colors.white70
                                      : Colors.white,
                                  fontWeight: hasCustomTitle
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                  fontSize: hasCustomTitle ? 11 : 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        bookmark.platform ==
                                                PlatformType.youtube
                                            ? FontAwesomeIcons.youtube
                                            : FontAwesomeIcons.instagram,
                                        color: bookmark.platform ==
                                                PlatformType.youtube
                                            ? Colors.red
                                            : Colors.pinkAccent,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        bookmark.type.name.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                  GestureDetector(
                                    onTap: () =>
                                        _removeFromFolder(bookmark.id),
                                    child: const Tooltip(
                                      message: 'Klasörden Çıkar',
                                      child: Icon(
                                        Icons.folder_off_outlined,
                                        color: Colors.white54,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
