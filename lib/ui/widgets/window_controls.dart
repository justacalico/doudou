import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WindowControls extends StatelessWidget {
  const WindowControls({super.key});

  static const MethodChannel _channel = MethodChannel('com.openlyst.doudou/window_controls');

  /// Hyprland (Wayland) doesn't support client-side minimize/maximize the way
  /// the method channel expects, so only the close button is shown there.
  static final bool _isHyprland = Platform.isLinux &&
      ((Platform.environment['XDG_CURRENT_DESKTOP'] ?? '')
          .toLowerCase()
          .contains('hyprland') ||
          (Platform.environment['HYPRLAND_INSTANCE_SIGNATURE'] ?? '').isNotEmpty);

  Future<void> _minimize() async {
    try {
      await _channel.invokeMethod('minimize');
    } catch (e) {
      debugPrint('Failed to minimize window: $e');
    }
  }

  Future<void> _maximize() async {
    try {
      await _channel.invokeMethod('maximize');
    } catch (e) {
      debugPrint('Failed to maximize window: $e');
    }
  }

  Future<void> _close() async {
    try {
      await _channel.invokeMethod('close');
    } catch (e) {
      debugPrint('Failed to close window: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS && !Platform.isLinux && !Platform.isWindows) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          if (Platform.isMacOS) ...[
            _MacOSWindowControl(
              color: Colors.red,
              onPressed: _close,
            ),
            const SizedBox(width: 8),
            _MacOSWindowControl(
              color: Colors.yellow,
              onPressed: _minimize,
            ),
            const SizedBox(width: 8),
            _MacOSWindowControl(
              color: Colors.green,
              onPressed: _maximize,
            ),
          ] else ...[
            _WindowControlButton(
              icon: Icons.close,
              onPressed: _close,
              isCloseButton: true,
            ),
            if (!_isHyprland) ...[
              const SizedBox(width: 4),
              _WindowControlButton(
                icon: Icons.crop_square,
                onPressed: _maximize,
              ),
              const SizedBox(width: 4),
              _WindowControlButton(
                icon: Icons.minimize,
                onPressed: _minimize,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MacOSWindowControl extends StatelessWidget {
  final Color color;
  final VoidCallback onPressed;

  const _MacOSWindowControl({
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.black12,
              width: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isCloseButton;

  const _WindowControlButton({
    required this.icon,
    required this.onPressed,
    this.isCloseButton = false,
  });

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.isCloseButton ? const Color(0xFFe81123) : const Color(0x1AFFFFFF))
                : Colors.transparent,
          ),
          child: Icon(
            widget.icon,
            size: 16,
            color: _isHovered && widget.isCloseButton ? Colors.white : const Color(0xFFa1a1aa),
          ),
        ),
      ),
    );
  }
}
