import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';
import 'cached_artwork.dart';
import '../../models/jellyfin_models.dart';

/// Apple Music-style playlist card
class PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final double size;
  final VoidCallback? onTap;
  final String Function(String imageId, {int? width, int? height})? getImageUrl;

  const PlaylistCard({
    super.key,
    required this.playlist,
    this.size = 160,
    this.onTap,
    this.getImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CachedArtwork(
              imageUrl: playlist.imageUrl != null && getImageUrl != null
                  ? getImageUrl!(playlist.imageUrl!, width: 400, height: 400)
                  : null,
              size: size,
              borderRadius: AppTheme.radiusM,
              placeholderIcon: CupertinoIcons.music_note_list,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              playlist.name,
              style: TextStyle(
                fontSize: AppTheme.fontSizeFootnote,
                color: AppTheme.textPrimary(context),
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              playlist.trackCount > 0
                  ? '${playlist.trackCount} songs'
                  : 'Playlist',
              style: TextStyle(
                fontSize: AppTheme.fontSizeCaption,
                color: AppTheme.textSecondary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal scrolling playlist row
class PlaylistRow extends StatelessWidget {
  final List<Playlist> playlists;
  final double itemSize;
  final void Function(Playlist playlist)? onPlaylistTap;
  final String Function(String imageId, {int? width, int? height})? getImageUrl;

  const PlaylistRow({
    super.key,
    required this.playlists,
    this.itemSize = 160,
    this.onPlaylistTap,
    this.getImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemSize + 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
        itemCount: playlists.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppTheme.spacingM),
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          return PlaylistCard(
            playlist: playlist,
            size: itemSize,
            getImageUrl: getImageUrl,
            onTap: onPlaylistTap != null ? () => onPlaylistTap!(playlist) : null,
          );
        },
      ),
    );
  }
}

/// Playlist list tile for vertical lists
class PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback? onTap;
  final String Function(String imageId, {int? width, int? height})? getImageUrl;

  const PlaylistTile({
    super.key,
    required this.playlist,
    this.onTap,
    this.getImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingL,
          vertical: AppTheme.spacingM,
        ),
        child: Row(
          children: [
            CachedArtwork(
              imageUrl: playlist.imageUrl != null && getImageUrl != null
                  ? getImageUrl!(playlist.imageUrl!, width: 120, height: 120)
                  : null,
              size: AppTheme.albumArtMedium,
              borderRadius: AppTheme.radiusS,
              placeholderIcon: CupertinoIcons.music_note_list,
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      color: AppTheme.textPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    playlist.trackCount > 0
                        ? '${playlist.trackCount} songs'
                        : 'Playlist',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeFootnote,
                      color: AppTheme.textSecondary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppTheme.textSecondary(context),
            ),
          ],
        ),
      ),
    );
  }
}
