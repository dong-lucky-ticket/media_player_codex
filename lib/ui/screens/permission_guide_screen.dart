import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../controllers/player_controller.dart';

class PermissionGuideScreen extends StatelessWidget {
  const PermissionGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlayerController>();
    final state = controller.permissionState;

    return Scaffold(
      appBar: AppBar(title: const Text('权限引导')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('当前状态', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(state.summary),
                  const SizedBox(height: 10),
                  Text(
                    state.scanAvailable ? '自动扫描可用' : '自动扫描不可用',
                    style: TextStyle(
                      color: state.scanAvailable
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('缺失权限', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (state.missingPermissions.isEmpty)
            const ListTile(
              leading: Icon(Icons.check_circle_outline),
              title: Text('没有缺失权限'),
            )
          else
            ...state.missingPermissions.map(
              (permission) => ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(_permissionLabel(permission)),
                subtitle: const Text('用于访问本地音频与后台通知控制'),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: controller.isBusy ? null : controller.requestPermissionsFromGuide,
            icon: const Icon(Icons.verified_user),
            label: const Text('重新申请权限'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: controller.openSystemSettings,
            icon: const Icon(Icons.settings),
            label: const Text('打开系统设置'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: controller.refreshPermissionState,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新权限状态'),
          ),
          if (controller.isBusy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  static String _permissionLabel(Permission permission) {
    if (permission == Permission.audio) return '音频媒体权限';
    if (permission == Permission.notification) return '通知权限';
    if (permission == Permission.storage) return '存储读取权限';
    return permission.toString();
  }
}
