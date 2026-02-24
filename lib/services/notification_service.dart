import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static OverlayEntry? _currentNotification;

  static void showNotification(
    BuildContext context, {
    required String message,
    String? title,
    IconData? icon,
    Color? backgroundColor,
    Color? textColor,
    Duration duration = const Duration(seconds: 4),
    NotificationType type = NotificationType.info,
  }) {
    // Remove any existing notification first
    _dismissCurrentNotification();

    final overlay = Overlay.of(context);

    // Create the notification overlay
    final overlayEntry = OverlayEntry(
      builder: (context) => _NotificationWidget(
        message: message,
        title: title,
        icon: icon ?? _getIconForType(type),
        backgroundColor: backgroundColor ?? _getBackgroundColorForType(context, type),
        textColor: textColor ?? _getTextColorForType(context, type),
        onDismiss: () => _dismissCurrentNotification(),
      ),
    );

    _currentNotification = overlayEntry;
    overlay.insert(overlayEntry);

    // Auto-dismiss after duration
    Future.delayed(duration, () {
      if (_currentNotification == overlayEntry) {
        _dismissCurrentNotification();
      }
    });

    // Add haptic feedback
    HapticFeedback.lightImpact();
  }

  static void _dismissCurrentNotification() {
    _currentNotification?.remove();
    _currentNotification = null;
  }

  // Convenience methods for common notification types
  static void showSuccess(BuildContext context, String message, {String? title}) {
    showNotification(
      context,
      message: message,
      title: title,
      type: NotificationType.success,
    );
  }

  static void showError(BuildContext context, String message, {String? title}) {
    showNotification(
      context,
      message: message,
      title: title,
      type: NotificationType.error,
    );
  }

  static void showWarning(BuildContext context, String message, {String? title}) {
    showNotification(
      context,
      message: message,
      title: title,
      type: NotificationType.warning,
    );
  }

  static void showInfo(BuildContext context, String message, {String? title}) {
    showNotification(
      context,
      message: message,
      title: title,
      type: NotificationType.info,
    );
  }

  static IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.error:
        return Icons.error;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.info:
        return Icons.info;
    }
  }

  static Color _getBackgroundColorForType(BuildContext context, NotificationType type) {
    final theme = Theme.of(context);
    switch (type) {
      case NotificationType.success:
        return Colors.green.shade700;
      case NotificationType.error:
        return Colors.red.shade700;
      case NotificationType.warning:
        return Colors.orange.shade700;
      case NotificationType.info:
        return theme.colorScheme.primaryContainer;
    }
  }

  static Color _getTextColorForType(BuildContext context, NotificationType type) {
    final theme = Theme.of(context);
    switch (type) {
      case NotificationType.success:
      case NotificationType.error:
      case NotificationType.warning:
        return Colors.white;
      case NotificationType.info:
        return theme.colorScheme.onPrimaryContainer;
    }
  }
}

enum NotificationType {
  success,
  error,
  warning,
  info,
}

class _NotificationWidget extends StatefulWidget {
  final String message;
  final String? title;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onDismiss;

  const _NotificationWidget({
    required this.message,
    this.title,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.onDismiss,
  });

  @override
  State<_NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<_NotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 400,
                minWidth: 300,
              ),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      color: widget.textColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.title != null) ...[
                            Text(
                              widget.title!,
                              style: TextStyle(
                                color: widget.textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            widget.message,
                            style: TextStyle(
                              color: widget.textColor.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _dismiss,
                      icon: Icon(
                        Icons.close,
                        color: widget.textColor.withValues(alpha: 0.7),
                        size: 18,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
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