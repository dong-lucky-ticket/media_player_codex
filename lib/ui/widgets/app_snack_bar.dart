import 'package:flutter/material.dart';

void showAppSnackBar(
  BuildContext context, {
  required String message,
  required bool isError,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final scheme = Theme.of(context).colorScheme;
  final messenger = ScaffoldMessenger.of(context);

  final backgroundColor = isError
      ? const Color(0xFFFDECEC)
      : const Color(0xFFEAF6F1);
  final borderColor = isError
      ? const Color(0xFFE4B7B7)
      : const Color(0xFFB7D8C9);
  final foregroundColor = isError
      ? const Color(0xFF7A1F1F)
      : const Color(0xFF1E5B43);
  final icon = isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      content: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        child: Row(
          children: [
            Icon(icon, size: 20, color: foregroundColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
      action: actionLabel == null || onAction == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              textColor: isError ? scheme.error : scheme.primary,
              onPressed: onAction,
            ),
    ),
  );
}
