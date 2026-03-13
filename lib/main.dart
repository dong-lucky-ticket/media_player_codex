import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/player_controller.dart';
import 'repositories/library_repository.dart';
import 'services/audio_import_service.dart';
import 'services/player_audio_handler.dart';
import 'ui/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repository = LibraryRepository();
  await repository.init();

  final audioHandler = await PlayerAudioHandler.init();
  final importService = AudioImportService();

  final controller = PlayerController(
    repository: repository,
    audioHandler: audioHandler,
    importService: importService,
  );
  await controller.init();

  runApp(PlayerApp(controller: controller));
}

class PlayerApp extends StatelessWidget {
  const PlayerApp({super.key, required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PlayerController>.value(
      value: controller,
      child: MaterialApp(
        title: 'Local Audio Player',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

