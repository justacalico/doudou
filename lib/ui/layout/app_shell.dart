import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/services/base_service.dart';
import 'package:doudou/services/navigation_service.dart';
import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/layout/desktop_layout.dart'
    show DesktopLayout, DesktopPlayerBar;
import 'package:doudou/ui/widgets/universal_image.dart'
    show buildSmartImage;
import 'package:doudou/ui/playing/now_playing.dart'
    show NowPlayingScreen;

import 'package:doudou/ui/pages/home_page.dart';
import 'package:doudou/ui/pages/search_page.dart';
import 'package:doudou/ui/pages/library_page.dart';
import 'package:doudou/ui/pages/albums_page.dart';
import 'package:doudou/ui/pages/artists_page.dart';
import 'package:doudou/ui/pages/tracks_page.dart';
import 'package:doudou/ui/pages/playlists_page.dart';
import 'package:doudou/ui/pages/downloads_page.dart';
import 'package:doudou/ui/pages/settings_page.dart';
import 'package:doudou/ui/onboarding/onboarding_screen.dart';

/// Breakpoint: above = sidebar (desktop), below = bottom nav (mobile).
const double kLayoutBreakpoint = 768.0;

/// Single responsive shell: sidebar on desktop, bottom navbar on mobile.
/// Uses one [selectedIndex] and one set of pages so resizing never reloads or loses state.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final NavigationService _nav = NavigationService();
  late int _selectedIndex;
  List<Widget Function()> _pageBuilders = [];
  final Map<int, Widget> _builtPages = {};
  int _pageCount = 0;
  int _settingsIndex = 0;
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
    if (idx != _selectedIndex && idx >= 0 && idx < _pageCount) {
      setState(() => _selectedIndex = idx);
    }
  }

  void _onDetailChanged() => setState(() {});

  bool get _isLocalMusic {
    return context.read<AppState>().mediaServiceManager.currentServerType ==
        ServerType.local;
  }

  void _rebuildPageLists() {
    final oldSettingsIndex = _settingsIndex;
    final hadPages = _pageCount > 0;
    _navItems = _buildNavItems();
    _libraryItems = _buildLibraryItems();
    _pageBuilders = _buildPageBuilders();
    _pageCount = _pageBuilders.length;
    _settingsIndex = _pageCount - 1;
    _builtPages.clear();
    if (hadPages && (_selectedIndex == oldSettingsIndex || _selectedIndex >= _pageCount)) {
      _selectedIndex = _settingsIndex;
      _nav.selectPage(_settingsIndex);
      if (mounted) setState(() {});
    }
  }

  List<Widget Function()> _buildPageBuilders() {
    return [
      () => const HomePage(),
      () => const SearchPage(),
      () => const LibraryPage(),
      () => const AlbumsPage(),
      () => const ArtistsPage(),
      () => const TracksPage(),
      () => const PlaylistsPage(),
      if (!_isLocalMusic) () => const DownloadsPage(),
      () => const SettingsPage(),
    ];
  }

  Widget _getOrBuildPage(int index) {
    if (_builtPages.containsKey(index)) return _builtPages[index]!;
    final page = _pageBuilders[index]();
    _builtPages[index] = page;
    return page;
  }

  List<_NavItem> _buildNavItems() => [
        const _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
        const _NavItem(Icons.search_outlined, Icons.search_rounded, 'Search'),
        const _NavItem(
          Icons.library_music_outlined,
          Icons.library_music_rounded,
          'Library',
        ),
      ];

  List<_NavItem> _buildLibraryItems() {
    return [
      const _NavItem(Icons.album_outlined, Icons.album_rounded, 'Albums'),
      const _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Artists'),
      const _NavItem(Icons.music_note_outlined, Icons.music_note_rounded, 'Tracks'),
      const _NavItem(
        Icons.queue_music_outlined,
        Icons.queue_music_rounded,
        'Playlists',
      ),
      if (!_isLocalMusic)
        const _NavItem(Icons.download_outlined, Icons.download_rounded, 'Downloads'),
    ];
  }

  void _navigateTo(int index) {
    _nav.selectPage(index);
    if (index != _selectedIndex && index < _pageCount) {
      setState(() => _selectedIndex = index);
    }
  }

  /// Single source of truth for mobile bottom bar items (indices, labels, icons).
  List<_MobileNavEntry> _getMobileNavEntries(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      _MobileNavEntry(0, l10n.navHome, _navItems[0].icon, _navItems[0].activeIcon),
      _MobileNavEntry(1, l10n.search, _navItems[1].icon, _navItems[1].activeIcon),
      _MobileNavEntry(2, l10n.library, _navItems[2].icon, _navItems[2].activeIcon),
      if (!_isLocalMusic)
        _MobileNavEntry(
          _navItems.length + 4,
          l10n.downloads,
          _libraryItems[4].icon,
          _libraryItems[4].activeIcon,
        ),
      _MobileNavEntry(
        _settingsIndex,
        l10n.settings,
        Icons.settings_outlined,
        Icons.settings_rounded,
      ),
    ];
  }

  Widget? _buildDetailOverlay() {
    return DesktopLayout.buildDetailOverlay(context, _nav);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isLocal = context.read<AppState>().mediaServiceManager.currentServerType ==
        ServerType.local;
    final wasLocal = _libraryItems.length == 4;
    if (isLocal != wasLocal) _rebuildPageLists();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (!appState.isLoggedIn) {
      if (!appState.onboardingCompleted) {
        return const OnboardingScreen();
      }
      return Scaffold(
        backgroundColor: DesktopTheme.backgroundDeep,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 80,
                  color: DesktopTheme.textMuted,
                ),
                const SizedBox(height: 24),
                Text(
                  'No server connected',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: DesktopTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add a server in Settings to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: DesktopTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Open Settings'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= kLayoutBreakpoint;
        return KeyboardListener(
          focusNode: FocusNode(),
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: KeyedSubtree(
            key: ValueKey(isDesktop),
            child: Scaffold(
              backgroundColor: DesktopTheme.backgroundDeep,
              extendBody: !isDesktop,
              body: Padding(
              padding: EdgeInsets.only(
                bottom: isDesktop
                    ? 0
                    : 72 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (isDesktop)
                          _Sidebar(
                            currentIndex: _selectedIndex,
                            navItems: _navItems,
                            libraryItems: _libraryItems,
                            settingsIndex: _settingsIndex,
                            onTap: _navigateTo,
                          ),
                        Expanded(
                          child: Container(
                            color: DesktopTheme.backgroundPrimary,
                            child: Stack(
                              children: [
                                IndexedStack(
                                  index: _selectedIndex.clamp(0, _pageCount - 1),
                                  children: List.generate(
                                    _pageCount,
                                    (i) => i == _selectedIndex
                                        ? _getOrBuildPage(i)
                                        : (_builtPages[i] ?? const SizedBox.shrink()),
                                  ),
                                ),
                                if (_buildDetailOverlay() != null)
                                  Positioned.fill(child: _buildDetailOverlay()!),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  isDesktop
                      ? const DesktopPlayerBar()
                      : const _MobilePlayerBar(),
                ],
              ),
            ),
            bottomNavigationBar: isDesktop
                ? null
                : _MobileNavBar(
                    entries: _getMobileNavEntries(context),
                    currentIndex: _selectedIndex,
                    onTap: _navigateTo,
                  ),
            ),
          ),
        );
      },
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final appState = context.read<AppState>();
    if (event.logicalKey == LogicalKeyboardKey.space) {
      appState.playPause();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
        HardwareKeyboard.instance.isControlPressed) {
      appState.skipToNext();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
        HardwareKeyboard.instance.isControlPressed) {
      appState.skipToPrevious();
    }
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

/// Single source for mobile bottom bar: index, label, icons.
class _MobileNavEntry {
  final int index;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _MobileNavEntry(this.index, this.label, this.icon, this.activeIcon);
}

class _Sidebar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> navItems;
  final List<_NavItem> libraryItems;
  final int settingsIndex;
  final ValueChanged<int> onTap;

  const _Sidebar({
    required this.currentIndex,
    required this.navItems,
    required this.libraryItems,
    required this.settingsIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Container(
      width: DesktopTheme.sidebarWidth,
      decoration: BoxDecoration(
        color: DesktopTheme.backgroundSidebar,
        border: Border(
          right: BorderSide(color: DesktopTheme.glassBorder, width: 1),
        ),
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
                    padding: const EdgeInsets.all(DesktopTheme.spacingLg),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                            boxShadow: DesktopTheme.shadowGlow(accent),
                          ),
                          child: const Icon(
                            Icons.music_note_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Doudou',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: DesktopTheme.textPrimary,
                          ) ?? TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: DesktopTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: navItems.asMap().entries.map((e) => _SidebarTile(
                            icon: e.value.icon,
                            activeIcon: e.value.activeIcon,
                            label: _navLabel(l10n, e.key),
                            selected: currentIndex == e.key,
                            onTap: () => onTap(e.key),
                            isSettings: false,
                          )).toList(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      l10n.library.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: DesktopTheme.textTertiary,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: libraryItems.asMap().entries.map((e) {
                        final idx = navItems.length + e.key;
                        return _SidebarTile(
                          icon: e.value.icon,
                          activeIcon: e.value.activeIcon,
                          label: _libraryLabel(l10n, e.key),
                          selected: currentIndex == idx,
                          onTap: () => onTap(idx),
                          isSettings: false,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: DesktopTheme.glassBorder, width: 1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _SidebarTile(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: l10n.settings,
                  selected: currentIndex == settingsIndex,
                  onTap: () => onTap(settingsIndex),
                  isSettings: true,
                ),
              ),
            ),
          ),
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

  String _libraryLabel(AppLocalizations l10n, int index) {
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
}

class _SidebarTile extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isSettings;

  const _SidebarTile({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.isSettings = false,
  });

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    if (widget.isSettings) {
      return MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: DesktopTheme.durationFast,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: widget.selected
                  ? accent.withOpacity(0.15)
                  : accent.withOpacity(0.1),
              border: Border.all(
                color: accent.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: widget.selected
                  ? [
                      BoxShadow(
                        color: accent.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  widget.selected ? widget.activeIcon : widget.icon,
                  color: accent,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: widget.selected
                ? DesktopTheme.sidebarActive
                : _hover
                    ? DesktopTheme.sidebarHover
                    : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                widget.selected ? widget.activeIcon : widget.icon,
                color: widget.selected
                    ? DesktopTheme.textPrimary
                    : _hover
                        ? DesktopTheme.textPrimary
                        : DesktopTheme.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                    color: widget.selected
                        ? DesktopTheme.textPrimary
                        : _hover
                            ? DesktopTheme.textPrimary
                            : DesktopTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavBar extends StatelessWidget {
  final List<_MobileNavEntry> entries;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _MobileNavBar({
    required this.entries,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SafeArea(
        top: false,
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DesktopTheme.radiusXl),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(DesktopTheme.radiusXl),
                  color: (isDark ? Colors.white : Colors.black)
                      .withOpacity(isDark ? 0.12 : 0.06),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black)
                        .withOpacity(0.15),
                    width: 0.5,
                  ),
                  boxShadow: DesktopTheme.shadowMd,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: entries.map((e) {
                    final selected = currentIndex == e.index;
                    return Expanded(
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onTap(e.index);
                        },
                        borderRadius: BorderRadius.circular(DesktopTheme.radiusMd),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  selected ? e.activeIcon : e.icon,
                                  size: 24,
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : (isDark
                                          ? Colors.white.withOpacity(0.6)
                                          : Colors.black.withOpacity(0.5)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  e.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                        selected ? FontWeight.w600 : FontWeight.w500,
                                    color: selected
                                        ? theme.colorScheme.primary
                                        : (isDark
                                            ? Colors.white.withOpacity(0.5)
                                            : Colors.black.withOpacity(0.4)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mobile playbar: old mini-player style (rounded liquid glass, album art, play/next).
class _MobilePlayerBar extends StatelessWidget {
  const _MobilePlayerBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<AppState>(
      builder: (context, appState, _) {
        final handler = appState.audioHandler;
        if (handler == null) return const SizedBox.shrink();
        return StreamBuilder<MediaItem?>(
          stream: handler.mediaItem,
          builder: (context, snap) {
            final mediaItem = snap.data;
            if (mediaItem == null) return const SizedBox.shrink();
            return StreamBuilder<PlaybackState>(
              stream: handler.playbackState,
              builder: (context, playSnap) {
                final playing = playSnap.data?.playing ?? false;
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (_, _, _) =>
                            const NowPlayingScreen(),
                        transitionDuration:
                            const Duration(milliseconds: 300),
                        reverseTransitionDuration:
                            const Duration(milliseconds: 300),
                        transitionsBuilder:
                            (_, animation, _, child) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 1),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeInOut,
                            )),
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                            sigmaX: 30, sigmaY: 30),
                        child: Container(
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(22),
                            color: (isDark
                                    ? Colors.white
                                    : Colors.black)
                                .withOpacity(
                                    isDark ? 0.12 : 0.06),
                            border: Border.all(
                              color: (isDark
                                      ? Colors.white
                                      : Colors.black)
                                  .withOpacity(0.12),
                              width: 0.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(0.25),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets
                                .symmetric(
                                horizontal: 14,
                                vertical: 10),
                            child: Row(
                              children: [
                                _albumArt(mediaItem),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .center,
                                    children: [
                                      Text(
                                        mediaItem.title,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight:
                                              FontWeight.w600,
                                          color: isDark
                                              ? Colors
                                                  .white
                                              : Colors
                                                  .black,
                                        ),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                      ),
                                      const SizedBox(
                                          height: 2),
                                      Text(
                                        mediaItem.artist ??
                                            'Unknown Artist',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: (isDark
                                                  ? Colors
                                                      .white
                                                  : Colors
                                                      .black)
                                              .withOpacity(0.6),
                                        ),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize:
                                      MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        playing
                                            ? Icons
                                                .pause_rounded
                                            : Icons
                                                .play_arrow_rounded,
                                        color: theme
                                            .colorScheme
                                            .primary,
                                        size: 28,
                                      ),
                                      onPressed: () =>
                                          appState
                                              .playPause(),
                                      style: IconButton
                                          .styleFrom(
                                        minimumSize:
                                            const Size(
                                                40, 40),
                                              ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons
                                            .skip_next_rounded,
                                        size: 24,
                                        color: handler
                                                .hasNext ==
                                            true
                                            ? (isDark
                                                ? Colors
                                                    .white
                                                : Colors
                                                    .black)
                                            : Colors.grey,
                                      ),
                                      onPressed: handler
                                              .hasNext ==
                                          true
                                          ? () => appState
                                              .skipToNext()
                                          : null,
                                      style: IconButton
                                          .styleFrom(
                                        minimumSize:
                                            const Size(
                                                36, 36),
                                              ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.close_rounded,
                                        size: 22,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                      onPressed: () =>
                                          appState
                                              .closePlayerAndClearQueue(),
                                      tooltip: 'Close and clear queue',
                                      style: IconButton
                                          .styleFrom(
                                        minimumSize:
                                            const Size(
                                                36, 36),
                                              ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _albumArt(MediaItem mediaItem) {
    String? imageUrl = mediaItem.artUri?.toString();
    if (imageUrl == null || imageUrl.isEmpty) {
      imageUrl = mediaItem.extras?['localImageUrl'] as String?;
    }
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(12),
        child: imageUrl != null &&
                imageUrl.isNotEmpty
            ? buildSmartImage(
                imageUrl: imageUrl,
                width: 52,
                height: 52,
                errorBuilder: () =>
                    _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 52,
      height: 52,
      color: DesktopTheme.backgroundElevated,
      child: Icon(
        Icons.music_note_rounded,
        color: DesktopTheme.textTertiary,
        size: 24,
      ),
    );
  }
}
