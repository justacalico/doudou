import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ColorScheme, Brightness;
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

/// Content type for the detail screen
enum DetailType { album, artist, playlist }

/// Unified detail screen for albums, artists, and playlists
class DetailScreen extends StatefulWidget {
  final DetailType type;
  final Album? album;
  final Artist? artist;
  final Playlist? playlist;

  const DetailScreen.album({super.key, required Album this.album})
      : type = DetailType.album,
        artist = null,
        playlist = null;

  const DetailScreen.artist({super.key, required Artist this.artist})
      : type = DetailType.artist,
        album = null,
        playlist = null;

  const DetailScreen.playlist({super.key, required Playlist this.playlist})
      : type = DetailType.playlist,
        album = null,
        artist = null;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  List<Track> _tracks = [];
  List<Album> _albums = []; // For artist view
  bool _isLoading = true;
  Color? _dominantColor;

  // Getters for content properties
  String get _title {
    switch (widget.type) {
      case DetailType.album:
        return widget.album!.name;
      case DetailType.artist:
        return widget.artist!.name;
      case DetailType.playlist:
        return widget.playlist!.name;
    }
  }

  String? get _subtitle {
    switch (widget.type) {
      case DetailType.album:
        return widget.album!.artistName;
      case DetailType.artist:
        return '${_albums.length} albums • ${_tracks.length} songs';
      case DetailType.playlist:
        return '${_tracks.length} songs • ${_formatDuration(_tracks)}';
    }
  }

  String? get _imageUrl {
    switch (widget.type) {
      case DetailType.album:
        return widget.album!.imageUrl;
      case DetailType.artist:
        return widget.artist!.imageUrl;
      case DetailType.playlist:
        return widget.playlist!.imageUrl;
    }
  }

  bool get _isCircularImage => widget.type == DetailType.artist;

  @override
  void initState() {
    super.initState();
    _loadData();
    _extractColors();
  }

