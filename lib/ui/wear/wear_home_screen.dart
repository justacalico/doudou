import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wearable_rotary/wearable_rotary.dart';

import '../../services/wear_comm_service.dart';
import 'wear_now_playing_screen.dart';
import 'wear_settings_screen.dart';

/// Home screen for the Wear OS app. A scrollable launcher-style menu
/// with rotary input support. Tapping items either sends a command to
/// the phone or navigates to a sub-screen via the Navigator.
class WearHomeScreen extends StatefulWidget {
  const WearHomeScreen({super.key});

  @override
  State<WearHomeScreen> createState() => _WearHomeScreenState();
}

class _WearHomeScreenState extends State<WearHomeScreen> {
  final _comm = Get.find<WearCommService>();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    rotaryEvents.listen((event) {
      if (!mounted || !_scrollController.hasClients) return;
      final direction =
          event.direction == RotaryDirection.clockwise ? 60.0 : -60.0;
      _scrollController.animateTo(
        (_scrollController.offset + direction).clamp(
          0,
          _scrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isRound = size.width == size.height;
    final horizontalPadding = isRound ? 20.0 : 12.0;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 8,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildNowPlayingTile(context),
                  _buildDivider(),
                  _buildMenuTile(
                    context,
                    icon: Icons.shuffle,
                    label: 'Shuffle All',
                    onTap: () => _comm.shuffleAll(),
                  ),
                  Obx(() => _buildMenuTile(
                        context,
                        icon: Icons.favorite,
                        label: 'Shuffle Favorites',
                        subtitle:
                            '${_comm.favoritesCount.value} songs',
                        onTap: () => _comm.shuffleFavorites(),
                      )),
                  _buildDivider(),
                  _buildMenuTile(
                    context,
                    icon: Icons.settings,
                    label: 'Settings',
                    onTap: () => _navigateToSettings(context),
                  ),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNowPlayingTile(BuildContext context) {
    return Obx(() {
      final hasSong = _comm.songTitle.value.isNotEmpty;
      return _MenuTile(
        icon: hasSong
            ? (_comm.isPlaying.value ? Icons.play_circle_filled : Icons.pause_circle_filled)
            : Icons.music_note,
        label: hasSong ? _comm.songTitle.value : 'Nothing Playing',
        subtitle: hasSong ? _comm.songArtist.value : 'Tap to open',
        accent: hasSong,
        onTap: () => _navigateToNowPlaying(context),
      );
    });
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return _MenuTile(
      icon: icon,
      label: label,
      subtitle: subtitle,
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: Colors.white12,
      ),
    );
  }

  void _navigateToNowPlaying(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const WearNowPlayingScreen(),
      ),
    );
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const WearSettingsScreen(),
      ),
    );
  }
}

/// A compact list tile optimized for small round watch screens.
class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.accent = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: accent ? theme.colorScheme.primary : theme.iconTheme.color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: accent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: Colors.white38,
              ),
          ],
        ),
      ),
    );
  }
}
