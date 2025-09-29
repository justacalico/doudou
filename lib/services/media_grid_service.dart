import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import '../models/jellyfin_models.dart';
import '../screens/partials/player/mini_player.dart';
import '../widgets/cached_image_widget.dart';

/// Centralized service for creating media grids (albums, playlists, etc.)
class MediaGridService {
  /// Creates a standardized media grid layout
  static Widget createMediaGrid<T>({
    required BuildContext context,
    required List<T> items,
    required bool isLoading,
    required String emptyTitle,
    required String emptySubtitle,
    required IconData emptyIcon,
    required Widget Function(T item, int index) itemBuilder,
    required Future<void> Function() onRefresh,
    Widget? headerWidget,
    bool useGridLayout = true,
    int gridCrossAxisCount = 2,
    double gridChildAspectRatio = 0.8,
    Color backgroundColor = const Color(0xFF000000),
    bool showMiniPlayer = true,
  }) {
    if (isLoading && items.isEmpty) {
      return Container(
        color: backgroundColor,
        child: const Center(
          child: CupertinoActivityIndicator(color: CupertinoColors.white),
        ),
      );
    }

    if (items.isEmpty) {
      return Container(
        color: backgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                emptyIcon,
                size: 80,
                color: const Color(0xFF333333),
              ),
              const SizedBox(height: 24),
              Text(
                emptyTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFFFFFF),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  emptySubtitle,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF888888),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Container(
          color: backgroundColor,
          child: CustomScrollView(
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: onRefresh,
              ),
              // Optional header widget
              if (headerWidget != null)
                SliverToBoxAdapter(child: headerWidget),
              // Media items
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: useGridLayout
                    ? SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridCrossAxisCount,
                          childAspectRatio: gridChildAspectRatio,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => itemBuilder(items[index], index),
                          childCount: items.length,
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => itemBuilder(items[index], index),
                          childCount: items.length,
                        ),
                      ),
              ),
              // Bottom padding for mini player
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
        // Mini player at bottom
        if (showMiniPlayer)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: MiniPlayer(),
            ),
          ),
      ],
    );
  }

  /// Creates a standardized album card widget
  static Widget createAlbumCard({
    required Album album,
    required VoidCallback onTap,
    required String? Function(String?, {int? width, int? height}) getImageUrl,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF1A1A1A),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album Art
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  color: const Color(0xFF2A2A2A),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: AlbumArtWidget(
                    imageUrl: album.imageUrl != null
                        ? getImageUrl(album.imageUrl!, width: 300, height: 300)
                        : null,
                    size: double.infinity,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                ),
              ),
            ),
            // Album Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      album.name,
                      style: const TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (album.artistName != null)
                      Text(
                        album.artistName!,
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Creates a standardized playlist tile widget
  static Widget createPlaylistTile({
    required Playlist playlist,
    required VoidCallback onTap,
    required String? Function(String?, {int? width, int? height}) getImageUrl,
    VoidCallback? onDelete,
    VoidCallback? onEdit,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1A1A1A),
      ),
      child: CupertinoListTile(
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF2A2A2A),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AlbumArtWidget(
              imageUrl: playlist.imageUrl != null
                  ? getImageUrl(playlist.imageUrl!, width: 120, height: 120)
                  : null,
              size: 60,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        title: Text(
          playlist.name,
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${playlist.trackCount ?? 0} songs',
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 14,
          ),
        ),
        trailing: onEdit != null || onDelete != null
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(
                  CupertinoIcons.ellipsis,
                  color: Color(0xFF888888),
                  size: 20,
                ),
                onPressed: () => _showPlaylistOptions(
                  onTap,
                  onEdit,
                  onDelete,
                ),
              )
            : const Icon(
                CupertinoIcons.chevron_right,
                color: Color(0xFF888888),
                size: 16,
              ),
        onTap: onTap,
      ),
    );
  }

  static void _showPlaylistOptions(
    VoidCallback? onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  ) {
    // This would need to be implemented with proper context
    // For now, just call onTap as fallback
    onTap?.call();
  }
}