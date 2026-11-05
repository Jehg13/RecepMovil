import 'dart:async';

import 'package:flutter/material.dart';

enum AppFeedbackType { success, error, warning, info }

abstract final class AppFeedback {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    AppFeedbackType type = AppFeedbackType.info,
    String? title,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _timer?.cancel();
    _entry?.remove();
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.paddingOf(context).top + 68,
        left: 14,
        right: 14,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, progress, child) => Transform.translate(
            offset: Offset(0, -12 * (1 - progress)),
            child: Opacity(opacity: progress, child: child),
          ),
          child: _FeedbackCard(message: message, type: type, title: title),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(const Duration(seconds: 4), () {
      if (_entry == entry) {
        entry.remove();
        _entry = null;
        _timer = null;
      }
    });
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.message,
    required this.type,
    required this.title,
  });

  final String message;
  final AppFeedbackType type;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final (defaultLabel, icon, accent) = switch (type) {
      AppFeedbackType.success => (
        'Listo',
        Icons.check_circle_rounded,
        const Color(0xFF53D6B0),
      ),
      AppFeedbackType.error => (
        'Ocurrió un problema',
        Icons.error_rounded,
        const Color(0xFFFF7189),
      ),
      AppFeedbackType.warning => (
        'Aviso',
        Icons.warning_amber_rounded,
        const Color(0xFFFFC56E),
      ),
      AppFeedbackType.info => (
        'Información',
        Icons.info_rounded,
        const Color(0xFF73BEFF),
      ),
    };

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF101A2D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: .48)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF020817).withValues(alpha: 0.48),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: .24)),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title ?? defaultLabel,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE7EEFA),
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Cerrar aviso',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                AppFeedback._timer?.cancel();
                AppFeedback._entry?.remove();
                AppFeedback._entry = null;
                AppFeedback._timer = null;
              },
              icon: const Icon(Icons.close_rounded, size: 17),
              color: const Color(0xFF9EABC0),
            ),
          ],
        ),
      ),
    );
  }
}
