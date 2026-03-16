import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/player_controller.dart';
import 'repositories/library_repository.dart';
import 'services/audio_import_service.dart';
import 'services/player_audio_handler.dart';
import 'ui/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The repository and audio handler must be ready before the widget tree starts,
  // 必须先完成仓库和音频处理器初始化，再启动组件树，
  // otherwise the first frame may render against incomplete persisted state.
  // 否则首帧可能会基于不完整的持久化状态渲染。
  final repository = LibraryRepository();
  await repository.init();

  final audioHandler = await PlayerAudioHandler.init();
  final importService = AudioImportService();

  final controller = PlayerController(
    repository: repository,
    audioHandler: audioHandler,
    importService: importService,
  );

  runApp(PlayerApp(controller: controller));
  // App startup should not be blocked by state restoration and stream wiring.
  // 应用启动不应被状态恢复和流订阅绑定阻塞。
  unawaited(controller.init());
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
        home: const HomeScreen(),
      ),
    );
  }
}
