import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/wear_comm_service.dart';

/// Now Playing screen for Wear OS. Features album art as full-screen
/// background, circular progress ring, transport controls,
/// and a volume slider overlay. Optimized for tiny round screens.
class WearNowPlayingScreen extends StatefulWidget {
  const WearNowPlayingScreen({super.key});

  @override
  State<WearNowPlayingScreen> createState() => _WearNowPlayingScreenState();
}

class _WearNowPlayingScreenState extends State<WearNowPlayingScreen> {
  final _comm = Get.find<WearCommService>();
  bool _showVolumeSlider = false;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasSong = _comm.songTitle.value.isNotEmpty;
      if (!hasSong) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(child: _buildEmpty(context)),
        );
      }
      return _buildNowPlaying(context);
    });
  }

  String _formatTime(int ms) {
    final secs = (ms / 1000).floor();
    final m = (secs / 60).floor();
    final s = secs % 60;
    return '$m:${s < 10 ? '0' : ''}$s';
  }

  Widget _buildEmpty(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.music_off, size: 32),
        const SizedBox(height: 8),
        Text(
          'No song playing',
          style: Theme.of(context).textTheme.titleSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back, size: 20, color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildNowPlaying(BuildContext context) {
    final artUri = _comm.songArtUri.value;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Album art as full-screen background
          if (artUri.isNotEmpty)
            Image.network(
              artUri,
              fit: BoxFit.cover,
              cacheWidth: 200,
              cacheHeight: 200,
              errorBuilder: (_, __, ___) => Container(color: Colors.black),
            )
          else
            Container(color: Colors.black),
          // Dark gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.55),
                  Colors.black.withOpacity(0.70),
                  Colors.black.withOpacity(0.85),
                ],
              ),
            ),
          ),
          // Circular progress ring
          _buildCircularProgress(context),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  _buildTopBar(context),
                  const Spacer(),
                  _buildSongInfo(context),
                  const SizedBox(height: 12),
                  _buildControls(context),
                  const SizedBox(height: 4),
                  _buildBottomRow(context),
                ],
              ),
            ),
          ),
          // Volume slider overlay
          if (_showVolumeSlider) _buildVolumeOverlay(context),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.arrow_back, size: 18, color: Colors.white70),
          ),
        ),
      ],
    );
  }

  Widget _buildCircularProgress(BuildContext context) {
    return Obx(() {
      final total = _comm.durationMs.value;
      final current = _comm.positionMs.value;
      final progress = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;

      return IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: CustomPaint(
            painter: _CircularProgressPainter(
              progress: progress,
              trackColor: Colors.white.withOpacity(0.10),
              progressColor: const Color(0xFFE8A598),
              strokeWidth: 2.5,
            ),
            size: Size.infinite,
          ),
        ),
      );
    });
  }

  Widget _buildSongInfo(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'NOW PLAYING',
          style: TextStyle(
            color: const Color(0xFFE8A598).withOpacity(0.8),
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _comm.songTitle.value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _comm.songArtist.value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildControls(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(Icons.skip_previous, _comm.prev),
        Obx(() => GestureDetector(
              onTap: _comm.playPause,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Icon(
                  _comm.isPlaying.value ? Icons.pause : Icons.play_arrow,
                  size: 24,
                  color: Colors.black,
                ),
              ),
            )),
        _buildControlButton(Icons.skip_next, _comm.next),
      ],
    );
  }

  Widget _buildBottomRow(BuildContext context) {
    return Obx(() {
      final current = _comm.positionMs.value;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Favorite
          GestureDetector(
            onTap: _comm.toggleFav,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                _comm.isFav.value
                    ? Icons.favorite
                    : Icons.favorite_border,
                size: 16,
                color: _comm.isFav.value
                    ? const Color(0xFFE8A598)
                    : Colors.white70,
              ),
            ),
          ),
          // Time
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Text(
              _formatTime(current),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          // Volume toggle
          GestureDetector(
            onTap: () => setState(() => _showVolumeSlider = !_showVolumeSlider),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                _comm.isMuted.value
                    ? Icons.volume_off
                    : Icons.volume_up,
                size: 16,
                color: _showVolumeSlider
                    ? const Color(0xFFE8A598)
                    : Colors.white70,
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildVolumeOverlay(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _showVolumeSlider = false),
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 160,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.90),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Obx(() {
                final vol = _comm.volume.value;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _comm.mute,
                          child: Icon(
                            _comm.isMuted.value
                                ? Icons.volume_off
                                : Icons.volume_up,
                            size: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 5),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 10),
                              activeTrackColor: const Color(0xFFE8A598),
                              inactiveTrackColor: Colors.white24,
                              thumbColor: const Color(0xFFE8A598),
                            ),
                            child: Slider(
                              value: (vol / 100).clamp(0.0, 1.0),
                              onChanged: (v) =>
                                  _comm.setVolume((v * 100).round()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$vol%',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 24, color: Colors.white70),
      ),
    );
  }
}

/// Paints a circular progress ring around the screen edge.
class _CircularProgressPainter extends CustomPainter {
  _CircularProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2 - strokeWidth / 2)
        .clamp(strokeWidth, 200)
        .toDouble();

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        progress * 2 * math.pi,
        false,
        Paint()
          ..color = progressColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter old) =>
      old.progress != progress;
}
