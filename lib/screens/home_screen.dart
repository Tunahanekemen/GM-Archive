import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/bookmark.dart';
import '../models/folder.dart';
import '../models/library.dart';
import '../main.dart';
import '../services/library_service.dart';
import '../widgets/add_bookmark_dialog.dart';
import 'player_screen.dart';
import 'folder_screen.dart';
import 'setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _dbService = globalDbService;

  int _selectedIndex = 0; // 0: All, 1: YouTube, 2: Instagram, 3: X
  bool _isSearchActive = false;
  String _searchQuery = '';
  bool _sortDescending = true;
  final TextEditingController _searchController = TextEditingController();

  List<Library> _libraries = [];
  Library? _activeLibrary;

  @override
  void initState() {
    super.initState();
    _loadLibraries();
  }

  Future<void> _loadLibraries() async {
    final libs = await LibraryService.getSavedLibraries();
    final active = await LibraryService.getActiveLibrary();
    if (mounted) {
      setState(() {
        _libraries = libs;
        _activeLibrary = active;
      });
    }
  }

  Future<void> _switchLibrary(Library lib) async {
    await LibraryService.setActiveLibrary(lib.id);
    _dbService.setActiveLibrary(lib.id, lib.accessLevel);
    await _loadLibraries();
    if (mounted) {
      Navigator.pop(context); // close drawer
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddBookmarkDialog(),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _toggleSort() {
    setState(() {
      _sortDescending = !_sortDescending;
    });
  }

  /// Called when a bookmark is dropped on another bookmark
  void _onBookmarkDroppedOnBookmark(
    Bookmark dragged,
    Bookmark target,
    List<Folder> folders,
  ) {
    // Don't drop on itself
    if (dragged.id == target.id) return;

    // If target is already in a folder, add dragged to that folder
    if (target.folderId != null && target.folderId!.isNotEmpty) {
      _dbService.addBookmarkToFolder(dragged.id, target.folderId!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video klasöre eklendi')),
      );
      return;
    }

    // If dragged is already in a folder, add target to that folder
    if (dragged.folderId != null && dragged.folderId!.isNotEmpty) {
      _dbService.addBookmarkToFolder(target.id, dragged.folderId!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video klasöre eklendi')),
      );
      return;
    }

    // Neither is in a folder → create a new folder
    _showCreateFolderDialog(dragged, target);
  }

  void _showCreateFolderDialog(Bookmark a, Bookmark b) {
    final controller = TextEditingController(text: 'Yeni Klasör');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Klasör Oluştur'),
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
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                _dbService.createFolder(
                  name,
                  [a.id, b.id],
                  thumbnailUrl: a.thumbnailUrl.isNotEmpty
                      ? a.thumbnailUrl
                      : b.thumbnailUrl,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"$name" klasörü oluşturuldu')),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }

  /// Called when a bookmark is dropped on a folder card
  void _onBookmarkDroppedOnFolder(Bookmark dragged, Folder folder) {
    if (_dbService.isReadOnly) return;
    _dbService.addBookmarkToFolder(dragged.id, folder.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${folder.name}" klasörüne eklendi')),
    );
  }

  // ─── Drawer ───

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.video_library, size: 36, color: Colors.deepPurple),
                      if (_activeLibrary != null && _activeLibrary!.isOwner)
                        IconButton(
                          icon: const Icon(Icons.lock_reset, size: 20),
                          tooltip: 'Tam Yetki Şifresini Değiştir',
                          onPressed: () {
                            Navigator.pop(context);
                            _showChangeOwnerPasswordDialog();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('GM-Archive', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    _dbService.isReadOnly ? '👁 Misafir Modu' : '✏️ Tam Yetki',
                    style: TextStyle(
                      fontSize: 12,
                      color: _dbService.isReadOnly ? Colors.orangeAccent : Colors.greenAccent,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('KÜTÜPHANELERİM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _libraries.length,
                itemBuilder: (context, index) {
                  final lib = _libraries[index];
                  final isActive = lib.id == _activeLibrary?.id;
                  return ListTile(
                    leading: Icon(
                      Icons.library_books,
                      color: isActive ? Colors.deepPurple : Colors.grey,
                    ),
                    title: Text(
                      lib.name,
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      lib.isOwner ? 'Sahip' : 'Misafir',
                      style: TextStyle(
                        fontSize: 11,
                        color: lib.isOwner ? Colors.greenAccent : Colors.orangeAccent,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (lib.isOwner)
                          IconButton(
                            icon: const Icon(Icons.share, size: 18, color: Colors.tealAccent),
                            tooltip: 'Paylaş',
                            onPressed: () {
                              Navigator.pop(context);
                              _showShareDialog(lib);
                            },
                          ),
                        if (isActive)
                          const Icon(Icons.check_circle, color: Colors.deepPurple, size: 20),
                      ],
                    ),
                    selected: isActive,
                    onTap: isActive ? null : () => _switchLibrary(lib),
                    onLongPress: () {
                      _showRemoveLibraryDialog(lib);
                    },
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
              title: const Text('Kütüphane Ekle'),
              onTap: () {
                Navigator.pop(context);
                _showJoinLibraryDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinLibraryDialog() {
    final codeController = TextEditingController();
    final passController = TextEditingController();
    String dialogError = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Kütüphane Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Kütüphane Kodu',
                  hintText: 'Örn: GM7X2K',
                  prefixIcon: Icon(Icons.vpn_key),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Şifre',
                  helperText: 'Sahip veya misafir şifresi',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
              ),
              if (dialogError.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(dialogError, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                final code = codeController.text.trim();
                final pass = passController.text;
                if (code.isEmpty || pass.isEmpty) {
                  setDialogState(() => dialogError = 'Tüm alanları doldurun.');
                  return;
                }
                final library = await LibraryService.joinLibrary(code, pass);
                if (library == null) {
                  setDialogState(() => dialogError = 'Kod veya şifre yanlış.');
                  return;
                }
                // Auto-switch to new library
                _dbService.setActiveLibrary(library.id, library.accessLevel);
                await LibraryService.setActiveLibrary(library.id);
                await _loadLibraries();
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"${library.name}" kütüphanesi eklendi (${library.isOwner ? "Tam Yetki" : "Misafir"})')),
                  );
                }
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareDialog(Library targetLib) async {
    final code = await LibraryService.getLibraryCode(targetLib.id);
    final hasGuest = await LibraryService.hasGuestPassword(targetLib.id);
    final guestPass = hasGuest ? await LibraryService.getGuestPassword(targetLib.id) : null;

    if (!mounted) return;

    final guestPassController = TextEditingController();
    String dialogMsg = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('${targetLib.name} Paylaş'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Kütüphane Kodu:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      code ?? '???',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 3),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code ?? ''));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Kod kopyalandı!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!hasGuest) ...[
                const Text(
                  'Misafir şifresi belirle (sadece okuma):',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: guestPassController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Misafir Şifresi',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else ...[
                const Text('Misafir Şifresi:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        guestPass ?? '???',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: guestPass ?? ''));
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Misafir şifresi kopyalandı!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Expanded(
                      child: Text(
                        'Arkadaşına kodu + bu şifreyi ver\n→ Sadece okuma erişimi alacak',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 16, color: Colors.orangeAccent),
                      tooltip: 'Misafir şifresini değiştir',
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showChangeGuestPasswordDialog(targetLib);
                      },
                    ),
                  ],
                ),
              ],
              if (dialogMsg.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(dialogMsg, style: TextStyle(color: dialogMsg.contains('✅') ? Colors.green : Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kapat'),
            ),
            if (!hasGuest)
              FilledButton(
                onPressed: () async {
                  final guestPass = guestPassController.text;
                  if (guestPass.length < 4) {
                    setDialogState(() => dialogMsg = 'Şifre en az 4 karakter olmalı.');
                    return;
                  }
                  final ok = await LibraryService.setGuestPassword(targetLib.id, guestPass);
                  if (ok) {
                    setDialogState(() => dialogMsg = '✅ Misafir şifresi ayarlandı!');
                  } else {
                    setDialogState(() => dialogMsg = 'Hata oluştu.');
                  }
                },
                child: const Text('Kaydet'),
              ),
          ],
        ),
      ),
    );
  }

  void _showChangeOwnerPasswordDialog() {
    if (_activeLibrary == null) return;
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    String dialogMsg = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Şifre Değiştir'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mevcut Şifre',
                  prefixIcon: Icon(Icons.lock_open),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Yeni Şifre',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Yeni Şifre Tekrar',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              if (dialogMsg.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(dialogMsg, style: TextStyle(color: dialogMsg.contains('✅') ? Colors.green : Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                final oldPass = oldController.text;
                final newPass = newController.text;
                final confirm = confirmController.text;
                if (oldPass.isEmpty || newPass.isEmpty) {
                  setDialogState(() => dialogMsg = 'Tüm alanları doldurun.');
                  return;
                }
                if (newPass.length < 4) {
                  setDialogState(() => dialogMsg = 'Yeni şifre en az 4 karakter olmalı.');
                  return;
                }
                if (newPass != confirm) {
                  setDialogState(() => dialogMsg = 'Yeni şifreler eşleşmiyor.');
                  return;
                }
                final ok = await LibraryService.changeOwnerPassword(_activeLibrary!.id, oldPass, newPass);
                if (ok) {
                  setDialogState(() => dialogMsg = '✅ Şifre değiştirildi!');
                } else {
                  setDialogState(() => dialogMsg = 'Mevcut şifre yanlış.');
                }
              },
              child: const Text('Değiştir'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeGuestPasswordDialog(Library targetLib) {
    final newController = TextEditingController();
    String dialogMsg = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Misafir Şifresini Değiştir'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Yeni Misafir Şifresi',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              if (dialogMsg.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(dialogMsg, style: TextStyle(color: dialogMsg.contains('✅') ? Colors.green : Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                final newPass = newController.text;
                if (newPass.length < 4) {
                  setDialogState(() => dialogMsg = 'Şifre en az 4 karakter olmalı.');
                  return;
                }
                final ok = await LibraryService.setGuestPassword(targetLib.id, newPass);
                if (ok) {
                  setDialogState(() => dialogMsg = '✅ Misafir şifresi değiştirildi!');
                } else {
                  setDialogState(() => dialogMsg = 'Hata oluştu.');
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveLibraryDialog(Library lib) {
    // Prevent deleting the last library
    if (_libraries.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Son kütüphane silinemez!')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kütüphaneyi Sil'),
        content: Text(
          '"${lib.name}" kütüphanesi kalıcı olarak silinecek.\n\n'
          '⚠️ Tüm videolar ve klasörler geri alınamaz şekilde silinir!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kütüphane siliniyor...')),
              );

              final ok = await LibraryService.deleteLibraryFromFirestore(lib.id);

              if (ok) {
                // If deleted library was active, switch to first available
                if (_activeLibrary?.id == lib.id) {
                  final remaining = await LibraryService.getSavedLibraries();
                  if (remaining.isNotEmpty) {
                    final newActive = remaining.first;
                    await LibraryService.setActiveLibrary(newActive.id);
                    _dbService.setActiveLibrary(newActive.id, newActive.accessLevel);
                  }
                }
                await _loadLibraries();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"${lib.name}" silindi')),
                  );
                  setState(() {});
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Silme hatası oluştu')),
                  );
                }
              }
            },
            child: const Text('Kalıcı Olarak Sil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: true,
      child: Scaffold(
        drawer: _buildDrawer(),
        appBar: AppBar(
          title: _isSearchActive
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Başlık veya açıklamada ara...',
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                )
              : Text(_activeLibrary?.name ?? 'GM-Archive'),
          centerTitle: !_isSearchActive,
          actions: [
            IconButton(
              icon: Icon(_isSearchActive ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  if (_isSearchActive) {
                    _isSearchActive = false;
                    _searchController.clear();
                    _searchQuery = '';
                  } else {
                    _isSearchActive = true;
                  }
                });
              },
            ),
            IconButton(
              icon: Icon(
                _sortDescending ? Icons.arrow_downward : Icons.arrow_upward,
              ),
              tooltip: _sortDescending ? 'En Yeniler' : 'En Eskiler',
              onPressed: _toggleSort,
            ),
          ],
        ),
        body: StreamBuilder<List<Bookmark>>(
          stream: _dbService.getBookmarks(),
          builder: (context, bookmarkSnap) {
            return StreamBuilder<List<Folder>>(
              stream: _dbService.getFolders(),
              builder: (context, folderSnap) {
                if (bookmarkSnap.connectionState == ConnectionState.waiting ||
                    folderSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (bookmarkSnap.hasError) {
                  return Center(
                    child: Text("Hata: ${bookmarkSnap.error}"),
                  );
                }

                List<Bookmark> bookmarks = bookmarkSnap.data ?? [];
                List<Folder> folders = folderSnap.data ?? [];

                // 1. FILTER BY PLATFORM
                if (_selectedIndex == 1) {
                  bookmarks = bookmarks
                      .where((b) => b.platform == PlatformType.youtube)
                      .toList();
                } else if (_selectedIndex == 2) {
                  bookmarks = bookmarks
                      .where((b) => b.platform == PlatformType.instagram)
                      .toList();
                } else if (_selectedIndex == 3) {
                  bookmarks = bookmarks
                      .where((b) => b.platform == PlatformType.twitter)
                      .toList();
                }

                // 2. FILTER BY SEARCH
                if (_searchQuery.isNotEmpty) {
                  bookmarks = bookmarks.where((b) {
                    final titleMatch =
                        b.title.toLowerCase().contains(_searchQuery);
                    final customTitleMatch =
                        (b.customTitle?.toLowerCase() ?? '')
                            .contains(_searchQuery);
                    final descMatch =
                        b.description.toLowerCase().contains(_searchQuery);
                    return titleMatch || customTitleMatch || descMatch;
                  }).toList();
                }

                // Separate folder-less bookmarks
                final looseBookmarks =
                    bookmarks.where((b) => b.folderId == null || b.folderId!.isEmpty).toList();

                // 3. SORTING loose bookmarks
                looseBookmarks.sort((a, b) {
                  if (a.isStarred != b.isStarred) {
                    return a.isStarred ? -1 : 1;
                  }
                  if (_sortDescending) {
                    return b.addedAt.compareTo(a.addedAt);
                  } else {
                    return a.addedAt.compareTo(b.addedAt);
                  }
                });

                // Filter folders that have at least one bookmark in current filter
                final filteredFolders = folders.where((f) {
                  return bookmarks.any((b) => b.folderId == f.id);
                }).toList();

                // Total items = folders + loose bookmarks
                final totalItems =
                    filteredFolders.length + looseBookmarks.length;

                if (totalItems == 0) {
                  return const Center(
                    child: Text("Gösterilecek video bulunamadı."),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(8.0),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.56,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: totalItems,
                  itemBuilder: (context, index) {
                    // Show folders first, then loose bookmarks
                    if (index < filteredFolders.length) {
                      final folder = filteredFolders[index];
                      final folderBookmarks = bookmarks
                          .where((b) => b.folderId == folder.id)
                          .toList();
                      return _buildFolderCard(
                          folder, folderBookmarks, bookmarks);
                    } else {
                      final bookmark =
                          looseBookmarks[index - filteredFolders.length];
                      return _buildDraggableBookmarkCard(
                          bookmark, bookmarks, folders);
                    }
                  },
                );
              },
            );
          },
        ),
        floatingActionButton: _dbService.isReadOnly ? null : FloatingActionButton(
          onPressed: () => _showAddDialog(context),
          child: const Icon(Icons.add),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.all_inclusive),
              label: 'Tümü',
            ),
            BottomNavigationBarItem(
              icon: Icon(FontAwesomeIcons.youtube),
              label: 'YouTube',
            ),
            BottomNavigationBarItem(
              icon: Icon(FontAwesomeIcons.instagram),
              label: 'Instagram',
            ),
            BottomNavigationBarItem(
              icon: Icon(FontAwesomeIcons.xTwitter),
              label: 'X',
            ),
          ],
        ),
      ),
    );
  }

  // ─── Folder Card (DragTarget for bookmark drops) ───

  Widget _buildFolderCard(
    Folder folder,
    List<Bookmark> folderBookmarks,
    List<Bookmark> allBookmarks,
  ) {
    return DragTarget<Bookmark>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        // Accept if the bookmark is not already in this folder
        return data.folderId != folder.id;
      },
      onAcceptWithDetails: (details) {
        _onBookmarkDroppedOnFolder(details.data, folder);
      },
      builder: (context, candidateData, rejectedData) {
        final isHover = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: isHover
              ? (Matrix4.diagonal3Values(1.05, 1.05, 1.0))
              : Matrix4.identity(),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FolderScreen(
                    folder: folder,
                    platformFilter: _selectedIndex,
                  ),
                ),
              );
            },
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isHover
                    ? const BorderSide(color: Colors.blueAccent, width: 2)
                    : BorderSide.none,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 2x2 thumbnail grid
                  _buildFolderThumbnails(folderBookmarks),

                  // Folder overlay
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
                      child: Row(
                        children: [
                          const Icon(Icons.folder,
                              color: Colors.amber, size: 20),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              folder.name,
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
                            '${folderBookmarks.length}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFolderThumbnails(List<Bookmark> folderBookmarks) {
    final thumbs = folderBookmarks.take(4).toList();

    if (thumbs.isEmpty) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Icon(Icons.folder_open, size: 50, color: Colors.white24),
        ),
      );
    }

    if (thumbs.length == 1) {
      return thumbs[0].thumbnailUrl.isNotEmpty
          ? Image.network(thumbs[0].thumbnailUrl, fit: BoxFit.cover)
          : Container(
              color: Colors.grey[900],
              child: const Center(
                child:
                    Icon(Icons.video_library, size: 50, color: Colors.white24),
              ),
            );
    }

    // 2x2 grid
    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(4, (i) {
        if (i < thumbs.length && thumbs[i].thumbnailUrl.isNotEmpty) {
          return Image.network(thumbs[i].thumbnailUrl, fit: BoxFit.cover);
        }
        return Container(color: Colors.grey[850]);
      }),
    );
  }

  // ─── Draggable Bookmark Card ───

  Widget _buildDraggableBookmarkCard(
    Bookmark bookmark,
    List<Bookmark> allBookmarks,
    List<Folder> allFolders,
  ) {
    final hasCustomTitle =
        bookmark.customTitle != null && bookmark.customTitle!.isNotEmpty;

    return LongPressDraggable<Bookmark>(
      data: bookmark,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.4,
          height: MediaQuery.of(context).size.width * 0.4 / 0.56,
          child: Opacity(
            opacity: 0.85,
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: bookmark.thumbnailUrl.isNotEmpty
                  ? Image.network(bookmark.thumbnailUrl, fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: Icon(Icons.video_library,
                            size: 40, color: Colors.white24),
                      ),
                    ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildBookmarkCardContent(bookmark, hasCustomTitle),
      ),

      child: DragTarget<Bookmark>(
        onWillAcceptWithDetails: (details) {
          return details.data.id != bookmark.id;
        },
        onAcceptWithDetails: (details) {
          _onBookmarkDroppedOnBookmark(details.data, bookmark, allFolders);
        },
        builder: (context, candidateData, rejectedData) {
          final isHover = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: isHover
                ? (Matrix4.diagonal3Values(1.05, 1.05, 1.0))
                : Matrix4.identity(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: isHover
                    ? Border.all(color: Colors.blueAccent, width: 2.5)
                    : null,
              ),
              child: _buildBookmarkCardContent(bookmark, hasCustomTitle),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookmarkCardContent(Bookmark bookmark, bool hasCustomTitle) {
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
                ? Image.network(
                    bookmark.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[900],
                      child: Center(
                        child: Icon(
                           bookmark.platform == PlatformType.instagram
                               ? Icons.camera_alt
                               : bookmark.platform == PlatformType.twitter
                                   ? FontAwesomeIcons.xTwitter
                                   : Icons.video_library,
                           size: 50,
                           color: Colors.white24,
                         ),
                      ),
                    ),
                  )
                : Container(
                    color: Colors.grey[900],
                    child: Center(
                      child: Icon(
                        bookmark.platform == PlatformType.instagram
                            ? Icons.camera_alt
                            : bookmark.platform == PlatformType.twitter
                                ? FontAwesomeIcons.xTwitter
                                : Icons.video_library,
                        size: 50,
                        color: Colors.white24,
                      ),
                    ),
                  ),

            // Star Button
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () =>
                    _dbService.toggleStar(bookmark.id, bookmark.isStarred),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    bookmark.isStarred ? Icons.star : Icons.star_border,
                    color: bookmark.isStarred ? Colors.amber : Colors.white,
                    size: 20,
                  ),
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
                        color:
                            hasCustomTitle ? Colors.white70 : Colors.white,
                        fontWeight: hasCustomTitle
                            ? FontWeight.normal
                            : FontWeight.bold,
                        fontSize: hasCustomTitle ? 11 : 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              bookmark.platform == PlatformType.youtube
                                  ? FontAwesomeIcons.youtube
                                  : bookmark.platform == PlatformType.twitter
                                      ? FontAwesomeIcons.xTwitter
                                      : FontAwesomeIcons.instagram,
                              color:
                                  bookmark.platform == PlatformType.youtube
                                      ? Colors.red
                                      : bookmark.platform == PlatformType.twitter
                                          ? Colors.lightBlueAccent
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
                        if (!_dbService.isReadOnly)
                          GestureDetector(
                            onTap: () =>
                                _dbService.deleteBookmark(bookmark.id),
                            child: const Icon(Icons.delete,
                                color: Colors.white54, size: 18),
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
  }
}
