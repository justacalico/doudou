import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/l10n.dart';
import '../../../models/jellyfin_models.dart';
import '../../../providers/app_state.dart';

void openAlbumDetailView(
  BuildContext context, {
  required Album album,
  required bool isCupertino,
}) {
  Navigator.of(context).push(
    _adaptiveRoute(
      isCupertino: isCupertino,
      builder: (_) => _AlbumDetailView(album: album, isCupertino: isCupertino),
    ),
  );
}

void openPlaylistDetailView(
  BuildContext context, {
  required Playlist playlist,
  required bool isCupertino,
}) {
  Navigator.of(context).push(
    _adaptiveRoute(
      isCupertino: isCupertino,
      builder: (_) =>
          _PlaylistDetailView(playlist: playlist, isCupertino: isCupertino),
    ),
  );
}

void openArtistDetailView(
  BuildContext context, {
  required Artist artist,
  required bool isCupertino,
}) {
  Navigator.of(context).push(
    _adaptiveRoute(
      isCupertino: isCupertino,
      builder: (_) =>
          _ArtistDetailView(artist: artist, isCupertino: isCupertino),
    ),
  );
}

Route<void> _adaptiveRoute({
  required bool isCupertino,
  required WidgetBuilder builder,
}) {
  if (isCupertino) {
    return CupertinoPageRoute<void>(builder: builder);
  }

  return MaterialPageRoute<void>(builder: builder);
}

class _AlbumDetailView extends StatefulWidget {
  const _AlbumDetailView({required this.album, required this.isCupertino});

  final Album album;
  final bool isCupertino;

  @override
  State<_AlbumDetailView> createState() => _AlbumDetailViewState();
}

class _AlbumDetailViewState extends State<_AlbumDetailView> {
  late Future<List<Track>> _tracksFuture;

  @override
  void initState() {
    super.initState();
    _tracksFuture = context.read<AppState>().getAlbumTracks(widget.album.id);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final artist = _findArtistByName(appState.artists, widget.album.artistName);

    return _DetailScaffold(
      isCupertino: widget.isCupertino,
      title: widget.album.name,
      child: FutureBuilder<List<Track>>(
        future: _tracksFuture,
        builder: (context, snapshot) {
          final tracks = snapshot.data ?? const <Track>[];

          return _DetailBody(
            isCupertino: widget.isCupertino,
            artworkId: widget.album.imageUrl,
            title: widget.album.name,
            subtitle: widget.album.artistName,
            statsLabel: context.l10n.tracksCount(tracks.length),
            secondaryAction: artist == null
                ? null
                : () => openArtistDetailView(
                    context,
                    artist: artist,
                    isCupertino: widget.isCupertino,
                  ),
            secondaryActionLabel: artist == null
                ? null
                : context.l10n.navArtists,
            onPlayAll: tracks.isEmpty
                ? null
                : () => appState.playPlaylist(tracks, 0),
            onShuffle: tracks.isEmpty
                ? null
                : () {
                    final shuffled = List<Track>.from(tracks)..shuffle();
                    appState.playPlaylist(shuffled, 0);
                  },
            trackList: tracks,
            isLoading: snapshot.connectionState == ConnectionState.waiting,
          );
        },
      ),
    );
  }
}

class _PlaylistDetailView extends StatefulWidget {
  const _PlaylistDetailView({
    required this.playlist,
    required this.isCupertino,
  });

  final Playlist playlist;
  final bool isCupertino;

  @override
  State<_PlaylistDetailView> createState() => _PlaylistDetailViewState();
}

class _PlaylistDetailViewState extends State<_PlaylistDetailView> {
  late Future<List<Track>> _tracksFuture;

