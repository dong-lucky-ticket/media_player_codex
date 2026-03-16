import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/player_controller.dart';
import 'repositories/library_repository.dart';
import 'services/audio_import_service.dart';
import 'services/player_audio_handler.dart';
import 'ui/screens/bootstrap_screen.dart';

Future<void> main() async {
  // Ensure Flutter engine bindings are ready before any plugin or platform call runs.
  // 确保在执行任何插件或平台调用前，Flutter 引擎绑定已经完成初始化。
  WidgetsFlutterBinding.ensureInitialized();

  final repository = LibraryRepository();
  await repository.init();

  final audioHandler = await PlayerAudioHandler.init();
  final importService = AudioImportService();

  runApp(
    PlayerApp(
      repository: repository,
      audioHandler: audioHandler,
      importService: importService,
    ),
  );
}

class PlayerApp extends StatefulWidget {
  const PlayerApp({
    super.key,
    required this.repository,
    required this.audioHandler,
    required this.importService,
  });

  final LibraryRepository repository;
  final PlayerAudioHandler audioHandler;
  final AudioImportService importService;

  @override
  State<PlayerApp> createState() => _PlayerAppState();
}

class _PlayerAppState extends State<PlayerApp> with WidgetsBindingObserver {
  static const _resumeHealthCheckDelay = Duration(milliseconds: 800);
  static const _resumeHealthCheckTimeout = Duration(seconds: 2);

  late PlayerController _controller;
  Key _appKey = UniqueKey();
  bool _resumeCheckInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = _buildController();
  }

  PlayerController _buildController() {
    return PlayerController(
      repository: widget.repository,
      audioHandler: widget.audioHandler,
      importService: widget.importService,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_handleAppResumed());
    }
  }

  // Give Android a short moment to restore surfaces and service bindings before probing.
  // 给 Android 一点时间恢复渲染表面和服务绑定，再执行探测。
  Future<void> _handleAppResumed() async {
    if (_resumeCheckInFlight) return;
    _resumeCheckInFlight = true;

    try {
      await Future<void>.delayed(_resumeHealthCheckDelay);
      if (!mounted) return;

      // If the UI-side controller or audio service cannot answer in time, rebuild the app shell.
      // 如果 UI 侧控制器或音频服务无法及时响应，就重建应用外壳。
      final isHealthy = await _controller
          .performForegroundHealthCheck()
          .timeout(_resumeHealthCheckTimeout, onTimeout: () => false);
      if (!mounted || isHealthy) return;

      await _restartController();
    } finally {
      _resumeCheckInFlight = false;
    }
  }

  // Recreate the controller and widget tree instead of leaving the user on a dead black screen.
  // 通过重建控制器和组件树自救，而不是把用户留在失效的黑屏上。
  Future<void> _restartController() async {
    final oldController = _controller;
    final newController = _buildController();

    setState(() {
      _controller = newController;
      _appKey = UniqueKey();
    });

    oldController.dispose();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PlayerController>.value(
      value: _controller,
      child: MaterialApp(
        key: _appKey,
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
