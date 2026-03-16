import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/player_controller.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/mini_player_bar.dart';
import 'library_screen.dart';
import 'permission_guide_screen.dart';
import 'player_screen.dart';
import 'settings_screen.dart';

const double kHomeNavigationBarHeight = 66;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  String? _dismissedMiniPlayerId;
  late final ValueNotifier<double> _bottomOverlayHeightNotifier;

  @override
  void initState() {
    super.initState();
    _bottomOverlayHeightNotifier = ValueNotifier<double>(0);
  }

  void _openPermissionGuide() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PermissionGuideScreen(),
      ),
    );
  }

  void _selectTab(int index, PlayerController controller) {
    if (index == 1) {
      unawaited(controller.restorePendingPlaybackForPlayerScreen());
    }
    setState(() {
      _currentTab = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlayerController>();
    final currentItemId = controller.currentMediaItem?.id;

    if (_dismissedMiniPlayerId != null &&
        _dismissedMiniPlayerId != currentItemId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _dismissedMiniPlayerId = null;
        });
      });
    }

    final showMiniPlayer = controller.currentMediaItem != null &&
        controller.playbackState.playing &&
        _currentTab != 1 &&
        currentItemId != _dismissedMiniPlayerId;
    final bottomOverlayHeight =
        showMiniPlayer ? kMiniPlayerBarReservedHeight : 0.0;
    final snackBarOverlayHeight =
        kHomeNavigationBarHeight + bottomOverlayHeight;
    if (_bottomOverlayHeightNotifier.value != snackBarOverlayHeight) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _bottomOverlayHeightNotifier.value = snackBarOverlayHeight;
      });
    }

    return AppOverlayInset(
      notifier: _bottomOverlayHeightNotifier,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('本地音频播放器'),
          actions: [
            IconButton(
              tooltip: '权限引导',
              onPressed: _openPermissionGuide,
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          ],
        ),
        body: IndexedStack(
          index: _currentTab,
          children: [
            LibraryScreen(
              onOpenPermissionGuide: _openPermissionGuide,
              bottomOverlayHeight: bottomOverlayHeight,
            ),
            const PlayerScreen(),
            SettingsScreen(
              bottomOverlayHeight: bottomOverlayHeight,
            ),
          ],
        ),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: kHomeNavigationBarHeight,
            labelTextStyle: MaterialStateProperty.resolveWith((states) {
              final selected = states.contains(MaterialState.selected);
              return Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.1,
                  );
            }),
            iconTheme: MaterialStateProperty.resolveWith((states) {
              final selected = states.contains(MaterialState.selected);
              return IconThemeData(size: selected ? 24 : 22);
            }),
          ),
          child: NavigationBar(
            selectedIndex: _currentTab,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            animationDuration: const Duration(milliseconds: 280),
            onDestinationSelected: (index) => _selectTab(index, controller),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.library_music), label: '音频列表'),
              NavigationDestination(
                  icon: Icon(Icons.play_circle_outline), label: '播放'),
              NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
            ],
          ),
        ),
        bottomSheet: !showMiniPlayer
            ? null
            : MiniPlayerBar(
                onOpenPlayer: () => _selectTab(1, controller),
                onClose: () {
                  setState(() {
                    _dismissedMiniPlayerId = currentItemId;
                  });
                },
              ),
      ),
    );
  }

  @override
  void dispose() {
    _bottomOverlayHeightNotifier.dispose();
    super.dispose();
  }
}
