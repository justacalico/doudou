import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/wear_comm_service.dart';

/// Home screen for the Wear OS app. Shows two large tap targets:
/// Shuffle All and Favorites. Optimized for small round screens.
/// Navigation between these cards is handled by the parent PageView
/// with rotary input support.
class WearHomeScreen extends StatelessWidget {
  const WearHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final comm = Get.find<WearCommService>();
    final size = MediaQuery.of(context).size;
    final isRound = size.width == size.height;

    return Scaffold(
      body: SafeArea(
        child: PageView(
          children: [
            _buildShuffleAllCard(comm, isRound),
            _buildFavoritesCard(comm, isRound),
            _buildNowPlayingShortcut(comm, isRound),
          ],
        ),
      ),
    );
  }

  Widget _buildShuffleAllCard(WearCommService comm, bool isRound) {
    return _ActionCard(
      icon: Icons.shuffle,
      label: 'Shuffle All',
      onTap: () => comm.shuffleAll(),
      isRound: isRound,
    );
  }

  Widget _buildFavoritesCard(WearCommService comm, bool isRound) {
    return Obx(() => _ActionCard(
          icon: Icons.favorite,
          label: 'Favorites',
          subtitle: '${comm.favoritesCount.value} songs',
          onTap: () => comm.shuffleFavorites(),
          isRound: isRound,
        ));
  }

  Widget _buildNowPlayingShortcut(WearCommService comm, bool isRound) {
    return Obx(() {
      final hasSong = comm.songTitle.value.isNotEmpty;
      if (!hasSong) {
        return _ActionCard(
          icon: Icons.music_note,
          label: 'Nothing Playing',
          isRound: isRound,
        );
      }
      return _ActionCard(
        icon: Icons.play_arrow,
        label: comm.songTitle.value,
        subtitle: comm.songArtist.value,
        onTap: () => comm.playPause(),
        isRound: isRound,
      );
    });
  }
}

/// A full-screen tap target with an icon and label.
/// Kept simple for performance on slow watch hardware.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    required this.isRound,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isRound;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isRound ? 24.0 : 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
