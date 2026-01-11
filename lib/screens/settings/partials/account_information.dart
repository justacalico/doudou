import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/base_service.dart';

class AccountInformationSection extends StatelessWidget {
  const AccountInformationSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final serverType = appState.mediaServiceManager.currentServerType;
        final isLocalMusic = serverType == ServerType.local;
        final localService = appState.mediaServiceManager.localMusicService;
        final currentServer = appState.mediaServiceManager.currentServer;

        // Get server type display name
        String getServerTypeName() {
          switch (serverType) {
            case ServerType.jellyfin:
              return 'Jellyfin';
            case ServerType.plex:
              return 'Plex';
            case ServerType.subsonic:
              return 'Navidrome/Subsonic';
            case ServerType.local:
              return 'Local Files';
          }
        }

        // Get user info based on server type
        String? getUserId() {
          if (currentServer == null) return null;
          if (serverType == ServerType.jellyfin) {
            return currentServer.userId?.substring(0, 8);
          } else if (serverType == ServerType.subsonic && currentServer is Map) {
            return currentServer['username'];
          } else if (serverType == ServerType.plex && currentServer is Map) {
            return currentServer['machineIdentifier']?.toString().substring(0, 8);
          }
          return null;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.12),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    _buildSectionHeader(l10n.accountInformation),
                    if (isLocalMusic && localService != null) ...[
                      // Local Music Mode
                      _buildInfoTile(
                        icon: CupertinoIcons.folder,
                        title: 'Music Source',
                        subtitle: 'Local Files',
                      ),
                      _buildInfoTile(
                        icon: CupertinoIcons.music_albums,
                        title: 'Directories',
                        subtitle: '${localService.musicDirectories.length} folder${localService.musicDirectories.length != 1 ? 's' : ''} configured',
                      ),
                      _buildInfoTile(
                        icon: CupertinoIcons.checkmark_seal,
                        title: l10n.connectionStatus,
                        subtitle: 'Active',
                      ),
                    ] else if (currentServer != null) ...[
                      // Server Mode (Jellyfin, Navidrome, Plex, etc.)
                      _buildInfoTile(
                        icon: CupertinoIcons.person_circle,
                        title: l10n.userId,
                        subtitle: getUserId() ?? l10n.notAvailable,
                      ),
                      _buildInfoTile(
                        icon: CupertinoIcons.globe,
                        title: l10n.server,
                        subtitle: getServerTypeName(),
                      ),
                      _buildInfoTile(
                        icon: CupertinoIcons.checkmark_seal,
                        title: l10n.connectionStatus,
                        subtitle: l10n.authenticated,
                      ),
                    ],
                  ],
                ),
              ),
            ),
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

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(icon, color: const Color(0xFF8B5CF6), size: 20),
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
                    color: Color(
                      0xFFAAAAAA,
                    ), // Lighter gray for better readability
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
