import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:doudou/providers/app_state.dart';
import 'package:doudou/ui/layout/breakpoint.dart';
import 'package:doudou/ui/desktop/templates/desktop_layout.dart' show NowPlayingOverlay;
import 'package:doudou/ui/mobile/playing/now_playing.dart' show NowPlayingScreen;

/// Now-playing UI that switches between desktop and mobile layout by width.
/// Use this when opening the now-playing view so resizing updates the layout.
class ResponsiveNowPlaying extends StatelessWidget {
  const ResponsiveNowPlaying({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= kLayoutBreakpoint;
    final appState = context.read<AppState>();
    final audioHandler = appState.audioHandler;

    if (isDesktop && audioHandler != null) {
      return NowPlayingOverlay(
        appState: appState,
        audioHandler: audioHandler,
      );
    }
    return const NowPlayingScreen();
  }
}
