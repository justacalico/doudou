import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlaylistAlbumScrollBehaviour extends MaterialScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  Set<LogicalKeyboardKey> get pointerAxisModifiers => {
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.shiftRight,
      };

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

