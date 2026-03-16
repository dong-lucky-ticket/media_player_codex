import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/player_controller.dart';
import 'home_screen.dart';

class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key});

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  Object? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _startInitialization();
  }

  // Keep the bootstrap page responsible only for startup orchestration and error handling.
  // 启动页只负责启动编排和错误处理，不承载业务页面逻辑。
  Future<void> _startInitialization() async {
    if (mounted) {
      setState(() {
        _error = null;
        _ready = false;
      });
    }

    try {
      // Wait until controller startup finishes before allowing HomeScreen to render.
      // 等待控制器启动完成后，再允许 HomeScreen 渲染。
      await context.read<PlayerController>().init();
      if (!mounted) return;
      setState(() {
        _ready = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Once startup succeeds, this page immediately hands off to HomeScreen.
    // 启动成功后，这个页面会立即切换到 HomeScreen。
    if (_ready) {
      return const HomeScreen();
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  color: scheme.surface.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: scheme.outlineVariant.withOpacity(0.32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        _error == null
                            ? Icons.library_music_rounded
                            : Icons.error_outline_rounded,
                        size: 30,
                        color: _error == null
                            ? scheme.onSecondaryContainer
                            : scheme.error,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _error == null ? '正在初始化播放器' : '初始化失败',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _error == null
                          ? '正在读取设置、恢复播放状态并准备媒体库，请稍候。'
                          : '启动阶段出现异常。你可以重试初始化，避免首页进入半完成状态。',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_error == null)
                      const CircularProgressIndicator()
                    else
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _startInitialization,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('重试初始化'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