  @override
  void initState() {
    super.initState();
    _tracksFuture = context.read<AppState>().getPlaylistTracks(
      widget.playlist.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return _DetailScaffold(
      isCupertino: widget.isCupertino,
      title: widget.playlist.name,
      child: FutureBuilder<List<Track>>(
        future: _tracksFuture,
        builder: (context, snapshot) {
          final tracks = snapshot.data ?? const <Track>[];

          return _DetailBody(
            isCupertino: widget.isCupertino,
            artworkId: widget.playlist.imageUrl,
            title: widget.playlist.name,
            subtitle: context.l10n.playlist,
            statsLabel: context.l10n.tracksCount(tracks.length),
            onPlayAll: tracks.isEmpty
                ? null
                : () => appState.playPlaylist(tracks, 0),
            onShuffle: tracks.isEmpty
                ? null
                : () {
                    final shuffled = List<Track>.from(tracks)..shuffle();
                    appState.playPlaylist(shuffled, 0);
                  },
            trackList: tracks,
            isLoading: snapshot.connectionState == ConnectionState.waiting,
          );
        },
      ),
    );
  }
}

class _ArtistDetailView extends StatelessWidget {
  const _ArtistDetailView({required this.artist, required this.isCupertino});

  final Artist artist;
  final bool isCupertino;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final tracks = appState.tracks
        .where(
          (track) => (track.artistName ?? '').toLowerCase().contains(
            artist.name.toLowerCase(),
          ),
        )
        .toList();

    final albums = appState.albums
        .where(
          (album) => (album.artistName ?? '').toLowerCase().contains(
            artist.name.toLowerCase(),
          ),
        )
        .toList();