  Future<void> _extractColors() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final imageUrl = _imageUrl;
    if (imageUrl != null) {
      try {
        final url = appState.getImageUrl(imageUrl, width: 100, height: 100);
        final colorScheme = await ColorScheme.fromImageProvider(
          provider: NetworkImage(url),
          brightness: Brightness.dark,
        );
        if (mounted) {
          setState(() {
            _dominantColor = colorScheme.primary;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _dominantColor = AppTheme.accentPink;
          });
        }
      }
    }
  }

  Future<void> _loadData() async {
    final appState = Provider.of<AppState>(context, listen: false);
    try {
      switch (widget.type) {
        case DetailType.album:
          final tracks = appState.tracks
              .where((t) => t.albumId == widget.album!.id)
              .toList();
          tracks.sort((a, b) => (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0));
          _tracks = tracks;
          break;

        case DetailType.artist:
          _albums = appState.albums
              .where((a) => a.artistName == widget.artist!.name)
              .toList();
          _tracks = appState.tracks
              .where((t) => t.artistName == widget.artist!.name)
              .toList();
          break;

        case DetailType.playlist:
          _tracks = await appState.mediaServiceManager
              .getPlaylistTracks(widget.playlist!.id);
          break;
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tracks = [];
          _albums = [];
          _isLoading = false;
        });
      }
    }
  }

  String _formatDuration(List<Track> tracks) {
    final totalMs = tracks.fold<int>(0, (sum, t) => sum + (t.duration ?? 0));
    final duration = Duration(milliseconds: totalMs);
    if (duration.inHours > 0) {
      return '${duration.inHours} hr ${duration.inMinutes % 60} min';
    }
    return '${duration.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return CupertinoPageScaffold(
          backgroundColor: AppTheme.background(context),
          child: _isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : CustomScrollView(
                  slivers: [
                    // Header
                    SliverToBoxAdapter(
                      child: _buildHeader(context, appState),
                    ),

                    // Albums section (artist only)
                    if (widget.type == DetailType.artist && _albums.isNotEmpty) ...[
                      const SliverSectionHeader(title: 'Albums'),
                      SliverToBoxAdapter(
                        child: AlbumRow(
                          albums: _albums,
                          getImageUrl: appState.getImageUrl,
                          onAlbumTap: (album) => _navigateToAlbum(context, album),
                        ),
                      ),
                      const SliverSectionHeader(title: 'Songs'),
                    ],

                    // Track list
                    TrackList(
                      tracks: widget.type == DetailType.artist 
                          ? _tracks.take(10).toList() 
                          : _tracks,
                      currentTrackId: appState.audioHandler?.currentTrack?.id,
                      showTrackNumbers: widget.type == DetailType.album,
                      showArtwork: widget.type != DetailType.album,
                      getImageUrl: appState.getImageUrl,
                      onTrackTap: (track, index) {
                        appState.audioHandler?.playPlaylist(_tracks, index);
                      },
                      onMoreTap: (track) => _showTrackOptions(context, appState, track),
                    ),

                    // Bottom spacing
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 150),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, AppState appState) {
    final screenWidth = MediaQuery.of(context).size.width;
    final artworkSize = _isCircularImage ? screenWidth * 0.45 : 160.0;
    final gradientColor = _dominantColor ?? const Color(0xFF2C2C2E);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            gradientColor.withOpacity(0.8),
            gradientColor.withOpacity(0.4),
            AppTheme.background(context),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Navigation bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXS),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    minSize: 0,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(CupertinoIcons.back, color: CupertinoColors.white, size: 26),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    minSize: 0,
                    onPressed: () => _showOptions(context, appState),
                    child: const Icon(CupertinoIcons.ellipsis, color: CupertinoColors.white, size: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),

            // Content layout depends on type
            if (_isCircularImage)
              _buildCenteredLayout(context, appState, artworkSize)
            else
              _buildHorizontalLayout(context, appState, artworkSize),

            const SizedBox(height: AppTheme.spacingL),

            // Play and Shuffle buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
              child: Row(
                children: [
                  Expanded(child: _buildPlayButton(appState)),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(child: _buildShuffleButton(appState)),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalLayout(BuildContext context, AppState appState, double artworkSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Artwork
          Container(
            width: artworkSize,
            height: artworkSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedArtwork(
                imageUrl: _imageUrl != null
                    ? appState.getImageUrl(_imageUrl!, width: 400, height: 400)
                    : null,
                size: artworkSize,
                borderRadius: 8,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  _title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.white,
                    letterSpacing: -0.5,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_subtitle != null) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: widget.type == DetailType.album
                        ? () => _navigateToArtist(context)
                        : null,
                    child: Text(
                      _subtitle!,
                      style: TextStyle(
                        fontSize: widget.type == DetailType.album ? 20 : 13,
                        fontWeight: widget.type == DetailType.album 
                            ? FontWeight.w500 
                            : FontWeight.w400,
                        color: widget.type == DetailType.album
                            ? AppTheme.accentPink
                            : CupertinoColors.white.withOpacity(0.6),
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (widget.type == DetailType.album) ...[
                  const SizedBox(height: 4),
                  Text(
                    _buildAlbumInfo(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: CupertinoColors.white.withOpacity(0.6),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenteredLayout(BuildContext context, AppState appState, double artworkSize) {
    return Column(
      children: [
        // Circular artwork for artist
        Container(
          width: artworkSize,
          height: artworkSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipOval(
            child: _imageUrl != null
                ? CachedArtwork(
                    imageUrl: appState.getImageUrl(_imageUrl!, width: 400, height: 400),
                    size: artworkSize,
                    borderRadius: artworkSize / 2,
                    placeholderIcon: CupertinoIcons.person_fill,
                  )
                : Container(
                    color: AppTheme.elevated(context),
                    child: Icon(
                      CupertinoIcons.person_fill,
                      size: artworkSize * 0.4,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingL),

        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
          child: Text(
            _title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.white,
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        if (_subtitle != null) ...[
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            _subtitle!,
            style: TextStyle(
              fontSize: 15,
              color: CupertinoColors.white.withOpacity(0.6),
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildPlayButton(AppState appState) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _tracks.isNotEmpty
          ? () => appState.audioHandler?.playPlaylist(_tracks, 0)
          : null,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.surface(context).withOpacity(0.8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.play_fill, size: 18, color: AppTheme.accentPink),
            SizedBox(width: 8),
            Text(
              'Play',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.accentPink,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShuffleButton(AppState appState) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _tracks.isNotEmpty
          ? () {
              final shuffled = List<Track>.from(_tracks)..shuffle();
              appState.audioHandler?.playPlaylist(shuffled, 0);
            }
          : null,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.surface(context).withOpacity(0.8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.shuffle, size: 18, color: AppTheme.accentPink),
            SizedBox(width: 8),
            Text(
              'Shuffle',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.accentPink,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildAlbumInfo() {
    final parts = <String>[];
    if (widget.album?.year != null) {
      parts.add('${widget.album!.year}');
    }
    parts.add('${_tracks.length} songs');
    parts.add(_formatDuration(_tracks));
    return parts.join(' • ');
  }

  void _navigateToAlbum(BuildContext context, Album album) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => DetailScreen.album(album: album),
      ),
    );
  }

  void _navigateToArtist(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final artistName = widget.album?.artistName;
    if (artistName != null) {
      final artist = appState.artists.firstWhere(
        (a) => a.name == artistName,
        orElse: () => Artist(id: '', name: artistName),
      );
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => DetailScreen.artist(artist: artist),
        ),
      );
    }
  }

  void _showOptions(BuildContext context, AppState appState) {
    final actions = <CupertinoActionSheetAction>[];

    switch (widget.type) {
      case DetailType.album:
        actions.addAll([
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.album!.isFavorite ? 'Remove from Library' : 'Add to Library'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Download'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Add to Playlist'),
          ),
        ]);
        break;

      case DetailType.artist:
        actions.addAll([
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Follow Artist'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Share'),
          ),
        ]);
        break;

      case DetailType.playlist:
        actions.addAll([
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Edit Playlist'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Download'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Share'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Delete Playlist'),
          ),
        ]);
        break;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: actions,
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showTrackOptions(BuildContext context, AppState appState, Track track) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(track.name),
        message: Text(track.artistName ?? ''),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              appState.toggleFavorite(track);
            },
            child: Text(track.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              appState.audioHandler?.addToQueue(track);
            },
            child: const Text('Play Next'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Add to Playlist'),
          ),
          if (widget.type == DetailType.playlist)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context),
              child: const Text('Remove from Playlist'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
