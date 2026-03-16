import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/player_controller.dart';
import 'repositories/library_repository.dart';
import 'services/audio_import_service.dart';
import 'services/player_audio_handler.dart';
import 'ui/screens/bootstrap_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize persistent dependencies before building the widget tree.
  // 在构建组件树之前先初始化持久化依赖。
  final repository = LibraryRepository();
  await repository.init();

  final audioHandler = await PlayerAudioHandler.init();
  final importService = AudioImportService();

  final controller = PlayerController(
    repository: repository,
    audioHandler: audioHandler,
    importService: importService,
  );

  // BootstrapScreen will finish controller initialization and decide when HomeScreen can appear.
  // BootstrapScreen 会完成控制器初始化，并决定何时展示 HomeScreen。
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
        title: '本地音频播放器',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const BootstrapScreen(),
      ),
    );
  }
}
