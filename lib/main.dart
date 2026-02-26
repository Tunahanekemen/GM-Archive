import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'services/library_service.dart';
import 'services/db_service.dart';
import 'firebase_options.dart';

final DatabaseService globalDbService = DatabaseService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Check if user has any library
  final isFirst = await LibraryService.isFirstLaunch();

  if (!isFirst) {
    // Load active library into DB service
    final activeLib = await LibraryService.getActiveLibrary();
    if (activeLib != null) {
      globalDbService.setActiveLibrary(activeLib.id, activeLib.accessLevel);
    }
  }

  runApp(BookmarkApp(isFirstLaunch: isFirst));
}

class BookmarkApp extends StatelessWidget {
  final bool isFirstLaunch;
  const BookmarkApp({Key? key, required this.isFirstLaunch}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GM-Archive',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: isFirstLaunch ? const SetupScreen() : const HomeScreen(),
    );
  }
}
