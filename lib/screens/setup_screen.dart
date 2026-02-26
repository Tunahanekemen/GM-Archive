import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/library_service.dart';
import '../main.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({Key? key}) : super(key: key);

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _nameController = TextEditingController(text: 'Benim Arşivim');
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String _errorMsg = '';
  bool _obscurePassword = true;

  Future<void> _create() async {
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty) {
      setState(() => _errorMsg = 'Kütüphane adı boş olamaz.');
      return;
    }
    if (password.length < 4) {
      setState(() => _errorMsg = 'Şifre en az 4 karakter olmalı.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMsg = 'Şifreler eşleşmiyor.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    try {
      final library = await LibraryService.createLibrary(name, password);

      // Set global DB service to this library
      globalDbService.setActiveLibrary(library.id, library.accessLevel);

      if (!mounted) return;

      // Show the library code
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Kütüphane Oluşturuldu! 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Kütüphane kodun:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepPurple, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      library.code,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: library.code));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Kod kopyalandı!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '⚠️ Bu kodu kaydet!\nBaşka cihazdan giriş yapmak veya arkadaşınla paylaşmak için bu koda ihtiyacın olacak.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kaydettim, Devam Et'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      // Navigate to HomeScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = 'Hata: $e';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.video_library, size: 64, color: Colors.deepPurple),
                const SizedBox(height: 16),
                const Text(
                  'GM-Archive',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Kütüphaneni oluştur',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 32),

                // Library name
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Kütüphane Adı',
                    prefixIcon: Icon(Icons.library_books),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Owner password
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Tam Yetki Şifresi',
                    helperText: 'Okuma + yazma erişimi için',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Confirm password
                TextField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Şifreyi Onayla',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),

                if (_errorMsg.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_errorMsg, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],

                const SizedBox(height: 24),

                // Create button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _create,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Kütüphane Oluştur', style: TextStyle(fontSize: 16)),
                  ),
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Join existing library
                const Text(
                  'Zaten bir kütüphane kodun var mı?',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Kütüphaneye Katıl'),
                  onPressed: _isLoading ? null : () => _showJoinDialog(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showJoinDialog() {
    final codeController = TextEditingController();
    final passController = TextEditingController();
    String dialogError = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Kütüphaneye Katıl'),
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

                await LibraryService.setActiveLibrary(library.id);
                globalDbService.setActiveLibrary(library.id, library.accessLevel);

                if (!mounted) return;
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              },
              child: const Text('Katıl'),
            ),
          ],
        ),
      ),
    );
  }
}
