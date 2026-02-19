import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../services/base_service.dart';
import 'breakpoint.dart';
import 'navigation_service.dart';
import '../screens/collection_detail.dart';
import '../screens/albums.dart';
import '../screens/artists.dart';
import '../screens/downloads.dart';
import '../screens/home.dart';
import '../screens/library.dart';
import '../screens/now_playing.dart';
import '../screens/playlists.dart';
import '../screens/search.dart';
import '../screens/settings.dart';
import '../screens/tracks.dart';
import '../theme.dart';
import '../widgets/now_playing_bar.dart';

/// Single responsive shell: sidebar on desktop (>= 600px), bottom navbar on mobile.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final NavigationService _nav = NavigationService();
  late int _selectedIndex;
  late List<Widget> _pages;
  late int _settingsIndex;
  late List<_NavItem> _navItems;
  late List<_NavItem> _libraryItems;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _nav.selectedPageIndex.value;
    _nav.selectedPageIndex.addListener(_onNavChanged);
    _nav.detailPageStack.addListener(_onDetailChanged);
    _rebuildPageLists();
  }

  @override
  void dispose() {
    _nav.selectedPageIndex.removeListener(_onNavChanged);
    _nav.detailPageStack.removeListener(_onDetailChanged);
    super.dispose();
  }

  void _onNavChanged() {
    final idx = _nav.selectedPageIndex.value;
    if (idx != _selectedIndex && idx >= 0 && idx < _pages.length) {
      setState(() => _selectedIndex = idx);
    }
  }

  void _onDetailChanged() => setState(() {});

  bool get _showDownloads {
    final st = context.read<AppState>().mediaServiceManager.currentServerType;
    return st != ServerType.local && st != ServerType.soundcloud && st != ServerType.youtubeMusic;
  }

  bool get _showAlbums {
    final st = context.read<AppState>().mediaServiceManager.currentServerType;
    return st != ServerType.soundcloud;
  }

  void _rebuildPageLists() {
    _navItems = _buildNavItems();
    _libraryItems = _buildLibraryItems();
    _pages = _buildPages();
    _settingsIndex = _pages.length - 1;
    if (_selectedIndex >= _pages.length) {
      _selectedIndex = _pages.length - 1;
      _nav.selectedPageIndex.value = _selectedIndex;
    }
  }

  List<_NavItem> _buildNavItems() => [
        const _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
        const _NavItem(Icons.search_outlined, Icons.search_rounded, 'Search'),
        const _NavItem(Icons.library_music_outlined, Icons.library_music_rounded, 'Library'),
      ];

  List<_NavItem> _buildLibraryItems() {
    return [
      if (_showAlbums) const _NavItem(Icons.album_outlined, Icons.album_rounded, 'Albums'),
      const _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Artists'),
      const _NavItem(Icons.music_note_outlined, Icons.music_note_rounded, 'Tracks'),
      const _NavItem(Icons.queue_music_outlined, Icons.queue_music_rounded, 'Playlists'),
      if (_showDownloads) const _NavItem(Icons.download_outlined, Icons.download_rounded, 'Downloads'),
    ];
  }

  List<Widget> _buildPages() {
    final list = <Widget>[
      const HomeScreen(),
      const SearchScreen(),
      const LibraryScreen(),
      if (_showAlbums) const AlbumsScreen(),
      const ArtistsScreen(),
      const TracksScreen(),
      const PlaylistsScreen(),
    ];
    if (_showDownloads) list.add(const DownloadsScreen());
    list.add(const SettingsScreen());
    return list;
  }

  void _navigateTo(int index) {
    _nav.selectPage(index);
    if (index != _selectedIndex && index < _pages.length) {
      setState(() => _selectedIndex = index);
    }
  }

  void _openNowPlaying() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: const NowPlayingScreen(),
          );
        },
      ),
    );
  }

  Widget? _buildDetailOverlay() {
    final detail = _nav.currentDetailPage;
    if (detail == null) return null;
    return Container(
      color: AppTheme.background,
      child: SafeArea(
        child: CollectionDetailScreen(
          type: detail.type,
          data: detail.data,
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final showDownloads = _showDownloads;
    final showAlbums = _showAlbums;
    final prevCount = _libraryItems.length;
    final expectedCount = (showAlbums ? 1 : 0) + 3 + (showDownloads ? 1 : 0);
    if (prevCount != expectedCount) _rebuildPageLists();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        appState.setCloseNowPlayingOverlay(() {
          if (context.mounted) Navigator.of(context).maybePop();
        });
        return Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= kLayoutBreakpoint;
                return Scaffold(
                  backgroundColor: AppTheme.background,
                  body: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (isDesktop)
                              _Sidebar(
                                currentIndex: _selectedIndex,
                                navItems: _navItems,
                                libraryItems: _libraryItems,
                                showAlbums: _showAlbums,
                                settingsIndex: _settingsIndex,
                                onTap: _navigateTo,
                              ),
                            Expanded(
                              child: Stack(
                                children: [
                                  IndexedStack(
                                    index: _selectedIndex.clamp(0, _pages.length - 1),
                                    children: _pages,
                                  ),
                                  if (_buildDetailOverlay() != null)
                                    Positioned.fill(child: _buildDetailOverlay()!),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      NowPlayingBar(onTap: _openNowPlaying),
                    ],
                  ),
                  bottomNavigationBar: isDesktop
                      ? null
                      : _BottomNavBar(
                          currentIndex: _selectedIndex,
                          onTap: _navigateTo,
                          settingsIndex: _settingsIndex,
                          showDownloads: _showDownloads,
                          downloadsIndex: _showAlbums ? 7 : 6,
                        ),
                );
              },
            ),
            if (!appState.isLoggedIn && _selectedIndex != _settingsIndex)
              _AddServerOverlay(
                onOpenSettings: () => _navigateTo(_settingsIndex),
              ),
          ],
        );
      },
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

