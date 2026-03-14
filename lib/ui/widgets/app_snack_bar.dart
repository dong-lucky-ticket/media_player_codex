import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const _kAppSnackBarDisplayDuration = Duration(milliseconds: 3200);
const _kAppSnackBarTransitionDuration = Duration(milliseconds: 220);
const _kAppSnackBarMiniPlayerGap = 4.0;
final ValueNotifier<double> _kZeroOverlayInset = ValueNotifier<double>(0);
final GlobalKey<_AppSnackBarOverlayState> _appSnackBarKey =
    GlobalKey<_AppSnackBarOverlayState>();
_ActiveAppSnackBar? _activeAppSnackBar;

class AppOverlayInset extends InheritedNotifier<ValueNotifier<double>> {
  const AppOverlayInset({
    super.key,
    required ValueNotifier<double> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ValueNotifier<double>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppOverlayInset>()
        ?.notifier;
  }
}

void showAppSnackBar(
  BuildContext context, {
  required String message,
  required bool isError,
  String? actionLabel,
  VoidCallback? onAction,
  double bottomOffset = 0,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _activeAppSnackBar?.dismiss(immediate: true);

  final overlayInset = AppOverlayInset.maybeOf(context) ?? _kZeroOverlayInset;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _AppSnackBarOverlay(
      key: _appSnackBarKey,
      message: message,
      isError: isError,
      actionLabel: actionLabel,
      onAction: onAction,
      bottomOffset: bottomOffset,
      overlayInset: overlayInset,
      onDismissed: () {
        if (identical(_activeAppSnackBar?.entry, entry)) {
          _activeAppSnackBar = null;
        }
        entry.remove();
      },
    ),
  );

  _activeAppSnackBar = _ActiveAppSnackBar(entry);
  overlay.insert(entry);
}

class _ActiveAppSnackBar {
  const _ActiveAppSnackBar(this.entry);

  final OverlayEntry entry;

  void dismiss({bool immediate = false}) {
    if (!entry.mounted) return;
    _appSnackBarKey.currentState?.dismiss(immediate: immediate);
  }
}

class _AppSnackBarOverlay extends StatefulWidget {
  const _AppSnackBarOverlay({
    super.key,
    required this.message,
    required this.isError,
    required this.actionLabel,
    required this.onAction,
    required this.bottomOffset,
    required this.overlayInset,
    required this.onDismissed,
  });

  final String message;
  final bool isError;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double bottomOffset;
  final ValueListenable<double> overlayInset;
  final VoidCallback onDismissed;

  @override
  State<_AppSnackBarOverlay> createState() => _AppSnackBarOverlayState();
}

class _AppSnackBarOverlayState extends State<_AppSnackBarOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  Timer? _dismissTimer;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _kAppSnackBarTransitionDuration,
      reverseDuration: _kAppSnackBarTransitionDuration,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(_fadeAnimation);
    _controller.forward();
    _dismissTimer = Timer(_kAppSnackBarDisplayDuration, dismiss);
  }

  Future<void> dismiss({bool immediate = false}) async {
    if (_isClosing) return;
    _isClosing = true;
    _dismissTimer?.cancel();
    if (!immediate && mounted) {
      await _controller.reverse();
    }
    if (mounted) {
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isError
        ? const Color(0xFFFDECEC)
        : const Color(0xFFEAF6F1);
    final borderColor = widget.isError
        ? const Color(0xFFE4B7B7)
        : const Color(0xFFB7D8C9);
    final foregroundColor = widget.isError
        ? const Color(0xFF7A1F1F)
        : const Color(0xFF1E5B43);
    final actionBackgroundColor = widget.isError
        ? const Color(0xFFF7D8D8)
        : const Color(0xFFD6ECDF);
    final actionBorderColor = widget.isError
        ? const Color(0xFFD99B9B)
        : const Color(0xFFA3CFBB);
    final icon = widget.isError
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;
    final hasAction = widget.actionLabel != null && widget.onAction != null;

    return ValueListenableBuilder<double>(
      valueListenable: widget.overlayInset,
      builder: (context, overlayInset, _) {
        return Positioned(
          left: 12,
          right: 12,
          bottom: 12 + widget.bottomOffset + overlayInset + (overlayInset > 0 ? _kAppSnackBarMiniPlayerGap : 0),
          child: SafeArea(
            top: false,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: double.infinity,
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
                                widget.message,
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
                                  widget.onAction?.call();
                                  dismiss();
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
                                child: Text(widget.actionLabel!),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}



