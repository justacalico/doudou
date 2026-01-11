import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../../providers/app_state.dart';

/// VR Player Controls Widget
///
/// Provides playback controls optimized for VR viewing with large touch targets
class VRPlayerControls extends StatefulWidget {
  final AppState appState;

  const VRPlayerControls({super.key, required this.appState});

  @override
  State<VRPlayerControls> createState() => _VRPlayerControlsState();
}

class _VRPlayerControlsState extends State<VRPlayerControls> {
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setupStreams();
  }

  void _setupStreams() {
    widget.appState.playbackState?.listen((PlaybackState state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          _position = state.position;
        });
      }
    });

    widget.appState.mediaItem?.listen((MediaItem? item) {
      if (mounted && item != null) {
        setState(() {
          _duration = item.duration ?? Duration.zero;
        });
      }
    });

    widget.appState.positionStream?.listen((Duration position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.purple,
                  inactiveTrackColor: Colors.grey.shade800,
                  thumbColor: Colors.white,
                  overlayColor: Colors.purple.withOpacity(0.3),
                  trackHeight: 4.0,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8.0,
                  ),
                ),
                child: Slider(
                  value: _position.inMilliseconds.toDouble(),
                  max: _duration.inMilliseconds.toDouble() > 0
                      ? _duration.inMilliseconds.toDouble()
                      : 1.0,
                  onChanged: (value) {
                    widget.appState.audioHandler?.seek(
                      Duration(milliseconds: value.toInt()),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildControlButton(
              icon: Icons.skip_previous,
              onPressed: () => widget.appState.audioHandler?.skipToPrevious(),
              size: 50,
            ),

            const SizedBox(width: 40),

            _buildControlButton(
              icon: _isPlaying ? Icons.pause : Icons.play_arrow,
              onPressed: () {
                if (_isPlaying) {
                  widget.appState.audioHandler?.pause();
                } else {
                  widget.appState.audioHandler?.play();
                }
              },
              size: 70,
              isPrimary: true,
            ),

            const SizedBox(width: 40),

            _buildControlButton(
              icon: Icons.skip_next,
              onPressed: () => widget.appState.audioHandler?.skipToNext(),
              size: 50,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required double size,
    bool isPrimary = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isPrimary
            ? LinearGradient(
                colors: [Colors.purple.shade700, Colors.purple.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isPrimary ? null : Colors.grey.shade900,
        boxShadow: [
          BoxShadow(
            color: isPrimary
                ? Colors.purple.withOpacity(0.5)
                : Colors.black.withOpacity(0.5),
            blurRadius: isPrimary ? 20 : 10,
            spreadRadius: isPrimary ? 5 : 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: size * 0.6),
          ),
        ),
      ),
    );
  }
}