class _Sidebar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> navItems;
  final List<_NavItem> libraryItems;
  final bool showAlbums;
  final int settingsIndex;
  final ValueChanged<int> onTap;

  const _Sidebar({
    required this.currentIndex,
    required this.navItems,
    required this.libraryItems,
    required this.showAlbums,
    required this.settingsIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.textMuted, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingLg),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: AppTheme.spacingSm),
                        const Text(
                          'Doudou',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...navItems.asMap().entries.map((e) => _SidebarTile(
                        icon: e.value.icon,
                        activeIcon: e.value.activeIcon,
                        label: _navLabel(l10n, e.key),
                        selected: currentIndex == e.key,
                        onTap: () => onTap(e.key),
                      )),
                  const SizedBox(height: AppTheme.spacingMd),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
                    child: Container(height: 1, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingLg,
                      vertical: AppTheme.spacingSm,
                    ),
                    child: Text(
                      l10n.library.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textTertiary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ...libraryItems.asMap().entries.map((e) {
                    final idx = navItems.length + e.key;
                    return _SidebarTile(
                      icon: e.value.icon,
                      activeIcon: e.value.activeIcon,
                      label: _libraryLabel(l10n, e.key, showAlbums),
                      selected: currentIndex == idx,
                      onTap: () => onTap(idx),
                    );
                  }),
                ],
              ),
            ),
          ),
          _SidebarTile(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: l10n.settings,
            selected: currentIndex == settingsIndex,
            onTap: () => onTap(settingsIndex),
          ),
          const SizedBox(height: AppTheme.spacingMd),
        ],
      ),
    );
  }

  String _navLabel(AppLocalizations l10n, int index) {
    switch (index) {
      case 0:
        return l10n.navHome;
      case 1:
        return l10n.search;
      case 2:
        return l10n.library;
      default:
        return '';
    }
  }

  String _libraryLabel(AppLocalizations l10n, int index, bool showAlbums) {
    if (showAlbums) {
      switch (index) {
        case 0:
          return l10n.albums;
        case 1:
          return l10n.artists;
        case 2:
          return l10n.songs;
        case 3:
          return l10n.playlists;
        case 4:
          return l10n.downloads;
        default:
          return '';
      }
    }
    switch (index) {
      case 0:
        return l10n.artists;
      case 1:
        return l10n.songs;
      case 2:
        return l10n.playlists;
      case 3:
        return l10n.downloads;
      default:
        return '';
    }
  }
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingSm,
            vertical: 2,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMd,
              vertical: 10,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  size: 20,
                  color: selected ? accent : AppTheme.textSecondary,
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? accent : AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int settingsIndex;
  final bool showDownloads;
  final int downloadsIndex;

  const _BottomNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.settingsIndex,
    required this.showDownloads,
    required this.downloadsIndex,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final indices = showDownloads
        ? [0, 1, 2, downloadsIndex, settingsIndex]
        : [0, 1, 2, settingsIndex];
    final labels = showDownloads
        ? [l10n.navHome, l10n.search, l10n.library, l10n.downloads, l10n.settings]
        : [l10n.navHome, l10n.search, l10n.library, l10n.settings];
    final icons = [
      Icons.home_outlined,
      Icons.search_outlined,
      Icons.library_music_outlined,
      if (showDownloads) Icons.download_outlined,
      Icons.settings_outlined,
    ];
    final activeIcons = [
      Icons.home_rounded,
      Icons.search_rounded,
      Icons.library_music_rounded,
      if (showDownloads) Icons.download_rounded,
      Icons.settings_rounded,
    ];
    return Container(
      color: AppTheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(indices.length, (i) {
              final idx = indices[i];
              final selected = currentIndex == idx;
              return InkWell(
                onTap: () {
                  onTap(idx);
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected ? activeIcons[i] : icons[i],
                        size: 24,
                        color: selected ? theme.colorScheme.primary : AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected ? theme.colorScheme.primary : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _AddServerOverlay extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _AddServerOverlay({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Positioned.fill(
      child: Material(
        color: AppTheme.background,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingXl * 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.settings_rounded, size: 80, color: AppTheme.textMuted),
                  const SizedBox(height: AppTheme.spacingXl),
                  const Text(
                    'Add a server from Settings to get started',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacingXl * 2),
                  FilledButton.icon(
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings_rounded),
                    label: Text(l10n.settings),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
