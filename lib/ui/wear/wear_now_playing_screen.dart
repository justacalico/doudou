import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/wear_comm_service.dart';

/// Now Playing screen for Wear OS. Shows album art (small, cached),
/// song title/artist, and playback controls. Optimized for tiny screens.
class WearNowPlayingScreen extends StatelessWidget {
  const WearNowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final comm = Get.find<WearCommService>();
    final size = MediaQuery.of(context).size;
    final isRound = size.width == size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: Obx(() {
                final hasSong = comm.songTitle.value.isNotEmpty;
                if (!hasSong) {
                  return _buildEmpty(context);
                }
                return _buildNowPlaying(context, comm, isRound);
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.arrow_back, size: 20),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Now Playing',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.music_off, size: 36),
          const SizedBox(height: 8),
          Text(
            'No song playing',
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNowPlaying(
      BuildContext context, WearCommService comm, bool isRound) {
    final padding = isRound ? 20.0 : 12.0;

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Album art - small to save memory on watch
          ClipOval(
            child: SizedBox(
              width: 60,
              height: 60,
              child: comm.songArtUri.value.isNotEmpty
                  ? Image.network(
                      comm.songArtUri.value,
                      cacheWidth: 64,
                      cacheHeight: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _defaultArt(),
                    )
                  : _defaultArt(),
            ),
          ),
          const SizedBox(height: 8),
          // Title
          Text(
            comm.songTitle.value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          // Artist
          Text(
            comm.songArtist.value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          // Progress bar - simple, no seek
          _buildProgressBar(context, comm),
          const SizedBox(height: 12),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                context,
                Icons.skip_previous,
                comm.prev,
              ),
              _buildPlayPauseButton(context, comm),
              _buildControlButton(
                context,
                Icons.skip_next,
                comm.next,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Favorite toggle
          Obx(() => IconButton(
                onPressed: comm.toggleFav,
                icon: Icon(
                  comm.isFav.value ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                  color: comm.isFav.value
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).iconTheme.color,
                ),
              )),
        ],
      ),
    );
  }

  Widget _defaultArt() {
    return Container(
      color: Colors.grey[900],
      child: const Icon(Icons.album, size: 30, color: Colors.white54),
    );
  }

  Widget _buildProgressBar(BuildContext context, WearCommService comm) {
    return Obx(() {
      final total = comm.durationMs.value;
      final current = comm.positionMs.value;
      final progress = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;

      return SizedBox(
        height: 4,
        width: 100,
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white24,
          valueColor: AlwaysStoppedAnimation(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    });
  }

  Widget _buildControlButton(
      BuildContext context, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 28),
      ),
    );
  }

  Widget _buildPlayPauseButton(BuildContext context, WearCommService comm) {
    return Obx(() => GestureDetector(
          onTap: comm.playPause,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Icon(
              comm.isPlaying.value ? Icons.pause : Icons.play_arrow,
              size: 28,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ));
  }
}
