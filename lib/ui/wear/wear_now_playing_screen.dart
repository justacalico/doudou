import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/wear_comm_service.dart';

/// Now Playing screen for Wear OS. Uses album art as a blurred background
/// with song info and controls overlaid. Optimized for tiny round screens.
class WearNowPlayingScreen extends StatelessWidget {
  const WearNowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final comm = Get.find<WearCommService>();

    return Obx(() {
      final hasSong = comm.songTitle.value.isNotEmpty;
      if (!hasSong) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(child: _buildEmpty(context)),
        );
      }
      return _buildNowPlaying(context, comm);
    });
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
          child: Icon(Icons.arrow_back, size: 20, color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildNowPlaying(BuildContext context, WearCommService comm) {
    final artUri = comm.songArtUri.value;

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
          // Dark gradient overlay for readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.85),
                ],
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _buildTopBar(context),
                  const Spacer(),
                  _buildSongInfo(context, comm),
                  const SizedBox(height: 8),
                  _buildProgressBar(context, comm),
                  const SizedBox(height: 8),
                  _buildControls(context, comm),
                ],
              ),
            ),
          ),
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

  Widget _buildSongInfo(BuildContext context, WearCommService comm) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          comm.songTitle.value,
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
          comm.songArtist.value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildProgressBar(BuildContext context, WearCommService comm) {
    return Obx(() {
      final total = comm.durationMs.value;
      final current = comm.positionMs.value;
      final progress = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;

      return SizedBox(
        height: 3,
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white24,
          valueColor: const AlwaysStoppedAnimation(Color(0xFFE8A598)),
        ),
      );
    });
  }

  Widget _buildControls(BuildContext context, WearCommService comm) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(Icons.skip_previous, comm.prev),
        Obx(() => GestureDetector(
              onTap: comm.playPause,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE8A598),
                ),
                child: Icon(
                  comm.isPlaying.value ? Icons.pause : Icons.play_arrow,
                  size: 24,
                  color: Colors.black,
                ),
              ),
            )),
        _buildControlButton(Icons.skip_next, comm.next),
        Obx(() => GestureDetector(
              onTap: comm.toggleFav,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  comm.isFav.value ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: comm.isFav.value
                      ? const Color(0xFFE8A598)
                      : Colors.white70,
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 24, color: Colors.white70),
      ),
    );
  }
}
