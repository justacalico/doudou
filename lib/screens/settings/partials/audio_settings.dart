import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state.dart';

class AudioSettingsSection extends StatelessWidget {
  const AudioSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF000000), // Pure black background
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF2C2C2E),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildSectionHeader('Audio Settings'),
              _buildSwitchTile(
                icon: CupertinoIcons.volume_up,
                title: 'Smart Crossfade',
                subtitle: 'Smooth transitions between tracks',
                value: appState.smartCrossfadeEnabled,
                onChanged: (value) {
                  appState.toggleSmartCrossfade(value);
                },
              ),
              _buildSwitchTile(
                icon: CupertinoIcons.speaker_2,
                title: 'Normalize Volume',
                subtitle: 'Reduces volume differences between tracks',
                value: appState.normalizeVolumeEnabled,
                onChanged: (value) {
                  appState.toggleNormalizeVolume(value);
                },
              ),
              _buildSwitchTile(
                icon: CupertinoIcons.forward_end,
                title: 'Gapless Playback',
                subtitle: 'Seamless transitions between tracks in queue',
                value: appState.gaplessPlaybackEnabled,
                onChanged: (value) {
                  appState.toggleGaplessPlayback(value);
                },
              ),
              const Divider(
                color: Color(0xFF2C2C2E),
                height: 1,
                indent: 20,
                endIndent: 20,
              ),
              _buildDownloadTile(
                context: context,
                icon: CupertinoIcons.cloud_download,
                title: 'Download All Songs',
                subtitle: 'Download your entire music library',
                onTap: () => _downloadAllSongs(context, appState),
              ),
              _buildDownloadTile(
                context: context,
                icon: CupertinoIcons.heart_circle,
                title: 'Download All Favorites',
                subtitle: 'Download all your liked songs',
                onTap: () => _downloadAllFavorites(context, appState),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFFFFFFF), // Pure white text
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF3A3A3C),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: value ? const Color(0xFF30D158) : const Color(0xFF007AFF), // Green when active, blue when inactive
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF), // Pure white text
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFAAAAAA), // Lighter gray
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF30D158), // Green for OLED
            trackColor: const Color(0xFF1C1C1E), // Dark track
          ),
        ],
      ),
    );
  }
}
