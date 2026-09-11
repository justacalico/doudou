import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../player_controller.dart';

/// Circular play/pause button used by the full screen player layouts.
///
/// Shows a loading indicator and ignores taps while a song is loading,
/// matching the behaviour of the mini player.
class NowPlayingPlayButton extends StatelessWidget {
  const NowPlayingPlayButton({
    super.key,
    required this.controller,
    required this.size,
    required this.iconSize,
    required this.backgroundColor,
    required this.iconColor,
    this.border,
  });

  final PlayerController controller;
  final double size;
  final double iconSize;
  final Color backgroundColor;
  final Color iconColor;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = controller.buttonState.value;
      final isPlaying = state == PlayButtonState.playing;
      final isLoading = state == PlayButtonState.loading;

      return GestureDetector(
        onTap: isLoading ? null : controller.playPause,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: border,
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: iconSize * 0.75,
                    height: iconSize * 0.75,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: iconColor,
                    size: iconSize,
                  ),
          ),
        ),
      );
    });
  }
}
