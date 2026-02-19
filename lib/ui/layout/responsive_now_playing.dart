import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:doudou/providers/app_state.dart';
import 'package:doudou/ui/layout/breakpoint.dart';
import 'package:doudou/ui/adaptive/desktop/desktop_layout.dart' show NowPlayingOverlay;
import 'package:doudou/ui/adaptive/mobile/now_playing.dart' show NowPlayingScreen;

/// Now-playing UI: wide layout = overlay, narrow = full-screen. One codebase, resizes by width.
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
