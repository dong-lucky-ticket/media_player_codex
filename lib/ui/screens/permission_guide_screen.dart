import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../controllers/player_controller.dart';
import '../../services/audio_import_service.dart';

class PermissionGuideScreen extends StatelessWidget {
  const PermissionGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlayerController>();
    final state = controller.permissionState;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('权限引导')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        children: [
          _buildStatusCard(context, state),
          const SizedBox(height: 12),
          _buildMissingPermissionsCard(context, state),
          const SizedBox(height: 12),
          _buildActionCard(context, controller),
          if (controller.isBusy) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: scheme.surface.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, PermissionGuideState state) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ok = state.scanAvailable;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: ok
                        ? scheme.secondaryContainer.withOpacity(0.72)
                        : const Color(0xFFFFE6D8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    ok ? Icons.verified_user_outlined : Icons.lock_outline_rounded,
                    size: 20,
                    color: ok
                        ? scheme.onSecondaryContainer
                        : const Color(0xFF9A4F2B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前状态',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ok ? '自动扫描可用' : '自动扫描不可用',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ok ? const Color(0xFF1E5B43) : const Color(0xFF8D5A43),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              state.summary,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.45,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingPermissionsCard(BuildContext context, PermissionGuideState state) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '缺失权限',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (state.missingPermissions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.outlineVariant.withOpacity(0.22)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '当前没有缺失权限，可以直接返回继续使用。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.4,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...state.missingPermissions.map(
                (permission) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceVariant.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: scheme.outlineVariant.withOpacity(0.22)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: scheme.outlineVariant.withOpacity(0.24)),
                          ),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _permissionLabel(permission),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '用于访问本地音频文件与播放通知控制。',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  height: 1.4,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, PlayerController controller) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '权限操作',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: controller.isBusy ? null : controller.requestPermissionsFromGuide,
                icon: const Icon(Icons.verified_user_outlined, size: 18),
                label: const Text('重新申请权限'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  elevation: 0,
                  backgroundColor: scheme.secondaryContainer.withOpacity(0.6),
                  foregroundColor: scheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: controller.openSystemSettings,
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('打开系统设置'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  foregroundColor: scheme.onSurface,
                  side: BorderSide(color: scheme.outlineVariant.withOpacity(0.26)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: controller.refreshPermissionState,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('刷新权限状态'),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  foregroundColor: scheme.onSurfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
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
