import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';
import 'cached_artwork.dart';
import '../../models/jellyfin_models.dart';

/// Apple Music-style horizontal scrolling album card
class AlbumCard extends StatelessWidget {
  final Album album;
  final double size;
  final VoidCallback? onTap;
  final String Function(String imageId, {int? width, int? height})? getImageUrl;

  const AlbumCard({
    super.key,
    required this.album,
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
              imageUrl: album.imageUrl != null && getImageUrl != null
                  ? getImageUrl!(album.imageUrl!, width: 400, height: 400)
                  : null,
              size: size,
              borderRadius: AppTheme.radiusM,
              placeholderIcon: CupertinoIcons.music_albums,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              album.name,
              style: TextStyle(
                fontSize: AppTheme.fontSizeFootnote,
                color: AppTheme.textPrimary(context),
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (album.artistName != null)
              Text(
                album.artistName!,
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
    );
  }
}

/// Horizontal scrolling album row like Apple Music
class AlbumRow extends StatelessWidget {
  final List<Album> albums;
  final double itemSize;
  final void Function(Album album)? onAlbumTap;
  final String Function(String imageId, {int? width, int? height})? getImageUrl;

  const AlbumRow({
    super.key,
    required this.albums,
    this.itemSize = 160,
    this.onAlbumTap,
    this.getImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemSize + 48, // Extra space for text
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
        itemCount: albums.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppTheme.spacingM),
        itemBuilder: (context, index) {
          final album = albums[index];
          return AlbumCard(
            album: album,
            size: itemSize,
            getImageUrl: getImageUrl,
            onTap: onAlbumTap != null ? () => onAlbumTap!(album) : null,
          );
        },
      ),
    );
  }
}

/// Grid of albums
class AlbumGrid extends StatelessWidget {
  final List<Album> albums;
  final int crossAxisCount;
  final void Function(Album album)? onAlbumTap;
  final String Function(String imageId, {int? width, int? height})? getImageUrl;

  const AlbumGrid({
    super.key,
    required this.albums,
    this.crossAxisCount = 2,
    this.onAlbumTap,
    this.getImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final album = albums[index];
            return AlbumCard(
              album: album,
              getImageUrl: getImageUrl,
              onTap: onAlbumTap != null ? () => onAlbumTap!(album) : null,
            );
          },
          childCount: albums.length,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: AppTheme.spacingL,
          crossAxisSpacing: AppTheme.spacingM,
          childAspectRatio: 0.75,
        ),
      ),
    );
  }
}