    return _DetailScaffold(
      isCupertino: isCupertino,
      title: artist.name,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DetailHeader(
            isCupertino: isCupertino,
            artworkId: artist.imageUrl,
            title: artist.name,
            subtitle: context.l10n.navArtists,
            statsLabel:
                '${context.l10n.albumsCount(albums.length)} • ${context.l10n.tracksCount(tracks.length)}',
          ),
          const SizedBox(height: 12),
          _DetailActions(
            isCupertino: isCupertino,
            onPlayAll: tracks.isEmpty
                ? null
                : () => appState.playPlaylist(tracks, 0),
            onShuffle: tracks.isEmpty
                ? null
                : () {
                    final shuffled = List<Track>.from(tracks)..shuffle();
                    appState.playPlaylist(shuffled, 0);
                  },
          ),
          const SizedBox(height: 14),
          if (albums.isNotEmpty)
            _DetailSection(
              title: context.l10n.navAlbums,
              child: SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: albums.length,
                  separatorBuilder: (_, index) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final album = albums[index];
                    return SizedBox(
                      width: 128,
                      child: GestureDetector(
                        onTap: () => openAlbumDetailView(
                          context,
                          album: album,
                          isCupertino: isCupertino,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DetailArtwork(imageId: album.imageUrl, size: 96),
                            const SizedBox(height: 6),
                            Text(
                              album.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          const SizedBox(height: 10),
          _DetailSection(
            title: context.l10n.navTracks,
            child: _DetailTrackList(
              tracks: tracks,
              isCupertino: isCupertino,
              emptyLabel: context.l10n.libraryAppearsEmpty,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({
    required this.isCupertino,
    required this.title,
    required this.child,
  });

  final bool isCupertino;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (isCupertino) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text(title)),
        child: SafeArea(child: child),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.isCupertino,
    required this.artworkId,
    required this.title,
    required this.subtitle,
    required this.statsLabel,
    required this.onPlayAll,
    required this.onShuffle,
    required this.trackList,
    required this.isLoading,
    this.secondaryAction,
    this.secondaryActionLabel,
  });

  final bool isCupertino;
  final String? artworkId;
  final String title;
  final String? subtitle;
  final String statsLabel;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffle;
  final VoidCallback? secondaryAction;
  final String? secondaryActionLabel;
  final List<Track> trackList;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DetailHeader(
          isCupertino: isCupertino,
          artworkId: artworkId,
          title: title,
          subtitle: subtitle,
          statsLabel: statsLabel,
        ),
        const SizedBox(height: 12),
        _DetailActions(
          isCupertino: isCupertino,
          onPlayAll: onPlayAll,
          onShuffle: onShuffle,
          secondaryAction: secondaryAction,
          secondaryActionLabel: secondaryActionLabel,
        ),
        const SizedBox(height: 16),
        if (isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: isCupertino
                  ? const CupertinoActivityIndicator(radius: 14)
                  : const CircularProgressIndicator(),
            ),
          )
        else
          _DetailTrackList(
            tracks: trackList,
            isCupertino: isCupertino,
            emptyLabel: context.l10n.libraryAppearsEmpty,
          ),
      ],
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.isCupertino,
    required this.artworkId,
    required this.title,
    required this.subtitle,
    required this.statsLabel,
  });

  final bool isCupertino;
  final String? artworkId;
  final String title;
  final String? subtitle;
  final String statsLabel;

  @override
  Widget build(BuildContext context) {
    final color = isCupertino
        ? CupertinoColors.secondaryLabel.resolveFrom(context)
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailArtwork(imageId: artworkId, size: 100),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(subtitle!, style: TextStyle(color: color)),
              const SizedBox(height: 4),
              Text(statsLabel, style: TextStyle(color: color)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailActions extends StatelessWidget {
  const _DetailActions({
    required this.isCupertino,
    required this.onPlayAll,
    required this.onShuffle,
    this.secondaryAction,
    this.secondaryActionLabel,
  });

  final bool isCupertino;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffle;
  final VoidCallback? secondaryAction;
  final String? secondaryActionLabel;

  @override
  Widget build(BuildContext context) {
    if (isCupertino) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          CupertinoButton.filled(
            onPressed: onPlayAll,
            child: Text(context.l10n.playAll),
          ),
          CupertinoButton(
            onPressed: onShuffle,
            child: Text(context.l10n.shuffleAll),
          ),
          if (secondaryAction != null && secondaryActionLabel != null)
            CupertinoButton(
              onPressed: secondaryAction,
              child: Text(secondaryActionLabel!),
            ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: onPlayAll,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(context.l10n.playAll),
        ),
        OutlinedButton.icon(
          onPressed: onShuffle,
          icon: const Icon(Icons.shuffle_rounded),
          label: Text(context.l10n.shuffleAll),
        ),
        if (secondaryAction != null && secondaryActionLabel != null)
          OutlinedButton(
            onPressed: secondaryAction,
            child: Text(secondaryActionLabel!),
          ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _DetailTrackList extends StatelessWidget {
  const _DetailTrackList({
    required this.tracks,
    required this.isCupertino,
    required this.emptyLabel,
  });

  final List<Track> tracks;
  final bool isCupertino;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();

    if (tracks.isEmpty) {
      return Text(emptyLabel);
    }

    return Column(
      children: tracks.map((track) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isCupertino
                ? CupertinoColors.secondarySystemBackground.resolveFrom(context)
                : Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _DetailArtwork(
                  imageId: track.imageUrl ?? track.albumId,
                  size: 42,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${track.artistName ?? '-'} • ${_formatTrackDuration(track)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCupertino
                              ? CupertinoColors.secondaryLabel.resolveFrom(
                                  context,
                                )
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCupertino)
                  CupertinoButton(
                    minSize: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    onPressed: () => appState.playTrack(track),
                    child: const Icon(CupertinoIcons.play_fill, size: 20),
                  )
                else
                  IconButton(
                    onPressed: () => appState.playTrack(track),
                    icon: const Icon(Icons.play_arrow_rounded),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DetailArtwork extends StatelessWidget {
  const _DetailArtwork({required this.imageId, required this.size});

  final String? imageId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final raw = imageId;

    if (raw == null || raw.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.music_note_rounded),
      );
    }

    final url = appState.getImageUrl(
      raw,
      width: size.round() * 2,
      height: size.round() * 2,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: Colors.grey.shade400,
            child: const Icon(Icons.music_note_rounded),
          ),
        ),
      ),
    );
  }
}

Artist? _findArtistByName(List<Artist> artists, String? name) {
  if (name == null || name.trim().isEmpty) {
    return null;
  }

  final query = name.trim().toLowerCase();
  for (final artist in artists) {
    if (artist.name.toLowerCase() == query ||
        artist.name.toLowerCase().contains(query)) {
      return artist;
    }
  }

  return null;
}

String _formatTrackDuration(Track track) {
  if (track.duration == null || track.duration! <= 0) {
    return '--:--';
  }

  final totalSeconds = track.duration! ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
