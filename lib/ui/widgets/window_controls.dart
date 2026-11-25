import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WindowControls extends StatelessWidget {
  const WindowControls({super.key, this.vertical = false});

  /// Stacks the buttons vertically for narrow layouts such as the minimized
  /// sidebar, where the horizontal row does not fit.
  final bool vertical;

  static const MethodChannel _channel = MethodChannel('com.openlyst.doudou/window_controls');

  @visibleForTesting
  static bool? debugIsHyprland;

  @visibleForTesting
  static bool? debugIsKde;

  /// Hyprland (Wayland) doesn't support client-side minimize/maximize the way
  /// the method channel expects, so only the close button is shown there.
  static bool get _isHyprland =>
      debugIsHyprland ??
      (Platform.isLinux &&
          ((Platform.environment['XDG_CURRENT_DESKTOP'] ?? '')
              .toLowerCase()
              .contains('hyprland') ||
              (Platform.environment['HYPRLAND_INSTANCE_SIGNATURE'] ?? '')
                  .isNotEmpty));

  /// KDE (Plasma) draws its own native title bar, so the in-app controls are
  /// redundant and would duplicate the window manager's buttons.
  static bool get _isKde =>
      debugIsKde ??
      (Platform.isLinux &&
          ((Platform.environment['XDG_CURRENT_DESKTOP'] ?? '')
              .toUpperCase()
              .contains('KDE') ||
              (Platform.environment['KDE_FULL_SESSION'] ?? '').isNotEmpty));

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

    // KDE draws its own title bar with window controls, so hide the in-app
    // ones to avoid duplicating them.
    if (_isKde) {
      return const SizedBox.shrink();
    }

    final gap = Platform.isMacOS ? 8.0 : 4.0;
    final buttons = <Widget>[
      if (Platform.isMacOS) ...[
        _MacOSWindowControl(
          color: Colors.red,
          onPressed: _close,
        ),
        _MacOSWindowControl(
          color: Colors.yellow,
          onPressed: _minimize,
        ),
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
          _WindowControlButton(
            icon: Icons.crop_square,
            onPressed: _maximize,
          ),
          _WindowControlButton(
            icon: Icons.minimize,
            onPressed: _minimize,
          ),
        ],
      ],
    ];

    return Container(
      height: vertical ? null : 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Flex(
        direction: vertical ? Axis.vertical : Axis.horizontal,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i != 0)
              SizedBox(
                width: vertical ? 0 : gap,
                height: vertical ? gap : 0,
              ),
            buttons[i],
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
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.isCloseButton ? const Color(0xFFe81123) : const Color(0x1AFFFFFF))
                : Colors.transparent,
            shape: BoxShape.circle,
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
