import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:doudou/ui/templates/page_template.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/models/jellyfin_models.dart';
import 'package:doudou/models/download_models.dart';
import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/services/base_service.dart';
import 'package:doudou/services/navigation_service.dart';
import 'package:doudou/ui/templates/music_card.dart';
import 'package:doudou/ui/widgets/apple_dialog.dart';
import 'package:doudou/ui/theme.dart';

enum MediaType { playlist, album, artist }

class MediaDetailsPage extends StatefulWidget {
  final Playlist? playlist;
  final Album? album;
  final Artist? artist;
  final MediaType mediaType;
  final VoidCallback? onBackPressed;

  const MediaDetailsPage.playlist({
    super.key,
    required this.playlist,
    this.onBackPressed,
  })  : album = null,
        artist = null,
        mediaType = MediaType.playlist;

  const MediaDetailsPage.album({
    super.key,
    required this.album,
    this.onBackPressed,
  })  : playlist = null,
        artist = null,
        mediaType = MediaType.album;

  const MediaDetailsPage.artist({
    super.key,
    required this.artist,
    this.onBackPressed,
  })  : playlist = null,
        album = null,
        mediaType = MediaType.artist;

  @override
  State<MediaDetailsPage> createState() => _MediaDetailsPageState();
}

class _MediaDetailsPageState extends State<MediaDetailsPage> {
  List<Track> _tracks = [];
  bool _isLoading = true;
  List<Album> _artistAlbums = [];
  List<Track> _popularTracks = [];
  bool _showArtistAlbums = false;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == MediaType.artist) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadArtistData());
    } else if (widget.mediaType == MediaType.album) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadTracks());
    } else {
      _loadTracks();
    }
  }

  void _loadArtistData() async {
    if (widget.artist == null || !mounted) return;
    final appState = context.read<AppState>();
    setState(() => _isLoading = true);
    try {
      if (appState.mediaServiceManager.currentServerType ==
          ServerType.youtubeMusic) {
        final tracks = await appState.mediaServiceManager.getArtistTracks(
          widget.artist!,
          limit: 100,
        );
        if (mounted) {
          setState(() {
            _popularTracks = tracks;
            _tracks = tracks;
            _artistAlbums = [];
            _isLoading = false;
          });
        }
        return;
      }
      final artistQuery = widget.artist!.name.toLowerCase();
      _artistAlbums = appState.albums.where((album) {
        final name = album.artistName?.toLowerCase();
        return name != null && name.contains(artistQuery);
      }).toList();
      _artistAlbums.sort((a, b) {
        final aYear = a.year ?? 0;
        final bYear = b.year ?? 0;
        return bYear.compareTo(aYear);
      });
      _popularTracks = appState.tracks
          .where((track) => _artistMatch(track.artistName, artistQuery))
          .toList();
      _tracks = _popularTracks;
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  bool _artistMatch(String? artistName, String queryLower) {
    if (artistName == null || artistName.isEmpty) return false;
    final value = artistName.toLowerCase();
    if (value == queryLower || value.contains(queryLower)) return true;
    return value
        .split(RegExp(r'[,/&]'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .contains(queryLower);
  }

  void _loadTracks() async {
    if (!mounted) return;

    final appState = context.read<AppState>();
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.mediaType == MediaType.playlist) {
        _tracks = await appState.getPlaylistTracks(widget.playlist!.id);
      } else {
        _tracks = await appState.getAlbumTracks(widget.album!.id);

        _tracks.sort((a, b) {
          final aTrack = a.trackNumber ?? 999;
          final bTrack = b.trackNumber ?? 999;
          return aTrack.compareTo(bTrack);
        });

        if (_tracks.isEmpty) {
          final fallbackTracks = appState.tracks
              .where(
                (track) =>
                    track.albumId == widget.album!.id ||
                    track.albumName?.toLowerCase() ==
                        widget.album!.name.toLowerCase(),
              )
              .toList();

          if (fallbackTracks.isNotEmpty) {
            _tracks = fallbackTracks;
          }
        }
      }
    } catch (_) {
      _tracks = [];
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _getImageUrl(AppState appState, String? imageId) {
    if (imageId == null) return null;
    return appState.getImageUrl(imageId);
  }

  void _refreshTracks() {
    if (widget.mediaType == MediaType.artist) {
      _loadArtistData();
    } else {
      _loadTracks();
    }
  }

  String get _title {
    if (widget.mediaType == MediaType.artist) return widget.artist!.name;
    if (widget.mediaType == MediaType.playlist) return widget.playlist!.name;
    return widget.album!.name;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: DesktopTheme.backgroundPrimary,
          child: PageTemplate(
            showBackButton: true,
            title: widget.mediaType == MediaType.playlist
                ? l10n.playlist
                : widget.mediaType == MediaType.artist
                ? l10n.artist
                : l10n.album,
            onBackPressed:
                widget.onBackPressed ?? () => Navigator.of(context).pop(),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;
                      final sidePadding = maxWidth >= 1200
                          ? 32.0
                          : maxWidth >= 900
                          ? 24.0
                          : 16.0;
                      return SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          sidePadding,
                          16,
                          sidePadding,
                          24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeroSection(
                              context,
                              appState,
                              l10n,
                              maxWidth,
                            ),
                            const SizedBox(height: 20),
                            if (widget.mediaType == MediaType.artist) ...[
                              _buildArtistTabs(l10n),
                              const SizedBox(height: 12),
                              _showArtistAlbums
                                  ? _buildArtistAlbumsPanel(
                                      context,
                                      appState,
                                      l10n,
                                    )
                                  : _buildTrackListPanel(
                                      context,
                                      appState,
                                      l10n,
                                      maxWidth,
                                    ),
                            ] else
                              _buildTrackListPanel(
                                context,
                                appState,
                                l10n,
                                maxWidth,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _buildHeroSection(
    BuildContext context,
    AppState appState,
    AppLocalizations l10n,
    double maxWidth,
  ) {
    final theme = Theme.of(context);
    final isWide = maxWidth >= 900;
    final imageSize = isWide ? 220.0 : 132.0;
    final imageUrl = widget.mediaType == MediaType.playlist
        ? widget.playlist!.imageUrl
        : widget.mediaType == MediaType.artist
        ? widget.artist!.imageUrl
        : widget.album!.imageUrl;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DesktopTheme.glassBorder),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DesktopTheme.backgroundSecondary,
            DesktopTheme.backgroundTertiary.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildArtworkCard(appState, imageUrl, imageSize),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildHeroMeta(
                      context,
                      appState,
                      l10n,
                      theme,
                      isWide: true,
                      includeActions: true,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildArtworkCard(appState, imageUrl, imageSize),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: DesktopTheme.backgroundDeep.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: DesktopTheme.glassBorder),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: _buildHeroMeta(
                            context,
                            appState,
                            l10n,
                            theme,
                            isWide: false,
                            includeActions: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildActionButtonsRow(appState, l10n),
                ],
              ),
      ),
    );
  }

  Widget _buildArtworkCard(AppState appState, String? imageId, double size) {
    final imageUrl = _getImageUrl(appState, imageId);
    final icon = widget.mediaType == MediaType.artist
        ? Icons.person_rounded
        : widget.mediaType == MediaType.playlist
        ? Icons.queue_music_rounded
        : Icons.album_rounded;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: DesktopTheme.backgroundElevated,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null
          ? Icon(icon, size: size * 0.45, color: DesktopTheme.textMuted)
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(icon, size: size * 0.45, color: DesktopTheme.textMuted),
            ),
    );
  }

  Widget _buildHeroMeta(
    BuildContext context,
    AppState appState,
    AppLocalizations l10n,
    ThemeData theme, {
    required bool isWide,
    required bool includeActions,
  }) {
    final mediaLabel = widget.mediaType == MediaType.playlist
        ? l10n.playlist
        : widget.mediaType == MediaType.artist
        ? l10n.artist
        : l10n.album;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            mediaLabel.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _title,
          maxLines: isWide ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: (isWide
                  ? theme.textTheme.headlineMedium
                  : theme.textTheme.headlineSmall)
              ?.copyWith(
            color: DesktopTheme.textPrimary,
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
        ),
        if (widget.mediaType == MediaType.album) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _navigateToArtist(l10n),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Text(
                widget.album!.artistName ?? l10n.unknownArtist,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStatPill(
              Icons.music_note_rounded,
              l10n.countSongs(_tracks.length),
            ),
            _buildStatPill(Icons.schedule_rounded, _getTotalDuration()),
            if (widget.mediaType == MediaType.album && widget.album!.year != null)
              _buildStatPill(
                Icons.calendar_today_rounded,
                widget.album!.year.toString(),
              ),
            if (widget.mediaType == MediaType.album &&
                widget.album!.dateCreated != null)
              _buildStatPill(
                Icons.add_circle_outline_rounded,
                '${l10n.added} ${_formatDate(widget.album!.dateCreated!, l10n)}',
              ),
          ],
        ),
        if (includeActions) ...[
          const SizedBox(height: 16),
          _buildActionButtonsRow(appState, l10n),
        ],
      ],
    );
  }

  Widget _buildStatPill(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: DesktopTheme.backgroundDeep.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DesktopTheme.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: DesktopTheme.textMuted),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: DesktopTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsRow(AppState appState, AppLocalizations l10n) {
    final isAlbumFollowed =
        widget.mediaType == MediaType.album && widget.album != null
        ? appState.isAlbumFollowed(widget.album!)
        : false;
    final isArtistFollowed =
        widget.mediaType == MediaType.artist && widget.artist != null
        ? appState.isArtistFollowed(widget.artist!)
        : false;
    final isPlaylistFollowed =
        widget.mediaType == MediaType.playlist && widget.playlist != null
        ? appState.isPlaylistFollowed(widget.playlist!)
        : false;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: _tracks.isEmpty
              ? null
              : () async {
                  await appState.playPlaylist(_tracks, 0);
                },
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(
            widget.mediaType == MediaType.playlist || widget.mediaType == MediaType.artist
                ? l10n.playAll
                : l10n.playAlbum,
          ),
        ),
        OutlinedButton.icon(
          onPressed: _tracks.isEmpty
              ? null
              : () async {
                  final shuffledTracks = List<Track>.from(_tracks)..shuffle();
                  await appState.playPlaylist(shuffledTracks, 0);
                },
          icon: const Icon(Icons.shuffle_rounded),
          label: Text(l10n.shuffle),
        ),
        if (widget.mediaType == MediaType.album && appState.downloadsEnabled)
          _buildAlbumDownloadButton(appState, l10n),
        if (widget.mediaType == MediaType.album && appState.isYoutubeMusic)
          FilledButton.tonalIcon(
            onPressed: () => appState.toggleAlbumFollow(widget.album!),
            icon: Icon(
              isAlbumFollowed
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
            label: Text(
              isAlbumFollowed
                  ? l10n.removeFromFavorites
                  : l10n.addToFavorites,
            ),
          ),
        if (widget.mediaType == MediaType.artist &&
            widget.artist != null &&
            appState.isYoutubeMusic)
          FilledButton.tonalIcon(
            onPressed: () => appState.toggleArtistFollow(widget.artist!),
            icon: Icon(
              isArtistFollowed
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
            label: Text(
              isArtistFollowed ? l10n.removeFromFavorites : l10n.followArtist,
            ),
          ),
        if (widget.mediaType == MediaType.playlist && appState.isYoutubeMusic)
          FilledButton.tonalIcon(
            onPressed: () => appState.togglePlaylistFollow(widget.playlist!),
            icon: Icon(
              isPlaylistFollowed
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
            label: Text(
              isPlaylistFollowed ? l10n.removeFromFavorites : l10n.addToFavorites,
            ),
          ),
        if (widget.mediaType == MediaType.album && !appState.isYoutubeMusic)
          IconButton(
            onPressed: () => appState.toggleAlbumFavorite(widget.album!),
            tooltip: isAlbumFollowed
                ? l10n.removeFromFavorites
                : l10n.addToFavorites,
            icon: Icon(
              isAlbumFollowed ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isAlbumFollowed ? Colors.redAccent : null,
            ),
          ),
        _buildMoreOptionsMenu(l10n),
      ],
    );
  }

  Widget _buildAlbumDownloadButton(AppState appState, AppLocalizations l10n) {
    final downloadService = appState.downloadService;
    final toDownload = _tracks
        .where((t) => !downloadService.isTrackDownloaded(t.id))
        .toList();
    final isAllDownloaded = toDownload.isEmpty;
    final anyDownloading = _tracks.any(
      (t) =>
          downloadService.getDownloadStatus(t.id) == DownloadStatus.downloading,
    );

    return Tooltip(
      message: isAllDownloaded
          ? l10n.downloadedSection
          : anyDownloading
          ? l10n.downloading
          : l10n.download,
      child: IconButton(
        onPressed: isAllDownloaded
            ? null
            : () async {
                if (toDownload.isEmpty) return;
                for (final track in toDownload) {
                  downloadService.downloadTrack(track);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.startedDownloading(toDownload.length, l10n.songs),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
        icon: Icon(
          isAllDownloaded
              ? Icons.download_done_rounded
              : Icons.download_rounded,
          size: 22,
        ),
        style: IconButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreOptionsMenu(AppLocalizations l10n) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'add_playlist':
            _showAddToPlaylistDialog(l10n);
            break;
          case 'download':
            if (widget.mediaType == MediaType.album) {
              _downloadAlbum(l10n);
            }
            break;
          case 'share':
            break;
          case 'artist':
            if (widget.mediaType == MediaType.album) {
              _navigateToArtist(l10n);
            }
            break;
          case 'edit':
            if (widget.mediaType == MediaType.playlist) {
              _showEditPlaylistDialog(l10n);
            }
            break;
          case 'delete':
            if (widget.mediaType == MediaType.playlist) {
              _showDeletePlaylistDialog(l10n);
            }
            break;
        }
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[];

        if (widget.mediaType == MediaType.album) {
          items.add(
            PopupMenuItem(
              value: 'add_playlist',
              child: ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: Text(l10n.addToPlaylist),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          );
          if (context.read<AppState>().downloadsEnabled) {
            items.add(
              PopupMenuItem(
                value: 'download',
                child: ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: Text(l10n.download),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            );
          }
        }

        items.add(
          PopupMenuItem(
            value: 'share',
            child: ListTile(
              leading: const Icon(Icons.share_rounded),
              title: Text(l10n.share),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        );

        if (widget.mediaType == MediaType.album) {
          items.add(
            PopupMenuItem(
              value: 'artist',
              child: ListTile(
                leading: const Icon(Icons.person_rounded),
                title: Text(l10n.goToArtist),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          );
        } else if (widget.mediaType == MediaType.playlist) {
          items.add(
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: Text(l10n.editPlaylist),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          );
          items.add(
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                title: Text(
                  l10n.deletePlaylist,
                  style: const TextStyle(color: Colors.red),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          );
        }
        return items;
      },
    );
  }

  Widget _buildTrackListPanel(
    BuildContext context,
    AppState appState,
    AppLocalizations l10n,
    double maxWidth,
  ) {
    final theme = Theme.of(context);
    if (_tracks.isEmpty && !_isLoading) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: DesktopTheme.backgroundSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DesktopTheme.glassBorder),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 56,
              color: DesktopTheme.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              widget.mediaType == MediaType.playlist
                  ? l10n.noTracksInPlaylist
                  : l10n.noTracksFound,
              style: theme.textTheme.titleLarge?.copyWith(
                color: DesktopTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.mediaType == MediaType.album
                  ? l10n.albumTracksEmptyMessage
                  : l10n.noTracksFound,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: DesktopTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _refreshTracks,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: DesktopTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesktopTheme.glassBorder),
      ),
      child: Column(
        children: [
          _buildTrackHeaderRow(theme, l10n, maxWidth),
          const Divider(height: 1),
          ...List.generate(
            _tracks.length,
            (index) => _buildTrackRow(
              context,
              appState,
              _tracks[index],
              index,
              l10n,
              maxWidth,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistTabs(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DesktopTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DesktopTheme.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildArtistTabChip(
            label: l10n.songs,
            selected: !_showArtistAlbums,
            onTap: () => setState(() => _showArtistAlbums = false),
          ),
          _buildArtistTabChip(
            label: l10n.albums,
            selected: _showArtistAlbums,
            onTap: () => setState(() => _showArtistAlbums = true),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistTabChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
              : Colors.transparent,
          foregroundColor: selected
              ? Theme.of(context).colorScheme.primary
              : DesktopTheme.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildArtistAlbumsPanel(
    BuildContext context,
    AppState appState,
    AppLocalizations l10n,
  ) {
    if (_artistAlbums.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: DesktopTheme.backgroundSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DesktopTheme.glassBorder),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          children: [
            Icon(Icons.album_outlined, size: 56, color: DesktopTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              l10n.noAlbumsFound,
              style: TextStyle(
                color: DesktopTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: DesktopTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesktopTheme.glassBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.74,
          crossAxisSpacing: DesktopTheme.spacingMd,
          mainAxisSpacing: DesktopTheme.spacingMd,
        ),
        itemCount: _artistAlbums.length,
        itemBuilder: (context, index) {
          final album = _artistAlbums[index];
          final imageUrl = album.imageUrl != null
              ? appState.getImageUrl(album.imageUrl!)
              : null;
          return KeyedSubtree(
            key: ValueKey(album.id),
            child: MusicCard(
              title: album.name,
              subtitle: album.artistName ?? l10n.unknownArtist,
              imageUrl: imageUrl,
              size: 180,
              onTap: () => NavigationService().navigateToAlbum(album),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrackHeaderRow(
    ThemeData theme,
    AppLocalizations l10n,
    double maxWidth,
  ) {
    final isWide = maxWidth >= 900;
    final showPlaylistColumns = widget.mediaType == MediaType.playlist && isWide;

    final style = theme.textTheme.labelMedium?.copyWith(
      color: DesktopTheme.textMuted,
      fontWeight: FontWeight.w700,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          const SizedBox(width: 36, child: Text('#')),
          const SizedBox(width: 10),
          Expanded(flex: 4, child: Text(l10n.title, style: style)),
          if (showPlaylistColumns) ...[
            const SizedBox(width: 10),
            Expanded(flex: 3, child: Text(l10n.artist, style: style)),
            const SizedBox(width: 10),
            Expanded(flex: 3, child: Text(l10n.album, style: style)),
          ],
          const SizedBox(width: 10),
          SizedBox(
            width: 56,
            child: Text(l10n.duration, style: style, textAlign: TextAlign.right),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildTrackRow(
    BuildContext context,
    AppState appState,
    Track track,
    int index,
    AppLocalizations l10n,
    double maxWidth,
  ) {
    final theme = Theme.of(context);
    final isWide = maxWidth >= 900;
    final showPlaylistColumns = widget.mediaType == MediaType.playlist && isWide;

    return InkWell(
      onTap: () async => appState.playPlaylist(_tracks, index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                (track.trackNumber ?? index + 1).toString(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: DesktopTheme.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: DesktopTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!showPlaylistColumns && track.artistName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${track.artistName}${track.albumName != null ? ' • ${track.albumName}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: DesktopTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showPlaylistColumns) ...[
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Text(
                  track.artistName ?? l10n.unknownArtist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: DesktopTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Text(
                  track.albumName ?? l10n.unknownAlbum,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: DesktopTheme.textSecondary,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 10),
            SizedBox(
              width: 56,
              child: Text(
                _formatDuration(track.duration ?? 0),
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: DesktopTheme.textMuted,
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'remove':
                    if (widget.mediaType == MediaType.playlist) {
                      _removeTrackFromPlaylist(track, l10n);
                    }
                    break;
                  case 'download':
                    break;
                }
              },
              itemBuilder: (context) {
                final items = <PopupMenuEntry<String>>[];
                if (widget.mediaType == MediaType.playlist) {
                  items.add(
                    PopupMenuItem(
                      value: 'remove',
                      child: ListTile(
                        leading: const Icon(Icons.remove_circle_outline_rounded),
                        title: Text(l10n.removeFromPlaylist),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  );
                }
                if (context.read<AppState>().downloadsEnabled) {
                  items.add(
                    PopupMenuItem(
                      value: 'download',
                      child: ListTile(
                        leading: const Icon(Icons.download_rounded),
                        title: Text(l10n.download),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  );
                }
                return items;
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _getTotalDuration() {
    final totalMs = _tracks.fold<int>(
      0,
      (sum, track) => sum + (track.duration ?? 0),
    );

    final duration = Duration(milliseconds: totalMs);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _formatDate(DateTime date, AppLocalizations l10n) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      return l10n.today;
    } else if (difference.inDays < 7) {
      return l10n.daysAgo(difference.inDays);
    } else if (difference.inDays < 30) {
      return l10n.weeksAgo((difference.inDays / 7).floor());
    } else {
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    }
  }

  // Album-specific methods
  void _navigateToArtist(AppLocalizations l10n) {
    if (widget.mediaType != MediaType.album) return;

    if (widget.album!.artistName == null) {
      return;
    }

    final appState = context.read<AppState>();

    // Find the artist by name in the artists list
    final artist = appState.artists.firstWhere(
      (artist) =>
          artist.name.toLowerCase() == widget.album!.artistName!.toLowerCase(),
      orElse: () => Artist(
        id: '', // We'll use empty ID as a fallback
        name: widget.album!.artistName!,
      ),
    );

    if (artist.id.isEmpty) {
      // Show a message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.artistNotFound(widget.album!.artistName!)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MediaDetailsPage.artist(artist: artist),
      ),
    );
  }

  void _downloadAlbum(AppLocalizations l10n) async {
    if (widget.mediaType != MediaType.album) return;

    final appState = context.read<AppState>();

    if (_tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.noTracksToDownload),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: l10n.downloadAlbum,
      message: l10n.downloadAlbumConfirmation(
        _tracks.length,
        widget.album!.name,
      ),
      confirmLabel: l10n.downloadAllTracks,
    );

    if (confirmed != true || !mounted) return;

    // Open all tracks in browser for download
    int successCount = 0;
    int failCount = 0;

    for (final track in _tracks) {
      try {
        final streamUrl = appState.mediaServiceManager.getStreamUrl(track.id);
        final uri = Uri.parse(streamUrl);

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          successCount++;
          // Add a small delay between opening URLs to prevent overwhelming the browser
          await Future.delayed(const Duration(milliseconds: 500));
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }
    }

    if (mounted) {
      if (failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.openedTracksInBrowser(successCount, widget.album!.name),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.openedTracksPartialSuccess(
                successCount,
                failCount,
                widget.album!.name,
              ),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _showAddToPlaylistDialog(AppLocalizations l10n) {
    final appState = context.read<AppState>();
    showAppDialog(
      context: context,
      title: widget.mediaType == MediaType.album
          ? l10n.addAlbumToPlaylist
          : l10n.addTracksToPlaylist,
      width: 320,
      maxHeight: 420,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.add),
            title: Text(l10n.createNewPlaylist),
            onTap: () {
              Navigator.of(context).pop();
              _showCreatePlaylistDialog(l10n);
            },
          ),
          const Divider(),
          ListView.builder(
            shrinkWrap: true,
            itemCount: appState.playlists.length,
            itemBuilder: (context, index) {
              final playlist = appState.playlists[index];
              return ListTile(
                leading: const Icon(Icons.playlist_play),
                title: Text(playlist.name),
                subtitle: Text(l10n.countSongs(playlist.trackCount)),
                onTap: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.addedToPlaylist(
                          widget.mediaType == MediaType.album
                              ? l10n.album
                              : 'tracks',
                          playlist.name,
                          _title,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      actionsBuilder: (dialogContext) => [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }

  void _showCreatePlaylistDialog(AppLocalizations l10n) {
    final nameController = TextEditingController();
    showAppDialog(
      context: context,
      title: l10n.createPlaylist,
      content: TextField(
        controller: nameController,
        decoration: InputDecoration(
          labelText: l10n.playlistName,
          border: const OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actionsBuilder: (dialogContext) => [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            if (nameController.text.trim().isNotEmpty) {
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    l10n.createdPlaylistWithTracks(
                      nameController.text,
                      widget.mediaType == MediaType.album ? l10n.album : '',
                    ),
                  ),
                ),
              );
            }
          },
          child: Text(l10n.create),
        ),
      ],
    );
  }

  // Playlist-specific methods
  void _showEditPlaylistDialog(AppLocalizations l10n) {
    if (widget.mediaType != MediaType.playlist) return;
    showAppDialog(
      context: context,
      title: l10n.editPlaylist,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: l10n.playlistName,
              border: const OutlineInputBorder(),
            ),
            controller: TextEditingController(text: widget.playlist!.name),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              labelText: l10n.descriptionOptional,
              border: const OutlineInputBorder(),
            ),
            controller: TextEditingController(text: ''),
            maxLines: 3,
          ),
        ],
      ),
      actionsBuilder: (dialogContext) => [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            // Save playlist changes
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }

  void _showDeletePlaylistDialog(AppLocalizations l10n) async {
    if (widget.mediaType != MediaType.playlist) return;
    final ok = await showAppConfirmDialog(
      context: context,
      title: l10n.deletePlaylist,
      message: l10n.deletePlaylistConfirmation(widget.playlist!.name),
      confirmLabel: l10n.delete,
      isDestructive: true,
    );
    if (ok == true && mounted) {
      Navigator.of(context).pop(); // Go back to playlists page
      // Delete playlist
    }
  }

  void _removeTrackFromPlaylist(Track track, AppLocalizations l10n) {
    if (widget.mediaType != MediaType.playlist) return;

    setState(() {
      _tracks.remove(track);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.removedFromPlaylist(track.name)),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () {
            // Undo remove track
          },
        ),
      ),
    );
  }
}
