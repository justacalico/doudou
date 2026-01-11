import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';
import 'cached_artwork.dart';
import '../../models/jellyfin_models.dart';

/// Apple Music-style artist card for horizontal scrolling
class ArtistCard extends StatelessWidget {
  final Artist artist;
  final double size;
  final VoidCallback? onTap;
  final String Function(String imageId, {int? width, int? height})? getImageUrl;

  const ArtistCard({
    super.key,
    required this.artist,
    this.size = 140,
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
          children: [
            ClipOval(
              child: Container(
                width: size,
                height: size,
                color: AppTheme.elevated(context),
                child: artist.imageUrl != null && getImageUrl != null
                    ? CachedArtwork(
                        imageUrl: getImageUrl!(artist.imageUrl!, width: 300, height: 300),
                        size: size,
                        borderRadius: size / 2,
                        placeholderIcon: CupertinoIcons.person_fill,
                      )
                    : Icon(
                        CupertinoIcons.person_fill,
                        size: size * 0.4,
                        color: AppTheme.textSecondary(context),
                      ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              artist.name,
              style: TextStyle(
                fontSize: AppTheme.fontSizeFootnote,
                color: AppTheme.textPrimary(context),
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal scrolling artist row
class ArtistRow extends StatelessWidget {
  final List<Artist> artists;
  final double itemSize;
  final void Function(Artist artist)? onArtistTap;
  final String Function(String imageId, {int? width, int? height})? getImageUrl;

  const ArtistRow({
    super.key,
    required this.artists,
    this.itemSize = 140,
    this.onArtistTap,
    this.getImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemSize + 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
        itemCount: artists.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppTheme.spacingM),
        itemBuilder: (context, index) {
          final artist = artists[index];
          return ArtistCard(
            artist: artist,
            size: itemSize,
            getImageUrl: getImageUrl,
            onTap: onArtistTap != null ? () => onArtistTap!(artist) : null,
          );
        },
      ),
    );
  }
}

/// Artist list tile for vertical lists
class ArtistTile extends StatelessWidget {
  final Artist artist;
  final VoidCallback? onTap;
  final String Function(String imageId, {int? width, int? height})? getImageUrl;

  const ArtistTile({
    super.key,
    required this.artist,
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
            ClipOval(
              child: Container(
                width: AppTheme.albumArtMedium,
                height: AppTheme.albumArtMedium,
                color: AppTheme.elevated(context),
                child: artist.imageUrl != null && getImageUrl != null
                    ? CachedArtwork(
                        imageUrl: getImageUrl!(artist.imageUrl!, width: 120, height: 120),
                        size: AppTheme.albumArtMedium,
                        borderRadius: AppTheme.albumArtMedium / 2,
                        placeholderIcon: CupertinoIcons.person_fill,
                      )
                    : Icon(
                        CupertinoIcons.person_fill,
                        size: 24,
                        color: AppTheme.textSecondary(context),
                      ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Text(
                artist.name,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  color: AppTheme.textPrimary(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
