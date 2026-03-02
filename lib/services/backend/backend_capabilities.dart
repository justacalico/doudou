class BackendCapabilities {
  const BackendCapabilities({
    this.hasVideos = false,
    this.hasCommunityPlaylists = false,
    this.hasFeaturedPlaylists = false,
    this.hasTrending = false,
    this.hasDiscoverContent = false,
    this.hasCharts = false,
  });

  final bool hasVideos;
  final bool hasCommunityPlaylists;
  final bool hasFeaturedPlaylists;
  final bool hasTrending;
  final bool hasDiscoverContent;
  final bool hasCharts;

  static const BackendCapabilities youtubeMusic = BackendCapabilities(
    hasVideos: true,
    hasCommunityPlaylists: true,
    hasFeaturedPlaylists: true,
    hasTrending: true,
    hasDiscoverContent: true,
    hasCharts: true,
  );

  static const BackendCapabilities jellyfin = BackendCapabilities(
    hasVideos: false,
    hasCommunityPlaylists: false,
    hasFeaturedPlaylists: false,
    hasTrending: false,
    hasDiscoverContent: false,
    hasCharts: false,
  );

  static const BackendCapabilities subsonic = BackendCapabilities(
    hasVideos: false,
    hasCommunityPlaylists: false,
    hasFeaturedPlaylists: false,
    hasTrending: false,
    hasDiscoverContent: false,
    hasCharts: false,
  );

  static const BackendCapabilities plex = BackendCapabilities(
    hasVideos: false,
    hasCommunityPlaylists: false,
    hasFeaturedPlaylists: false,
    hasTrending: false,
    hasDiscoverContent: false,
    hasCharts: false,
  );
}
