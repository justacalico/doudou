import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../widgets/apple_design/apple_theme.dart';
import 'details/media_details.dart';
import 'details/artist_details.dart';

// Helper class for filter data
class _FilterData {
  final String key;
  final String label;
  final int count;
  final IconData icon;
  
  const _FilterData(this.key, this.label, this.count, this.icon);
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  String _selectedFilter = 'all';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  // Animation controller for staggered animations
  late AnimationController _animationController;
  
  // Track hover states for interactive elements
  int? _hoveredResultIndex;
  String? _hoveredCategory;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.albums.isEmpty || appState.artists.isEmpty || appState.tracks.isEmpty) {
        appState.loadLibraryData();
      }
    });
  }

  String? _getImageUrl(AppState appState, String? imageId) {
    if (imageId == null) return null;
    return appState.getImageUrl(imageId);
  }

  Map<String, List<dynamic>> _getSearchResults(AppState appState) {
    if (_searchQuery.isEmpty) {
      return {
        'tracks': [],
        'albums': [],
        'artists': [],
        'playlists': [],
      };
    }

    // Browse all mode - show all items
    if (_searchQuery == '*') {
      return {
        'tracks': appState.tracks,
        'albums': appState.albums,
        'artists': appState.artists,
        'playlists': appState.playlists,
      };
    }

    final query = _searchQuery.toLowerCase();

    final tracks = appState.tracks.where((track) {
      return track.name.toLowerCase().contains(query) ||
             (track.artistName?.toLowerCase().contains(query) ?? false) ||
             (track.albumName?.toLowerCase().contains(query) ?? false);
    }).toList();

    final albums = appState.albums.where((album) {
      return album.name.toLowerCase().contains(query) ||
             (album.artistName?.toLowerCase().contains(query) ?? false);
    }).toList();

    final artists = appState.artists.where((artist) {
      return artist.name.toLowerCase().contains(query);
    }).toList();

    final playlists = appState.playlists.where((playlist) {
      return playlist.name.toLowerCase().contains(query);
    }).toList();

    return {
      'tracks': tracks,
      'albums': albums,
      'artists': artists,
      'playlists': playlists,
    };
  }

  int _getTotalResults(Map<String, List<dynamic>> results) {
    return results.values.fold(0, (sum, list) => sum + list.length);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final searchResults = _getSearchResults(appState);
        final totalResults = _getTotalResults(searchResults);
        
        return Container(
          color: isDark ? AppleColors.backgroundPrimaryDark : AppleColors.backgroundPrimary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Search Header
              _buildSearchHeader(l10n, isDark, appState),
              
              // Filter Pills
              _buildFilterPills(searchResults, l10n, isDark),
              
              // Content Area
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppleDesignSystem.durationNormal,
                  switchInCurve: AppleDesignSystem.springCurve,
                  switchOutCurve: AppleDesignSystem.springCurve,
                  child: _searchQuery.isEmpty
                      ? _buildInitialState(appState, l10n, isDark)
                      : totalResults == 0
                          ? _buildNoResults(l10n, isDark)
                          : _buildSearchResults(appState, searchResults, l10n, isDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================
  // SECTION 1: Search Header with Glassmorphic Search Bar
  // ============================================
  
  Widget _buildSearchHeader(AppLocalizations l10n, bool isDark, AppState appState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppleDesignSystem.spacing32,
        AppleDesignSystem.spacing24,
        AppleDesignSystem.spacing32,
        AppleDesignSystem.spacing16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.navSearch,
                      style: AppleTextStyles.largeTitle(
                        color: isDark ? AppleColors.labelPrimaryDark : AppleColors.labelPrimary,
                      ),
                    ),
                    const SizedBox(height: AppleDesignSystem.spacing4),
                    Text(
                      '${appState.tracks.length} songs • ${appState.albums.length} albums • ${appState.artists.length} artists',
                      style: AppleTextStyles.subheadline(
                        color: isDark ? AppleColors.labelSecondaryDark : AppleColors.labelSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Keyboard shortcut hint
              _buildKeyboardHint('⌘K', isDark),
            ],
          ),
          
          const SizedBox(height: AppleDesignSystem.spacing20),
          
          // Glassmorphic Search Bar
          _buildGlassSearchBar(l10n, isDark),
        ],
      ),
    );
  }
  
  Widget _buildKeyboardHint(String shortcut, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppleDesignSystem.spacing12,
        vertical: AppleDesignSystem.spacing8,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppleColors.fillTertiaryDark : AppleColors.fillTertiary,
        borderRadius: BorderRadius.circular(AppleDesignSystem.radiusSmall),
        border: Border.all(
          color: isDark ? AppleColors.separatorDark : AppleColors.separator,
          width: 0.5,
        ),
      ),
      child: Text(
        shortcut,
        style: AppleTextStyles.caption1(
          color: isDark ? AppleColors.labelSecondaryDark : AppleColors.labelSecondary,
        ).copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildGlassSearchBar(AppLocalizations l10n, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppleDesignSystem.radiusLarge),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppleDesignSystem.blurThin,
          sigmaY: AppleDesignSystem.blurThin,
        ),
        child: AnimatedContainer(
          duration: AppleDesignSystem.durationFast,
          decoration: BoxDecoration(
            color: isDark 
                ? AppleColors.fillSecondaryDark 
                : AppleColors.fillSecondary,
            borderRadius: BorderRadius.circular(AppleDesignSystem.radiusLarge),
            border: Border.all(
              color: _searchFocusNode.hasFocus
                  ? (isDark ? AppleColors.systemBlueDark : AppleColors.systemBlue)
                  : (isDark ? AppleColors.separatorDark : AppleColors.separator),
              width: _searchFocusNode.hasFocus ? 2 : 0.5,
            ),
            boxShadow: _searchFocusNode.hasFocus
                ? [
                    BoxShadow(
                      color: (isDark ? AppleColors.systemBlueDark : AppleColors.systemBlue)
                          .withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            style: AppleTextStyles.body(
              color: isDark ? AppleColors.labelPrimaryDark : AppleColors.labelPrimary,
            ),
            decoration: InputDecoration(
              hintText: l10n.searchPlaceholder,
              hintStyle: AppleTextStyles.body(
                color: isDark ? AppleColors.labelTertiaryDark : AppleColors.labelTertiary,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: AppleDesignSystem.spacing16, right: AppleDesignSystem.spacing12),
                child: Icon(
                  Icons.search_rounded,
                  size: 24,
                  color: isDark ? AppleColors.labelSecondaryDark : AppleColors.labelSecondary,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 48),
              suffixIcon: _searchQuery.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(right: AppleDesignSystem.spacing8),
                      child: IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: isDark ? AppleColors.labelSecondaryDark : AppleColors.labelSecondary,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _selectedFilter = 'all';
                          });
                        },
                        splashRadius: 20,
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppleDesignSystem.spacing16,
                vertical: AppleDesignSystem.spacing16,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
      ),
    );
  }

  // ============================================
  // SECTION 2: Filter Pills with Animated Selection
  // ============================================

  Widget _buildFilterPills(Map<String, List<dynamic>> results, AppLocalizations l10n, bool isDark) {
    final filters = [
      _FilterData('all', l10n.all, _getTotalResults(results), Icons.apps_rounded),
      _FilterData('tracks', l10n.songs, results['tracks']!.length, Icons.music_note_rounded),
      _FilterData('albums', l10n.albums, results['albums']!.length, Icons.album_rounded),
      _FilterData('artists', l10n.artists, results['artists']!.length, Icons.person_rounded),
      _FilterData('playlists', l10n.playlists, results['playlists']!.length, Icons.queue_music_rounded),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppleDesignSystem.spacing32,
        vertical: AppleDesignSystem.spacing8,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter.key;
            return Padding(
              padding: const EdgeInsets.only(right: AppleDesignSystem.spacing12),
              child: _buildFilterPill(filter, isSelected, isDark),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterPill(_FilterData filter, bool isSelected, bool isDark) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredCategory = filter.key),
      onExit: (_) => setState(() => _hoveredCategory = null),
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = filter.key),
        child: AnimatedContainer(
          duration: AppleDesignSystem.durationFast,
          curve: AppleDesignSystem.springCurve,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleDesignSystem.spacing16,
            vertical: AppleDesignSystem.spacing12,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppleColors.systemBlueDark : AppleColors.systemBlue)
                : _hoveredCategory == filter.key
                    ? (isDark ? AppleColors.fillSecondaryDark : AppleColors.fillSecondary)
                    : (isDark ? AppleColors.fillTertiaryDark : AppleColors.fillTertiary),
            borderRadius: BorderRadius.circular(AppleDesignSystem.radiusRound),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : (isDark ? AppleColors.separatorDark : AppleColors.separator),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                filter.icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppleColors.labelSecondaryDark : AppleColors.labelSecondary),
              ),
              const SizedBox(width: AppleDesignSystem.spacing8),
              Text(
                filter.label,
                style: AppleTextStyles.subheadline(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppleColors.labelPrimaryDark : AppleColors.labelPrimary),
                ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500),
              ),
              const SizedBox(width: AppleDesignSystem.spacing8),
              AnimatedContainer(
                duration: AppleDesignSystem.durationFast,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppleDesignSystem.spacing8,
                  vertical: AppleDesignSystem.spacing2,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : (isDark ? AppleColors.fillSecondaryDark : AppleColors.fillSecondary),
                  borderRadius: BorderRadius.circular(AppleDesignSystem.radiusSmall),
                ),
                child: Text(
                  '${filter.count}',
                  style: AppleTextStyles.caption1(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? AppleColors.labelSecondaryDark : AppleColors.labelSecondary),
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // SECTION 3: Initial State with Browse Cards
  // ============================================

  Widget _buildInitialState(AppState appState, AppLocalizations l10n, bool isDark) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppleDesignSystem.spacing32,
        vertical: AppleDesignSystem.spacing16,
      ),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Browse Your Library Section
          _buildSectionTitle(l10n.browseYourLibrary, isDark),
          const SizedBox(height: AppleDesignSystem.spacing16),
          _buildBrowseGrid(appState, l10n, isDark),
          
          const SizedBox(height: AppleDesignSystem.spacing32),
          
          // Quick Access Section
          _buildSectionTitle(l10n.quickSuggestions, isDark),
          const SizedBox(height: AppleDesignSystem.spacing16),
          _buildQuickAccessChips(isDark),
          
          const SizedBox(height: AppleDesignSystem.spacing32),
          
          // Recent Artists Preview
          if (appState.artists.isNotEmpty) ...[
            _buildSectionTitle(l10n.artists, isDark, showViewAll: true, onViewAll: () {
              setState(() {
                _selectedFilter = 'artists';
                _searchQuery = '*';
              });
            }),
            const SizedBox(height: AppleDesignSystem.spacing16),
            _buildArtistsPreview(appState, isDark),
          ],
          
          const SizedBox(height: AppleDesignSystem.spacing48),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark, {bool showViewAll = false, VoidCallback? onViewAll}) {
    return Row(
      children: [
        Text(
          title,
          style: AppleTextStyles.title2(
            color: isDark ? AppleColors.labelPrimaryDark : AppleColors.labelPrimary,
          ),
        ),
        const Spacer(),
        if (showViewAll)
          TextButton(
            onPressed: onViewAll,
            child: Text(
              'View All',
              style: AppleTextStyles.subheadline(
                color: isDark ? AppleColors.systemBlueDark : AppleColors.systemBlue,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBrowseGrid(AppState appState, AppLocalizations l10n, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              child: _buildBrowseCard(
                title: l10n.albums,
                count: appState.albums.length,
                icon: Icons.album_rounded,
                gradient: [AppleColors.systemPurple, AppleColors.systemPink],
                isDark: isDark,
                onTap: () => _handleBrowseCardTap('Albums'),
              ),
            ),
            const SizedBox(width: AppleDesignSystem.spacing16),
            Expanded(
              child: _buildBrowseCard(
                title: l10n.artists,
                count: appState.artists.length,
                icon: Icons.people_rounded,
                gradient: [AppleColors.systemOrange, AppleColors.systemRed],
                isDark: isDark,
                onTap: () => _handleBrowseCardTap('Artists'),
              ),
            ),
            const SizedBox(width: AppleDesignSystem.spacing16),
            Expanded(
              child: _buildBrowseCard(
                title: l10n.playlists,
                count: appState.playlists.length,
                icon: Icons.queue_music_rounded,
                gradient: [AppleColors.systemTeal, AppleColors.systemBlue],
                isDark: isDark,
                onTap: () => _handleBrowseCardTap('Playlists'),
              ),
            ),
            const SizedBox(width: AppleDesignSystem.spacing16),
            Expanded(
              child: _buildBrowseCard(
                title: l10n.songs,
                count: appState.tracks.length,
                icon: Icons.music_note_rounded,
                gradient: [AppleColors.systemGreen, AppleColors.systemTeal],
                isDark: isDark,
                onTap: () {
                  setState(() {
                    _selectedFilter = 'tracks';
                    _searchQuery = '*';
                  });
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBrowseCard({
    required String title,
    required int count,
    required IconData icon,
    required List<Color> gradient,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppleDesignSystem.durationFast,
          height: 140,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppleDesignSystem.radiusLarge),
            boxShadow: AppleDesignSystem.shadowMedium(gradient[0]),
          ),
          child: Stack(
            children: [
              // Background icon
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(
                  icon,
                  size: 100,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(AppleDesignSystem.spacing20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppleDesignSystem.spacing12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const Spacer(),
                    Text(
                      title,
                      style: AppleTextStyles.headline(color: Colors.white),
                    ),
                    const SizedBox(height: AppleDesignSystem.spacing4),
                    Text(
                      '$count items',
                      style: AppleTextStyles.caption1(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessChips(bool isDark) {
    final suggestions = ['Rock', 'Pop', 'Jazz', 'Classical', 'Electronic', 'Hip Hop', 'R&B', 'Indie'];
    
    return Wrap(
      spacing: AppleDesignSystem.spacing12,
      runSpacing: AppleDesignSystem.spacing12,
      children: suggestions.map((suggestion) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              _searchController.text = suggestion;
              setState(() => _searchQuery = suggestion);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppleDesignSystem.spacing16,
                vertical: AppleDesignSystem.spacing12,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppleColors.elevatedSecondaryDark : AppleColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(AppleDesignSystem.radiusRound),
                border: Border.all(
                  color: isDark ? AppleColors.separatorDark : AppleColors.separator,
                  width: 0.5,
                ),
              ),
              child: Text(
                suggestion,
                style: AppleTextStyles.subheadline(
                  color: isDark ? AppleColors.labelPrimaryDark : AppleColors.labelPrimary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildArtistsPreview(AppState appState, bool isDark) {
    final artists = appState.artists.take(6).toList();
    
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: artists.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppleDesignSystem.spacing16),
        itemBuilder: (context, index) {
          final artist = artists[index];
          return _buildArtistPreviewCard(appState, artist, isDark);
        },
      ),
    );
  }

  Widget _buildArtistPreviewCard(AppState appState, dynamic artist, bool isDark) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ArtistDetailsPage(artist: artist)),
          );
        },
        child: SizedBox(
          width: 120,
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppleColors.fillSecondaryDark : AppleColors.fillSecondary,
                  boxShadow: AppleDesignSystem.shadowSmall(Colors.black),
                ),
                child: artist.imageUrl != null
                    ? ClipOval(
                        child: Image.network(
                          _getImageUrl(appState, artist.imageUrl)!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.person_rounded,
                            size: 40,
                            color: isDark ? AppleColors.labelTertiaryDark : AppleColors.labelTertiary,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.person_rounded,
                        size: 40,
                        color: isDark ? AppleColors.labelTertiaryDark : AppleColors.labelTertiary,
                      ),
              ),
              const SizedBox(height: AppleDesignSystem.spacing12),
              Text(
                artist.name,
                style: AppleTextStyles.subheadline(
                  color: isDark ? AppleColors.labelPrimaryDark : AppleColors.labelPrimary,
                ),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // SECTION 4: No Results State
  // ============================================

  Widget _buildNoResults(AppLocalizations l10n, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: isDark ? AppleColors.fillTertiaryDark : AppleColors.fillTertiary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 56,
              color: isDark ? AppleColors.labelTertiaryDark : AppleColors.labelTertiary,
            ),
          ),
          const SizedBox(height: AppleDesignSystem.spacing24),
          Text(
            l10n.noResultsFor(_searchQuery),
            style: AppleTextStyles.title2(
              color: isDark ? AppleColors.labelPrimaryDark : AppleColors.labelPrimary,
            ),
          ),
          const SizedBox(height: AppleDesignSystem.spacing8),
          Text(
            l10n.tryDifferentSearch,
            style: AppleTextStyles.body(
              color: isDark ? AppleColors.labelSecondaryDark : AppleColors.labelSecondary,
            ),
          ),
          const SizedBox(height: AppleDesignSystem.spacing24),
          TextButton.icon(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _selectedFilter = 'all';
              });
              _searchFocusNode.requestFocus();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.clearSearch),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? AppleColors.systemBlueDark : AppleColors.systemBlue,
            ),
          ),
        ],
      ),
    );
  }

  // Old method - keeping for reference, will be replaced
  Widget _buildFilterChips(Map<String, List<dynamic>> results, AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          FilterChip(
            label: Text('${l10n.all} (${_getTotalResults(results)})'),
            selected: _selectedFilter == 'all',
            onSelected: (selected) {
              setState(() {
                _selectedFilter = 'all';
              });
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text('${l10n.songs} (${results['tracks']!.length})'),
            selected: _selectedFilter == 'tracks',
            onSelected: (selected) {
              setState(() {
                _selectedFilter = 'tracks';
              });
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text('${l10n.albums} (${results['albums']!.length})'),
            selected: _selectedFilter == 'albums',
            onSelected: (selected) {
              setState(() {
                _selectedFilter = 'albums';
              });
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text('${l10n.artists} (${results['artists']!.length})'),
            selected: _selectedFilter == 'artists',
            onSelected: (selected) {
              setState(() {
                _selectedFilter = 'artists';
              });
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text('${l10n.playlists} (${results['playlists']!.length})'),
            selected: _selectedFilter == 'playlists',
            onSelected: (selected) {
              setState(() {
                _selectedFilter = 'playlists';
              });
            },
          ),
        ],
      ),
    );
  }

  // Old initial state method - to be removed
  Widget _buildOldInitialState(AppState appState, AppLocalizations l10n) {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick suggestions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.quickSuggestions,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSuggestionChip('Rock'),
                      _buildSuggestionChip('Pop'),
                      _buildSuggestionChip('Jazz'),
                      _buildSuggestionChip('Classical'),
                      _buildSuggestionChip('Electronic'),
                      _buildSuggestionChip('Alternative'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Recent searches (placeholder)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.recentSearches,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.yourRecentSearches,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Browse categories
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.browseYourLibrary,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildBrowseCard(
                          l10n.albums,
                          l10n.countAlbums(appState.albums.length),
                          Icons.album,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildBrowseCard(
                          l10n.artists,
                          l10n.countArtists(appState.artists.length),
                          Icons.person,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildBrowseCard(
                          l10n.playlists,
                          l10n.countPlaylists(appState.playlists.length),
                          Icons.playlist_play,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String suggestion) {
    return ActionChip(
      label: Text(suggestion),
      onPressed: () {
        _searchController.text = suggestion;
        setState(() {
          _searchQuery = suggestion;
        });
      },
    );
  }

  Widget _buildBrowseCard(String title, String subtitle, IconData icon, Color color) {
    final theme = Theme.of(context);
    
    return Card(
      child: InkWell(
        onTap: () {
          _handleBrowseCardTap(title);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoResults(AppLocalizations l10n) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noResultsFor(_searchQuery),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tryDifferentSearch,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
              _searchFocusNode.requestFocus();
            },
            child: Text(l10n.clearSearch),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(AppState appState, Map<String, List<dynamic>> results, AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top result
          if (_selectedFilter == 'all' && _getTotalResults(results) > 0)
            _buildTopResult(appState, results, l10n),
          
          // Filtered results
          if (_selectedFilter == 'all' || _selectedFilter == 'tracks')
            _buildSectionResults(appState, l10n.songs, results['tracks']!, 'track'),
          
          if (_selectedFilter == 'all' || _selectedFilter == 'albums')
            _buildSectionResults(appState, l10n.albums, results['albums']!, 'album'),
          
          if (_selectedFilter == 'all' || _selectedFilter == 'artists')
            _buildSectionResults(appState, l10n.artists, results['artists']!, 'artist'),
          
          if (_selectedFilter == 'all' || _selectedFilter == 'playlists')
            _buildSectionResults(appState, l10n.playlists, results['playlists']!, 'playlist'),
        ],
      ),
    );
  }

  Widget _buildTopResult(AppState appState, Map<String, List<dynamic>> results, AppLocalizations l10n) {
    // Find the first non-empty result as the top result
    dynamic topResult;
    String topResultType = '';
    
    for (final entry in results.entries) {
      if (entry.value.isNotEmpty) {
        topResult = entry.value.first;
        topResultType = entry.key.substring(0, entry.key.length - 1); // Remove 's' from plural
        break;
      }
    }
    
    if (topResult == null) return const SizedBox.shrink();
    
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.topResult,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildResultItem(appState, topResult, topResultType, isTopResult: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionResults(AppState appState, String title, List<dynamic> items, String type) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    final theme = Theme.of(context);
    final displayItems = _selectedFilter == 'all' ? items.take(5).toList() : items;
    
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_selectedFilter == 'all' && items.length > 5)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedFilter = '${type}s'; // Convert to plural
                      });
                    },
                    child: Text('View All (${items.length})'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...displayItems.map((item) => _buildResultItem(appState, item, type)),
          ],
        ),
      ),
    );
  }

  Widget _buildResultItem(AppState appState, dynamic item, String type, {bool isTopResult = false}) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: _buildResultLeading(appState, item, type),
      title: Text(
        _getItemTitle(item, type),
        style: isTopResult 
            ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
            : theme.textTheme.bodyLarge,
      ),
      subtitle: Text(_getItemSubtitle(item, type)),
      trailing: _buildResultTrailing(appState, item, type),
      onTap: () {
        _handleItemTap(appState, item, type);
      },
      contentPadding: isTopResult 
          ? const EdgeInsets.all(8)
          : const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
    );
  }

  Widget _buildResultLeading(AppState appState, dynamic item, String type) {
    final theme = Theme.of(context);
    final size = 48.0;
    
    switch (type) {
      case 'track':
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: item.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _getImageUrl(appState, item.imageUrl)!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.music_note, color: theme.colorScheme.onSurfaceVariant);
                    },
                  ),
                )
              : Icon(Icons.music_note, color: theme.colorScheme.onSurfaceVariant),
        );
      case 'album':
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: item.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _getImageUrl(appState, item.imageUrl)!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.album, color: theme.colorScheme.onSurfaceVariant);
                    },
                  ),
                )
              : Icon(Icons.album, color: theme.colorScheme.onSurfaceVariant),
        );
      case 'artist':
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            shape: BoxShape.circle,
          ),
          child: item.imageUrl != null
              ? ClipOval(
                  child: Image.network(
                    _getImageUrl(appState, item.imageUrl)!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.person, color: theme.colorScheme.onSurfaceVariant);
                    },
                  ),
                )
              : Icon(Icons.person, color: theme.colorScheme.onSurfaceVariant),
        );
      case 'playlist':
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: item.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _getImageUrl(appState, item.imageUrl)!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.playlist_play, color: theme.colorScheme.onSurfaceVariant);
                    },
                  ),
                )
              : Icon(Icons.playlist_play, color: theme.colorScheme.onSurfaceVariant),
        );
      default:
        return Icon(Icons.music_note, color: theme.colorScheme.onSurfaceVariant);
    }
  }

  Widget _buildResultTrailing(AppState appState, dynamic item, String type) {
    switch (type) {
      case 'track':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.duration != null)
              Text(
                _formatDuration(item.duration!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            IconButton(
              onPressed: () {
                _handlePlayTrack(appState, item);
              },
              icon: const Icon(Icons.play_arrow),
              iconSize: 20,
            ),
          ],
        );
      default:
        return IconButton(
          onPressed: () {
            _handleItemTap(appState, item, type);
          },
          icon: const Icon(Icons.play_arrow),
          iconSize: 20,
        );
    }
  }

  void _handleItemTap(AppState appState, dynamic item, String type) {
    switch (type) {
      case 'track':
        _handlePlayTrack(appState, item);
        break;
      case 'album':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MediaDetailsPage.album(album: item),
          ),
        );
        break;
      case 'artist':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtistDetailsPage(artist: item),
          ),
        );
        break;
      case 'playlist':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MediaDetailsPage.playlist(playlist: item),
          ),
        );
        break;
    }
  }

  void _handlePlayTrack(AppState appState, dynamic track) {
    // Play the selected track
    appState.playTrack(track);
  }

  void _handleBrowseCardTap(String title) {
    // Set filter and show browse mode
    setState(() {
      switch (title) {
        case 'Albums':
          _selectedFilter = 'albums';
          break;
        case 'Artists':
          _selectedFilter = 'artists';
          break;
        case 'Playlists':
          _selectedFilter = 'playlists';
          break;
      }
      _searchQuery = '*'; // Use asterisk to indicate browse all mode
      _searchController.text = '';
    });
  }

  String _getItemTitle(dynamic item, String type) {
    return item.name;
  }

  String _getItemSubtitle(dynamic item, String type) {
    switch (type) {
      case 'track':
        final parts = <String>[];
        if (item.artistName != null) parts.add(item.artistName!);
        if (item.albumName != null) parts.add(item.albumName!);
        return parts.join(' • ');
      case 'album':
        return item.artistName ?? 'Unknown Artist';
      case 'artist':
        return 'Artist';
      case 'playlist':
        return '${item.trackCount} songs';
      default:
        return '';
    }
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
