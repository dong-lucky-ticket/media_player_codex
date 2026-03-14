import 'package:flutter/material.dart';

void showAppSnackBar(
  BuildContext context, {
  required String message,
  required bool isError,
  String? actionLabel,
  VoidCallback? onAction,
}) {
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
  final actionBackgroundColor = isError
      ? const Color(0xFFF7D8D8)
      : const Color(0xFFD6ECDF);
  final actionBorderColor = isError
      ? const Color(0xFFD99B9B)
      : const Color(0xFFA3CFBB);
  final icon = isError
      ? Icons.error_outline_rounded
      : Icons.check_circle_outline_rounded;
  final hasAction = actionLabel != null && onAction != null;

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
            if (hasAction) ...[
              const SizedBox(width: 10),
              TextButton(
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  onAction();
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  foregroundColor: foregroundColor,
                  backgroundColor: actionBackgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: actionBorderColor),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
