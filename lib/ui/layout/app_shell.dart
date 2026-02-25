import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/services/base_service.dart';
import 'package:doudou/services/navigation_service.dart';
import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/layout/desktop_layout.dart'
    show DesktopLayout, DesktopPlayerBar;
import 'package:doudou/ui/widgets/universal_image.dart' show buildSmartImage;
import 'package:doudou/ui/playing/now_playing.dart' show NowPlayingScreen;

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

/// Below this, keep compact sidebar to preserve usable content width.
const double kCompactSidebarLockBreakpoint = 840.0;

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
  bool _sidebarCompact = false;
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

  void _rebuildPageLists() {
    final oldSettingsIndex = _settingsIndex;
    final hadPages = _pageCount > 0;
    final appState = context.read<AppState>();
    _navItems = _buildNavItems();
    _libraryItems = _buildLibraryItems(appState);
    _pageBuilders = _buildPageBuilders(appState);
    _pageCount = _pageBuilders.length;
    _settingsIndex = _pageCount - 1;
    _builtPages.clear();
    if (hadPages &&
        (_selectedIndex == oldSettingsIndex || _selectedIndex >= _pageCount)) {
      _selectedIndex = _settingsIndex;
      _nav.selectPage(_settingsIndex);
      if (mounted) setState(() {});
    }
  }

  List<Widget Function()> _buildPageBuilders(AppState appState) {
    final isLocal =
        appState.mediaServiceManager.currentServerType == ServerType.local;
    return [
      () => const HomePage(),
      () => const SearchPage(),
      () => const LibraryPage(),
      () => const AlbumsPage(),
      () => const ArtistsPage(),
      () => const TracksPage(),
      () => const PlaylistsPage(),
      if (!isLocal && appState.downloadsEnabled) () => const DownloadsPage(),
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

  List<_NavItem> _buildLibraryItems(AppState appState) {
    final isLocal =
        appState.mediaServiceManager.currentServerType == ServerType.local;
    return [
      const _NavItem(Icons.album_outlined, Icons.album_rounded, 'Albums'),
      const _NavItem(
        Icons.person_outline_rounded,
        Icons.person_rounded,
        'Artists',
      ),
      const _NavItem(
        Icons.music_note_outlined,
        Icons.music_note_rounded,
        'Tracks',
      ),
      const _NavItem(
        Icons.queue_music_outlined,
        Icons.queue_music_rounded,
        'Playlists',
      ),
      if (!isLocal && appState.downloadsEnabled)
        const _NavItem(
          Icons.download_outlined,
          Icons.download_rounded,
          'Downloads',
        ),
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
    final appState = context.read<AppState>();
    final isLocal =
        appState.mediaServiceManager.currentServerType == ServerType.local;
    final showDownloads = !isLocal && appState.downloadsEnabled;
    return [
      _MobileNavEntry(
        0,
        l10n.navHome,
        _navItems[0].icon,
        _navItems[0].activeIcon,
      ),
      _MobileNavEntry(
        1,
        l10n.search,
        _navItems[1].icon,
        _navItems[1].activeIcon,
      ),
      _MobileNavEntry(
        2,
        l10n.library,
        _navItems[2].icon,
        _navItems[2].activeIcon,
      ),
      if (showDownloads)
        _MobileNavEntry(
          _settingsIndex - 1,
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
    final appState = context.read<AppState>();
    final isLocal =
        appState.mediaServiceManager.currentServerType == ServerType.local;
    final showDownloads = !isLocal && appState.downloadsEnabled;
    final hadDownloads = _libraryItems.length == 5;
    if (showDownloads != hadDownloads) {
      _rebuildPageLists();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context);
    // When downloadsEnabled or server type changes, page list may need to change
    final isLocal =
        appState.mediaServiceManager.currentServerType == ServerType.local;
    final showDownloads = !isLocal && appState.downloadsEnabled;
    final expectedCount = 7 + (showDownloads ? 1 : 0) + 1; // pages + settings
    if (expectedCount != _pageCount && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _rebuildPageLists();
          setState(() {});
        }
      });
    }
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
                  l10n.noServerConnected,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: DesktopTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.addServerInSettingsToStart,
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
                  label: Text(l10n.openSettings),
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
        final forceCompactSidebar =
            constraints.maxWidth < kCompactSidebarLockBreakpoint;
        final effectiveCompactSidebar =
            isDesktop && (forceCompactSidebar || _sidebarCompact);
        return KeyboardListener(
          focusNode: FocusNode(),
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: KeyedSubtree(
            key: ValueKey(isDesktop),
            child: Scaffold(
              backgroundColor: DesktopTheme.backgroundDeep,
              extendBody: !isDesktop,
              body: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: isDesktop ? 0 : 20),
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
                                  compact: effectiveCompactSidebar,
                                  onToggleCompact: () {
                                    setState(
                                      () => _sidebarCompact = !_sidebarCompact,
                                    );
                                  },
                                  onTap: _navigateTo,
                                ),
                              Expanded(
                                child: Container(
                                  color: DesktopTheme.backgroundPrimary,
                                  child: Stack(
                                    children: [
                                      IndexedStack(
                                        index: _selectedIndex.clamp(
                                          0,
                                          _pageCount - 1,
                                        ),
                                        children: List.generate(
                                          _pageCount,
                                          (i) => i == _selectedIndex
                                              ? _getOrBuildPage(i)
                                              : (_builtPages[i] ??
                                                    const SizedBox.shrink()),
                                        ),
                                      ),
                                      if (_buildDetailOverlay() != null)
                                        Positioned.fill(
                                          child: _buildDetailOverlay()!,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isDesktop) const DesktopPlayerBar(),
                      ],
                    ),
                  ),
                  if (!isDesktop)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _MobileFloatingDock(
                        entries: _getMobileNavEntries(context),
                        currentIndex: _selectedIndex,
                        onTap: _navigateTo,
                      ),
                    ),
                ],
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
  final bool compact;
  final VoidCallback onToggleCompact;
  final ValueChanged<int> onTap;

  const _Sidebar({
    required this.currentIndex,
    required this.navItems,
    required this.libraryItems,
    required this.settingsIndex,
    required this.compact,
    required this.onToggleCompact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final sidebarWidth = compact ? 88.0 : DesktopTheme.sidebarWidth;
    return AnimatedContainer(
      duration: DesktopTheme.durationMedium,
      curve: Curves.easeOutCubic,
      width: sidebarWidth,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            DesktopTheme.backgroundSidebar,
            DesktopTheme.backgroundPrimary,
          ],
        ),
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
                    padding: EdgeInsets.all(
                      compact ? 12 : DesktopTheme.spacingLg,
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 10 : 12,
                        vertical: compact ? 8 : 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          DesktopTheme.radiusMd,
                        ),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.35),
                        ),
                        color: DesktopTheme.backgroundTertiary.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: compact
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: DesktopTheme.backgroundTertiary,
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusMd,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              'assets/icons/icon.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.music_note_rounded,
                                color: accent,
                                size: 20,
                              ),
                            ),
                          ),
                          if (!compact) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Doudou',
                                style:
                                    theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: DesktopTheme.textPrimary,
                                      letterSpacing: -0.2,
                                    ) ??
                                    TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: DesktopTheme.textPrimary,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16),
                    child: Column(
                      children: navItems
                          .asMap()
                          .entries
                          .map(
                            (e) => _SidebarTile(
                              icon: e.value.icon,
                              activeIcon: e.value.activeIcon,
                              label: _navLabel(l10n, e.key),
                              selected: currentIndex == e.key,
                              onTap: () => onTap(e.key),
                              compact: compact,
                              isSettings: false,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  SizedBox(height: compact ? 20 : 32),
                  if (!compact)
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
                  SizedBox(height: compact ? 4 : 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16),
                    child: Column(
                      children: libraryItems.asMap().entries.map((e) {
                        final idx = navItems.length + e.key;
                        return _SidebarTile(
                          icon: e.value.icon,
                          activeIcon: e.value.activeIcon,
                          label: _libraryLabel(l10n, e.key),
                          selected: currentIndex == idx,
                          onTap: () => onTap(idx),
                          compact: compact,
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
            padding: EdgeInsets.all(compact ? 8 : 16),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: compact
                      ? BorderSide.none
                      : BorderSide(color: DesktopTheme.glassBorder, width: 1),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(top: compact ? 0 : 16),
                child: Column(
                  children: [
                    _SidebarTile(
                      icon: Icons.settings_outlined,
                      activeIcon: Icons.settings_rounded,
                      label: l10n.settings,
                      selected: currentIndex == settingsIndex,
                      onTap: () => onTap(settingsIndex),
                      compact: compact,
                      isSettings: true,
                    ),
                    const SizedBox(height: 8),
                    _SidebarTile(
                      icon: compact
                          ? Icons.keyboard_double_arrow_right_rounded
                          : Icons.keyboard_double_arrow_left_rounded,
                      activeIcon: compact
                          ? Icons.keyboard_double_arrow_right_rounded
                          : Icons.keyboard_double_arrow_left_rounded,
                      label: compact ? 'Full view' : 'Shrink sidebar',
                      selected: false,
                      onTap: onToggleCompact,
                      compact: compact,
                      isSettings: false,
                    ),
                  ],
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
  final bool compact;
  final bool isSettings;

  const _SidebarTile({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.compact,
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
    final tile = widget.isSettings
        ? _buildSettingsTile(context, accent)
        : _buildDefaultTile(context);
    return Tooltip(message: widget.label, child: tile);
  }

  Widget _buildSettingsTile(BuildContext context, Color accent) {
    if (widget.isSettings) {
      return MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: DesktopTheme.durationFast,
            padding: widget.compact
                ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: widget.selected
                  ? accent.withValues(alpha: 0.15)
                  : accent.withValues(alpha: 0.1),
              border: Border.all(
                color: accent.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: widget.selected
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: widget.compact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  widget.selected ? widget.activeIcon : widget.icon,
                  color: accent,
                  size: 20,
                ),
                if (!widget.compact) ...[
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
              ],
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildDefaultTile(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DesktopTheme.durationFast,
          margin: const EdgeInsets.only(bottom: 4),
          padding: widget.compact
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 12)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: widget.selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.16)
                : _hover
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            border: widget.selected
                ? Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.45),
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: widget.compact
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
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
              if (!widget.compact) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: widget.selected
                          ? FontWeight.w600
                          : FontWeight.w500,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileFloatingDock extends StatelessWidget {
  final List<_MobileNavEntry> entries;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _MobileFloatingDock({
    required this.entries,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appState = context.watch<AppState>();
    final handler = appState.audioHandler;
    final track = handler?.currentTrack;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (track != null) ...[
              _MobileNowPlayingCapsule(
                isDark: isDark,
                onTapOpen: () => _openNowPlaying(context),
                title: track.name,
                artist: track.artistName ?? 'Unknown Artist',
                imageUrl: track.imageUrl != null
                    ? appState.getImageUrl(track.imageUrl!)
                    : null,
                isPlaying: handler.userIntendedPlaying,
                hasNext: handler.hasNext,
                onPlayPause: appState.playPause,
                onSkipNext: appState.skipToNext,
                onClose: appState.closePlayerAndClearQueue,
              ),
              const SizedBox(height: 10),
            ],
            RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          (isDark ? Colors.white : Colors.black).withValues(
                            alpha: isDark ? 0.2 : 0.07,
                          ),
                          (isDark ? Colors.white : Colors.black).withValues(
                            alpha: isDark ? 0.12 : 0.04,
                          ),
                        ],
                      ),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: isDark ? 0.38 : 0.2,
                        ),
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
                            borderRadius: BorderRadius.circular(18),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 8,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      selected ? e.activeIcon : e.icon,
                                      size: 22,
                                      color: selected
                                          ? theme.colorScheme.primary
                                          : (isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.7,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.55,
                                                  )),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      e.label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: selected
                                            ? theme.colorScheme.primary
                                            : (isDark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.52,
                                                    )
                                                  : Colors.black.withValues(
                                                      alpha: 0.45,
                                                    )),
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
          ],
        ),
      ),
    );
  }

  void _openNowPlaying(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const NowPlayingScreen(),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_, animation, _, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                ),
            child: child,
          );
        },
      ),
    );
  }
}

