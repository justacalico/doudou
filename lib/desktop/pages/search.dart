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
        separatorBuilder: (_, _) => const SizedBox(width: AppleDesignSystem.spacing16),
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
                          errorBuilder: (_, _, _) => Icon(
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

  // ============================================
  // SECTION 5: Search Results with Modern Grid Layout
  // ============================================

  Widget _buildSearchResults(AppState appState, Map<String, List<dynamic>> results, AppLocalizations l10n, bool isDark) {
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
          // Top Result (only in 'all' filter)
          if (_selectedFilter == 'all' && _getTotalResults(results) > 0)
            _buildTopResultCard(appState, results, l10n, isDark),
          
          // Artists Section
          if ((_selectedFilter == 'all' || _selectedFilter == 'artists') && results['artists']!.isNotEmpty)
            _buildResultsSection(
              appState: appState,
              title: l10n.artists,
              items: results['artists']!,
              type: 'artist',
              isDark: isDark,
              l10n: l10n,
            ),
          
          // Albums Section
          if ((_selectedFilter == 'all' || _selectedFilter == 'albums') && results['albums']!.isNotEmpty)
            _buildResultsSection(
              appState: appState,
              title: l10n.albums,
              items: results['albums']!,
              type: 'album',
              isDark: isDark,
              l10n: l10n,
            ),
          
          // Songs Section
          if ((_selectedFilter == 'all' || _selectedFilter == 'tracks') && results['tracks']!.isNotEmpty)
            _buildTracksSection(appState, results['tracks']!, l10n, isDark),
          
          // Playlists Section
          if ((_selectedFilter == 'all' || _selectedFilter == 'playlists') && results['playlists']!.isNotEmpty)
            _buildResultsSection(
              appState: appState,
              title: l10n.playlists,
              items: results['playlists']!,
              type: 'playlist',
              isDark: isDark,
              l10n: l10n,
            ),
          
          const SizedBox(height: AppleDesignSystem.spacing48),
        ],
      ),
    );
  }

  Widget _buildTopResultCard(AppState appState, Map<String, List<dynamic>> results, AppLocalizations l10n, bool isDark) {
    // Find best match
    dynamic topResult;
    String topResultType = '';
    
    for (final entry in results.entries) {
      if (entry.value.isNotEmpty) {
        topResult = entry.value.first;
        topResultType = entry.key.substring(0, entry.key.length - 1);
        break;
      }
    }
    
    if (topResult == null) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.topResult, isDark),
        const SizedBox(height: AppleDesignSystem.spacing16),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hoveredResultIndex = -1),
          onExit: (_) => setState(() => _hoveredResultIndex = null),
          child: GestureDetector(
            onTap: () => _handleItemTap(appState, topResult, topResultType),
            child: AnimatedContainer(
              duration: AppleDesignSystem.durationFast,
              transform: Matrix4.identity()..scale(_hoveredResultIndex == -1 ? 1.01 : 1.0),
              padding: const EdgeInsets.all(AppleDesignSystem.spacing20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [AppleColors.elevatedSecondaryDark, AppleColors.elevatedTertiaryDark]
                      : [AppleColors.backgroundSecondary, AppleColors.backgroundTertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppleDesignSystem.radiusLarge),
                border: Border.all(
                  color: isDark ? AppleColors.separatorDark : AppleColors.separator,
                  width: 0.5,
                ),
                boxShadow: _hoveredResultIndex == -1
                    ? AppleDesignSystem.shadowMedium(Colors.black)
                    : AppleDesignSystem.shadowSmall(Colors.black),
              ),
              child: Row(
                children: [
                  // Large artwork
                  _buildResultArtwork(appState, topResult, topResultType, isDark, size: 140),
                  const SizedBox(width: AppleDesignSystem.spacing24),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppleDesignSystem.spacing8,
                            vertical: AppleDesignSystem.spacing4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? AppleColors.systemBlueDark.withOpacity(0.2) : AppleColors.systemBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppleDesignSystem.spacing4),
                          ),
                          child: Text(
                            _getTypeLabel(topResultType, l10n),
                            style: AppleTextStyles.caption1(
                              color: isDark ? AppleColors.systemBlueDark : AppleColors.systemBlue,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: AppleDesignSystem.spacing12),
                        Text(
                          topResult.name,
                          style: AppleTextStyles.title1(
                            color: isDark ? AppleColors.labelPrimaryDark : AppleColors.labelPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppleDesignSystem.spacing8),
                        Text(
                          _getItemSubtitle(topResult, topResultType),
                          style: AppleTextStyles.body(
                            color: isDark ? AppleColors.labelSecondaryDark : AppleColors.labelSecondary,
                          ),
                        ),
                        const SizedBox(height: AppleDesignSystem.spacing16),
                        // Play button
                        _buildPlayButton(appState, topResult, topResultType, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppleDesignSystem.spacing32),
      ],
    );
  }

  Widget _buildResultsSection({
    required AppState appState,
    required String title,
    required List<dynamic> items,
    required String type,
    required bool isDark,
    required AppLocalizations l10n,
  }) {
    final displayItems = _selectedFilter == 'all' ? items.take(6).toList() : items;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title,
          isDark,
          showViewAll: _selectedFilter == 'all' && items.length > 6,
          onViewAll: () => setState(() => _selectedFilter = '${type}s'),
        ),
        const SizedBox(height: AppleDesignSystem.spacing16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 1200 ? 6 : constraints.maxWidth > 900 ? 5 : constraints.maxWidth > 600 ? 4 : 3;
            
            return Wrap(
              spacing: AppleDesignSystem.spacing16,
              runSpacing: AppleDesignSystem.spacing20,
              children: displayItems.asMap().entries.map((entry) {
                return SizedBox(
                  width: (constraints.maxWidth - (crossAxisCount - 1) * AppleDesignSystem.spacing16) / crossAxisCount,
                  child: _buildResultCard(appState, entry.value, type, isDark, entry.key),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: AppleDesignSystem.spacing32),
      ],
    );
  }

  Widget _buildResultCard(AppState appState, dynamic item, String type, bool isDark, int index) {
    final isHovered = _hoveredResultIndex == index;
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredResultIndex = index),
      onExit: (_) => setState(() => _hoveredResultIndex = null),
      child: GestureDetector(
        onTap: () => _handleItemTap(appState, item, type),
        child: AnimatedContainer(
          duration: AppleDesignSystem.durationFast,
          curve: AppleDesignSystem.springCurve,
          transform: Matrix4.identity()..scale(isHovered ? 1.03 : 1.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Artwork with play overlay
              Stack(
                children: [
                  _buildResultArtwork(appState, item, type, isDark),
                  // Play overlay on hover
                  if (isHovered)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(
                            type == 'artist' ? AppleDesignSystem.radiusRound : AppleDesignSystem.radiusMedium,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isDark ? AppleColors.systemBlueDark : AppleColors.systemBlue,
                              shape: BoxShape.circle,
                              boxShadow: AppleDesignSystem.shadowMedium(AppleColors.systemBlue),
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppleDesignSystem.spacing12),
              // Title
              Text(
                item.name,
                style: AppleTextStyles.subheadline(
                  color: isDark ? AppleColors.labelPrimaryDark : AppleColors.labelPrimary,
                ).copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppleDesignSystem.spacing4),
              // Subtitle
              Text(
                _getItemSubtitle(item, type),
                style: AppleTextStyles.caption1(
                  color: isDark ? AppleColors.labelSecondaryDark : AppleColors.labelSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultArtwork(AppState appState, dynamic item, String type, bool isDark, {double size = 0}) {
    final actualSize = size > 0 ? size : double.infinity;
    final isCircle = type == 'artist';
    
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        width: actualSize,
        height: actualSize,
        decoration: BoxDecoration(
          color: isDark ? AppleColors.fillSecondaryDark : AppleColors.fillSecondary,
          borderRadius: isCircle ? null : BorderRadius.circular(AppleDesignSystem.radiusMedium),
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          boxShadow: AppleDesignSystem.shadowSmall(Colors.black),
        ),
        child: ClipRRect(
          borderRadius: isCircle 
              ? BorderRadius.circular(1000) 
              : BorderRadius.circular(AppleDesignSystem.radiusMedium),
          child: item.imageUrl != null
              ? Image.network(
                  _getImageUrl(appState, item.imageUrl)!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _buildPlaceholderIcon(type, isDark),
                )
              : _buildPlaceholderIcon(type, isDark),
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon(String type, bool isDark) {
    IconData icon;
    switch (type) {
      case 'track':
        icon = Icons.music_note_rounded;
        break;
      case 'album':
        icon = Icons.album_rounded;
        break;
      case 'artist':
        icon = Icons.person_rounded;
        break;
      case 'playlist':
        icon = Icons.queue_music_rounded;
        break;
      default:
        icon = Icons.music_note_rounded;
    }
    
    return Center(
      child: Icon(
        icon,
        size: 40,
        color: isDark ? AppleColors.labelTertiaryDark : AppleColors.labelTertiary,
      ),
    );
  }

  Widget _buildTracksSection(AppState appState, List<dynamic> tracks, AppLocalizations l10n, bool isDark) {
    final displayTracks = _selectedFilter == 'all' ? tracks.take(8).toList() : tracks;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          l10n.songs,
          isDark,
          showViewAll: _selectedFilter == 'all' && tracks.length > 8,
          onViewAll: () => setState(() => _selectedFilter = 'tracks'),
        ),
        const SizedBox(height: AppleDesignSystem.spacing16),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppleColors.elevatedSecondaryDark : AppleColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(AppleDesignSystem.radiusMedium),
            border: Border.all(
              color: isDark ? AppleColors.separatorDark : AppleColors.separator,
              width: 0.5,
            ),
          ),
          child: Column(
            children: displayTracks.asMap().entries.map((entry) {
              final track = entry.value;
              final index = entry.key;
              final isLast = index == displayTracks.length - 1;
              
              return _buildTrackRow(appState, track, index, isDark, isLast);
            }).toList(),
          ),
        ),
        const SizedBox(height: AppleDesignSystem.spacing32),
      ],
    );
  }

  Widget _buildTrackRow(AppState appState, dynamic track, int index, bool isDark, bool isLast) {
    final isHovered = _hoveredResultIndex == index + 1000; // Offset to not conflict with other results
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredResultIndex = index + 1000),
      onExit: (_) => setState(() => _hoveredResultIndex = null),
      child: GestureDetector(
        onTap: () => _handlePlayTrack(appState, track),
        child: AnimatedContainer(
          duration: AppleDesignSystem.durationFast,
          decoration: BoxDecoration(
            color: isHovered
                ? (isDark ? AppleColors.fillTertiaryDark : AppleColors.fillTertiary)
                : Colors.transparent,
            border: isLast
                ? null
                : Border(
                    bottom: BorderSide(
                      color: isDark ? AppleColors.separatorDark : AppleColors.separator,
                      width: 0.5,
                    ),
                  ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppleDesignSystem.spacing16,
            vertical: AppleDesignSystem.spacing12,
          ),
          child: Row(
            children: [
              // Play/Number indicator
              SizedBox(
                width: 32,
                child: isHovered
                    ? Icon(
                        Icons.play_arrow_rounded,
                        color: isDark ? AppleColors.systemBlueDark : AppleColors.systemBlue,
                        size: 20,
                      )
                    : Text(
                        '${index + 1}',
                        style: AppleTextStyles.body(
                          color: isDark ? AppleColors.labelTertiaryDark : AppleColors.labelTertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),
              const SizedBox(width: AppleDesignSystem.spacing12),
              // Artwork
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppleDesignSystem.radiusSmall),
                  color: isDark ? AppleColors.fillSecondaryDark : AppleColors.fillSecondary,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppleDesignSystem.radiusSmall),
                  child: track.imageUrl != null
                      ? Image.network(
                          _getImageUrl(appState, track.imageUrl)!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.music_note_rounded,
                            color: isDark ? AppleColors.labelTertiaryDark : AppleColors.labelTertiary,
                          ),
                        )
                      : Icon(
                          Icons.music_note_rounded,
                          color: isDark ? AppleColors.labelTertiaryDark : AppleColors.labelTertiary,
                        ),
                ),
              ),
              const SizedBox(width: AppleDesignSystem.spacing12),
              // Track info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.name,
                      style: AppleTextStyles.body(
                        color: isDark ? AppleColors.labelPrimaryDark : AppleColors.labelPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      track.artistName ?? 'Unknown Artist',
                      style: AppleTextStyles.caption1(
                        color: isDark ? AppleColors.labelSecondaryDark : AppleColors.labelSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Album name
              Expanded(
                child: Text(
                  track.albumName ?? '',
                  style: AppleTextStyles.caption1(
                    color: isDark ? AppleColors.labelSecondaryDark : AppleColors.labelSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Duration
              if (track.duration != null)
                Text(
                  _formatDuration(track.duration!),
                  style: AppleTextStyles.caption1(
                    color: isDark ? AppleColors.labelTertiaryDark : AppleColors.labelTertiary,
                  ),
                ),
              const SizedBox(width: AppleDesignSystem.spacing8),
              // More button
              if (isHovered)
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: isDark ? AppleColors.labelSecondaryDark : AppleColors.labelSecondary,
                    size: 20,
                  ),
                  splashRadius: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton(AppState appState, dynamic item, String type, bool isDark) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (type == 'track') {
            _handlePlayTrack(appState, item);
          } else {
            _handleItemTap(appState, item, type);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppleDesignSystem.spacing20,
            vertical: AppleDesignSystem.spacing12,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppleColors.systemBlueDark : AppleColors.systemBlue,
            borderRadius: BorderRadius.circular(AppleDesignSystem.radiusRound),
            boxShadow: AppleDesignSystem.shadowSmall(AppleColors.systemBlue),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
              const SizedBox(width: AppleDesignSystem.spacing8),
              Text(
                'Play',
                style: AppleTextStyles.subheadline(color: Colors.white).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTypeLabel(String type, AppLocalizations l10n) {
    switch (type) {
      case 'track':
        return l10n.songs;
      case 'album':
        return l10n.albums;
      case 'artist':
        return l10n.artists;
      case 'playlist':
        return l10n.playlists;
      default:
        return type;
    }
  }

  // ============================================
  // Helper Methods
  // ============================================

  void _handleItemTap(AppState appState, dynamic item, String type) {
    switch (type) {
      case 'track':
        _handlePlayTrack(appState, item);
        break;
      case 'album':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MediaDetailsPage.album(album: item)),
        );
        break;
      case 'artist':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ArtistDetailsPage(artist: item)),
        );
        break;
      case 'playlist':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MediaDetailsPage.playlist(playlist: item)),
        );
        break;
    }
  }

  void _handlePlayTrack(AppState appState, dynamic track) {
    appState.playTrack(track);
  }

  void _handleBrowseCardTap(String title) {
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
      _searchQuery = '*';
      _searchController.text = '';
    });
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
        return '${item.trackCount ?? 0} songs';
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
