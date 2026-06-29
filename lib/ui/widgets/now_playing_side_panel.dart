import 'package:flutter/material.dart';

import '../design/doudou_colors.dart';
import '../player/components/standard_player.dart';

/// Now playing panel that sits on the right side of the app on desktop.
/// Shows the full player UI in a fixed-width column that can be resized
/// via the [PanelResizeHandle] next to it.
class NowPlayingSidePanel extends StatelessWidget {
  const NowPlayingSidePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.doudouColors;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: c.borderSubtle, width: 0.5),
        ),
      ),
      child: const StandardPlayer(),
    );
  }
}

/// The drag handle between the main content and the now playing panel.
/// Dragging it left/right resizes the panel. Double-click toggles visibility.
class PanelResizeHandle extends StatelessWidget {
  const PanelResizeHandle({
    super.key,
    required this.onDragUpdate,
    required this.onToggle,
  });

  final ValueChanged<double> onDragUpdate;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.doudouColors;
    double lastX = 0;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        onHorizontalDragStart: (details) {
          lastX = details.globalPosition.dx;
        },
        onHorizontalDragUpdate: (details) {
          final dx = details.globalPosition.dx - lastX;
          lastX = details.globalPosition.dx;
          // Moving the handle left means the panel gets wider
          onDragUpdate(-dx);
        },
        onDoubleTap: onToggle,
        child: Container(
          width: 6,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 1,
              color: c.borderSubtle,
            ),
          ),
        ),
      ),
    );
  }
}
