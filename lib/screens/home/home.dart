import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../shared/detail_track_view.dart';
import '../settings/settings.dart';

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  List<Album>? _shuffledAlbums;
  List<Album>? _continueListeningAlbums;
  List<Album>? _madeForYouAlbums;
  List<Album>? _recommendedAlbums;
  List<Album>? _similarToFavoritesAlbums;
  
  // Add debouncing for shuffle buttons to prevent audio bleeding
  DateTime? _lastShuffleAllTap;
  DateTime? _lastShuffleFavoritesTap;

  void _initializeAlbumLists(List<Album> allAlbums, List<Track> favoriteTracks) {
    if (_shuffledAlbums == null || _shuffledAlbums!.isEmpty) {
      _shuffledAlbums = List<Album>.from(allAlbums)..shuffle();
      
      // Get personalized recommendations based on favorites
      _recommendedAlbums = _getRecommendedAlbums(allAlbums, favoriteTracks);
      _continueListeningAlbums = _getContinueListeningAlbums(allAlbums, favoriteTracks);
      _madeForYouAlbums = _getMadeForYouAlbums(allAlbums, favoriteTracks);
      _similarToFavoritesAlbums = _getSimilarToFavoritesAlbums(allAlbums, favoriteTracks);
    }
  }

  List<Album> _getRecommendedAlbums(List<Album> allAlbums, List<Track> favoriteTracks) {
    // Sort albums by date added (most recent first)
    final sortedAlbums = List<Album>.from(allAlbums);
    sortedAlbums.sort((a, b) {
      // If both albums have dateCreated, compare them
      if (a.dateCreated != null && b.dateCreated != null) {
        return b.dateCreated!.compareTo(a.dateCreated!);
      }
      // If only one has dateCreated, prioritize it
      if (a.dateCreated != null) return -1;
      if (b.dateCreated != null) return 1;
      // If neither has dateCreated, maintain original order
      return 0;
    });
    
    return sortedAlbums.take(6).toList();
  }

  List<Album> _getContinueListeningAlbums(List<Album> allAlbums, List<Track> favoriteTracks) {
    if (favoriteTracks.isEmpty) {
      return allAlbums.take(4).toList();
    }

    // Get albums that contain favorite tracks
    final favoriteAlbumIds = favoriteTracks
        .where((track) => track.albumId != null)
        .map((track) => track.albumId!)
        .toSet();

    final continueListeningAlbums = allAlbums
        .where((album) => favoriteAlbumIds.contains(album.id))
        .toList();

    return continueListeningAlbums.take(4).toList();
  }

  List<Album> _getMadeForYouAlbums(List<Album> allAlbums, List<Track> favoriteTracks) {
    if (favoriteTracks.isEmpty) {
      return allAlbums.take(4).toList();
    }

    // Get albums from the same artists as favorite tracks
    final favoriteArtistNames = favoriteTracks
        .where((track) => track.artistName != null)
        .map((track) => track.artistName!)
        .toSet();

    final albumsByFavoriteArtists = allAlbums
        .where((album) => 
            album.artistName != null && 
            favoriteArtistNames.contains(album.artistName!))
        .toList();

    // Remove albums that contain favorite tracks (to avoid duplicates with continue listening)
    final favoriteAlbumIds = favoriteTracks
        .where((track) => track.albumId != null)
        .map((track) => track.albumId!)
        .toSet();

    final madeForYou = albumsByFavoriteArtists
        .where((album) => !favoriteAlbumIds.contains(album.id))
        .toList()
      ..shuffle();

    if (madeForYou.length >= 4) {
      return madeForYou.take(4).toList();
    }

    // Fill with other albums if needed
    final otherAlbums = allAlbums
        .where((album) => 
            (album.artistName == null || !favoriteArtistNames.contains(album.artistName!)) &&
            !favoriteAlbumIds.contains(album.id))
        .toList()
      ..shuffle();

    madeForYou.addAll(otherAlbums.take(4 - madeForYou.length));
    return madeForYou;
  }

  List<Album> _getSimilarToFavoritesAlbums(List<Album> allAlbums, List<Track> favoriteTracks) {
    if (favoriteTracks.isEmpty) {
      return [];
    }

    // Get albums from the same artists as favorite tracks
    final favoriteArtistNames = favoriteTracks
        .where((track) => track.artistName != null)
        .map((track) => track.artistName!)
        .toSet();

    // Get albums that user hasn't favorited tracks from yet
    final favoriteAlbumIds = favoriteTracks
        .where((track) => track.albumId != null)
        .map((track) => track.albumId!)
        .toSet();

    final similarAlbums = allAlbums
        .where((album) => 
            album.artistName != null && 
            favoriteArtistNames.contains(album.artistName!) &&
            !favoriteAlbumIds.contains(album.id))
        .toList()
      ..shuffle();

    return similarAlbums.take(6).toList();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  void _showNoFavoritesDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('No Favorites'),
        content: const Text('You haven\'t marked any songs as favorites yet. Add some favorites to use this shuffle option.'),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final allAlbums = List<Album>.from(appState.albums);
        final favoriteTracks = List<Track>.from(appState.favoriteTracks);
        _initializeAlbumLists(allAlbums, favoriteTracks);
        
        final recentAlbums = _recommendedAlbums ?? allAlbums.take(6).toList();
        final continueListeningAlbums = _continueListeningAlbums ?? allAlbums.take(4).toList();
        final madeForYouAlbums = _madeForYouAlbums ?? allAlbums.take(4).toList();
        final similarToFavoritesAlbums = _similarToFavoritesAlbums ?? [];

        return CupertinoPageScaffold(
          backgroundColor: const Color(0xFF0A0A0A), // Deeper black for premium feel
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Enhanced header with better typography and spacing
              SliverPersistentHeader(
                floating: true,
                delegate: _SliverHeaderDelegate(
                  minHeight: 90,
                  maxHeight: 140,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF0A0A0A),
                          Color(0xFF0A0A0A),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          offset: const Offset(0, 2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                      child: Row(
                        children: [
                          // Enhanced profile picture with gradient border
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE91E63), Color(0xFFAD1457)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE91E63).withOpacity(0.3),
                                  offset: const Offset(0, 4),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.person_fill,
                              color: CupertinoColors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Enhanced greeting with better typography
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _getGreeting(),
                                  style: TextStyle(
                                    color: CupertinoColors.systemGrey.withOpacity(0.8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'What would you like to hear?',
                                  style: const TextStyle(
                                    color: CupertinoColors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    height: 1.1,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Enhanced settings button
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E).withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                // TODO: Navigate to settings
                              },
                              child: const Icon(
                                CupertinoIcons.gear_alt,
                                color: CupertinoColors.systemGrey,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
              
              // Enhanced shuffle buttons with better design
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth > 600;
                      
                      if (isDesktop) {
                        // Desktop layout: centered buttons with better spacing
                        return Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildEnhancedShuffleButton(
                                    icon: CupertinoIcons.shuffle,
                                    label: 'Shuffle all',
                                    onPressed: () async {
                                      // CRITICAL FIX: Add UI-level debouncing to prevent rapid taps
                                      final now = DateTime.now();
                                      if (_lastShuffleAllTap != null && 
                                          now.difference(_lastShuffleAllTap!) < const Duration(milliseconds: 1000)) {
                                        if (kDebugMode) {
                                          print('Shuffle all button debounced - ${now.difference(_lastShuffleAllTap!).inMilliseconds}ms since last tap');
                                        }
                                        return; // Ignore rapid taps
                                      }
                                      _lastShuffleAllTap = now;
                                      
                                      await appState.shuffleAllTracks();
                                    },
                                    isPrimary: true,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildEnhancedShuffleButton(
                                    icon: CupertinoIcons.heart_fill,
                                    label: 'Shuffle favorites',
                                    onPressed: () async {
                                      // CRITICAL FIX: Add UI-level debouncing to prevent rapid taps
                                      final now = DateTime.now();
                                      if (_lastShuffleFavoritesTap != null && 
                                          now.difference(_lastShuffleFavoritesTap!) < const Duration(milliseconds: 1000)) {
                                        if (kDebugMode) {
                                          print('Shuffle favorites button debounced - ${now.difference(_lastShuffleFavoritesTap!).inMilliseconds}ms since last tap');
                                        }
                                        return; // Ignore rapid taps
                                      }
                                      _lastShuffleFavoritesTap = now;
                                      
                                      final favoriteCount = appState.favoriteTracks.length;
                                      if (favoriteCount > 0) {
                                        await appState.shuffleFavoriteTracks();
                                      } else {
                                        _showNoFavoritesDialog(context);
                                      }
                                    },
                                    isPrimary: false,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        // Mobile layout with two buttons
                        return Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildEnhancedShuffleButton(
                                icon: CupertinoIcons.shuffle,
                                label: 'Shuffle all',
                                onPressed: () async {
                                  await appState.shuffleAllTracks();
                                },
                                isPrimary: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildEnhancedShuffleButton(
                                icon: CupertinoIcons.heart_fill,
                                label: 'Favorites',
                                onPressed: () async {
                                  final favoriteCount = appState.favoriteTracks.length;
                                  if (favoriteCount > 0) {
                                    await appState.shuffleFavoriteTracks();
                                  } else {
                                    _showNoFavoritesDialog(context);
                                  }
                                },
                                isPrimary: false,
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
              
              // Enhanced "Listen now" section at the top if playing
              if (appState.audioHandler?.currentTrack != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Listen now', CupertinoIcons.speaker_3),
                        const SizedBox(height: 20),
                        _buildEnhancedListenNowCard(context, appState),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              
              // Continue listening section with enhanced design
              if (continueListeningAlbums.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: _buildSectionHeader('Continue listening', CupertinoIcons.clock),
                  ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 280,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: continueListeningAlbums.take(8).length,
                      itemBuilder: (context, index) {
                        final album = continueListeningAlbums[index];
                        return _buildEnhancedContinueListeningCard(context, album, appState);
                      },
                    ),
                  ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
              
              // Recently added albums with enhanced design
              if (recentAlbums.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: _buildSectionHeader('Recently added', CupertinoIcons.plus_circle),
                  ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200, // Reduced from 220 to prevent overflow
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: recentAlbums.take(10).length,
                      itemBuilder: (context, index) {
                        final album = recentAlbums[index];
                        return _buildEnhancedAlbumCard(context, album, appState);
                      },
                    ),
                  ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
              
              // Made for you section
              if (madeForYouAlbums.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: _buildSectionHeader('Made for you', CupertinoIcons.sparkles),
                  ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: madeForYouAlbums.take(8).length,
                      itemBuilder: (context, index) {
                        final album = madeForYouAlbums[index];
                        return _buildEnhancedPlaylistCard(context, album, appState);
                      },
                    ),
                  ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
              
              // Favorite albums section
              if (similarToFavoritesAlbums.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: _buildSectionHeader('Your favorites', CupertinoIcons.heart_fill),
                  ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200, // Reduced from 240 to prevent overflow
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: similarToFavoritesAlbums.take(8).length,
                      itemBuilder: (context, index) {
                        final album = similarToFavoritesAlbums[index];
                        return _buildEnhancedFavoriteAlbumCard(context, album, appState);
                      },
                    ),
                  ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
              
              const SliverToBoxAdapter(child: SizedBox(height: 120)), // Extra space for mini player and nav
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFE91E63).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFE91E63),
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedListenNowCard(BuildContext context, AppState appState) {
    final currentTrack = appState.audioHandler?.currentTrack;
    if (currentTrack == null) return Container();

    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1C1C1E).withOpacity(0.8),
            const Color(0xFF2C2C2E).withOpacity(0.6),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFE91E63).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withOpacity(0.1),
            offset: const Offset(0, 8),
            blurRadius: 24,
          ),
        ],
      ),
      child: Row(
        children: [
          // Album art with overlay
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
                child: Container(
                  width: 140,
                  height: 140,
                  color: const Color(0xFF2D2D2D),
                  child: currentTrack.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: appState.getImageUrl(
                            currentTrack.imageUrl!,
                            width: 300,
                            height: 300,
                          ),
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => const Icon(
                            CupertinoIcons.music_note,
                            size: 40,
                            color: CupertinoColors.systemGrey,
                          ),
                        )
                      : const Icon(
                          CupertinoIcons.music_note,
                          size: 40,
                          color: CupertinoColors.systemGrey,
                        ),
                ),
              ),
              // Audio wave overlay
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.waveform,
                        color: Color(0xFFE91E63),
                        size: 12,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Now playing',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Track info and play button
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentTrack.artistName ?? 'Unknown Artist',
                    style: TextStyle(
                      color: CupertinoColors.systemGrey.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currentTrack.name,
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          // Enhanced play button
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFAD1457)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE91E63).withOpacity(0.4),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.play_fill,
                color: CupertinoColors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedContinueListeningCard(BuildContext context, Album album, AppState appState) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => DetailTrackView.album(album),
          ),
        );
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1C1C1E).withOpacity(0.8),
              const Color(0xFF2C2C2E).withOpacity(0.4),
            ],
          ),
          border: Border.all(
            color: const Color(0xFF3C3C3E).withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              offset: const Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Container(
                height: 200,
                width: 200,
                color: const Color(0xFF2D2D2D),
                child: album.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: appState.getImageUrl(
                          album.imageUrl!,
                          width: 400,
                          height: 400,
                        ),
                        fit: BoxFit.cover,
                        width: 200,
                        height: 200,
                        placeholder: (context, url) => const Center(
                          child: CupertinoActivityIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          CupertinoIcons.music_albums,
                          size: 60,
                          color: CupertinoColors.systemGrey,
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.music_albums,
                        size: 60,
                        color: CupertinoColors.systemGrey,
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        album.name,
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (album.artistName != null) ...[
                      const SizedBox(height: 4),
                      Flexible(
                        child: Text(
                          album.artistName!,
                          style: TextStyle(
                            color: CupertinoColors.systemGrey.withOpacity(0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedAlbumCard(BuildContext context, Album album, AppState appState) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => DetailTrackView.album(album),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF1C1C1E).withOpacity(0.6),
          border: Border.all(
            color: const Color(0xFF3C3C3E).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                height: 140, // Reduced from 160 to fit in 200px container
                width: 160,
                color: const Color(0xFF2D2D2D),
                child: album.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: appState.getImageUrl(
                          album.imageUrl!,
                          width: 300,
                          height: 300,
                        ),
                        fit: BoxFit.cover,
                        width: 160,
                        height: 140,
                        placeholder: (context, url) => const Center(
                          child: CupertinoActivityIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          CupertinoIcons.music_albums,
                          size: 50,
                          color: CupertinoColors.systemGrey,
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.music_albums,
                        size: 50,
                        color: CupertinoColors.systemGrey,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8), // Reduced from 12 to 8
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.name,
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (album.artistName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      album.artistName!,
                      style: TextStyle(
                        color: CupertinoColors.systemGrey.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedPlaylistCard(BuildContext context, Album album, AppState appState) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => DetailTrackView.album(album),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 140,
                width: 140,
                color: const Color(0xFF2D2D2D),
                child: album.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: appState.getImageUrl(
                          album.imageUrl!,
                          width: 300,
                          height: 300,
                        ),
                        fit: BoxFit.cover,
                        width: 140,
                        height: 140,
                        placeholder: (context, url) => const Center(
                          child: CupertinoActivityIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          CupertinoIcons.music_albums,
                          size: 40,
                          color: CupertinoColors.systemGrey,
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.music_albums,
                        size: 40,
                        color: CupertinoColors.systemGrey,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              album.name,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedFavoriteAlbumCard(BuildContext context, Album album, AppState appState) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => DetailTrackView.album(album),
          ),
        );
      },
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF1C1C1E).withOpacity(0.6),
          border: Border.all(
            color: const Color(0xFFE91E63).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                height: 140, // Reduced from 180 to fit in container
                width: 180,
                color: const Color(0xFF2D2D2D),
                child: album.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: appState.getImageUrl(
                          album.imageUrl!,
                          width: 400,
                          height: 400,
                        ),
                        fit: BoxFit.cover,
                        width: 180,
                        height: 140,
                        placeholder: (context, url) => const Center(
                          child: CupertinoActivityIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          CupertinoIcons.music_albums,
                          size: 50,
                          color: CupertinoColors.systemGrey,
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.music_albums,
                        size: 50,
                        color: CupertinoColors.systemGrey,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8), // Reduced from 12 to 8
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.name,
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (album.artistName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      album.artistName!,
                      style: TextStyle(
                        color: CupertinoColors.systemGrey.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedShuffleButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          gradient: isPrimary 
              ? const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFAD1457)],
                )
              : LinearGradient(
                  colors: [
                    const Color(0xFF1C1C1E).withOpacity(0.8),
                    const Color(0xFF2C2C2E).withOpacity(0.6),
                  ],
                ),
          borderRadius: BorderRadius.circular(18),
          border: isPrimary 
              ? null
              : Border.all(
                  color: const Color(0xFFE91E63).withOpacity(0.3),
                  width: 1,
                ),
          boxShadow: [
            BoxShadow(
              color: isPrimary 
                  ? const Color(0xFFE91E63).withOpacity(0.4)
                  : Colors.black.withOpacity(0.2),
              offset: const Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              color: isPrimary 
                  ? CupertinoColors.white
                  : const Color(0xFFE91E63), 
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isPrimary 
                    ? CupertinoColors.white
                    : const Color(0xFFE91E63),
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SliverHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}