class _MobileNowPlayingCapsule extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTapOpen;
  final String title;
  final String artist;
  final String? imageUrl;
  final bool isPlaying;
  final bool hasNext;
  final VoidCallback onPlayPause;
  final VoidCallback onSkipNext;
  final VoidCallback onClose;

  const _MobileNowPlayingCapsule({
    required this.isDark,
    required this.onTapOpen,
    required this.title,
    required this.artist,
    required this.imageUrl,
    required this.isPlaying,
    required this.hasNext,
    required this.onPlayPause,
    required this.onSkipNext,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTapOpen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: 74,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (isDark ? Colors.white : Colors.black).withValues(
                    alpha: isDark ? 0.2 : 0.08,
                  ),
                  (isDark ? Colors.white : Colors.black).withValues(
                    alpha: isDark ? 0.12 : 0.05,
                  ),
                ],
              ),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(
                  alpha: isDark ? 0.38 : 0.22,
                ),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  _DockAlbumArt(imageUrl: imageUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                            height: 1.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          artist,
                          style: TextStyle(
                            fontSize: 13,
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.62),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: theme.colorScheme.primary,
                      size: 25,
                    ),
                    onPressed: onPlayPause,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(34, 34),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.skip_next_rounded,
                      size: 23,
                      color: hasNext
                          ? (isDark ? Colors.white : Colors.black)
                          : Colors.grey,
                    ),
                    onPressed: hasNext ? onSkipNext : null,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 21,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    onPressed: onClose,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                    ),
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

class _DockAlbumArt extends StatelessWidget {
  final String? imageUrl;

  const _DockAlbumArt({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? buildSmartImage(
                imageUrl: imageUrl!,
                width: 52,
                height: 52,
                errorBuilder: () => _dockArtPlaceholder(),
              )
            : _dockArtPlaceholder(),
      ),
    );
  }

  Widget _dockArtPlaceholder() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: DesktopTheme.backgroundElevated,
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: DesktopTheme.textTertiary,
        size: 24,
      ),
    );
  }
}
