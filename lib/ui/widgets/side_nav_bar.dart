import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/utils/app_l10n.dart';
import 'package:doudou/ui/design/doudou_colors.dart';
import 'package:doudou/ui/player/player_controller.dart';
import 'package:doudou/ui/screens/Home/home_screen_controller.dart';

class SideNavBar extends StatefulWidget {
  const SideNavBar({
    super.key,
    required this.minimized,
    required this.onMinimizeChanged,
  });

  final bool minimized;
  final ValueChanged<bool> onMinimizeChanged;

  @override
  State<SideNavBar> createState() => _SideNavBarState();
}

class _SideNavBarState extends State<SideNavBar> {
  ValueNotifier<int>? _tabIndexNotifier;
  Worker? _tabIndexWorker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tabIndexNotifier == null) {
      final controller = Get.find<HomeScreenController>();
      _tabIndexNotifier = ValueNotifier<int>(controller.tabIndex.value);
      _tabIndexWorker = ever(controller.tabIndex, (v) {
        _tabIndexNotifier!.value = v;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tabIndexWorker?.dispose();
    _tabIndexNotifier?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    final notifier = _tabIndexNotifier;
    if (notifier == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: context.doudouColors.borderSubtle),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: notifier,
              builder: (context, currentIndex, _) {
                return _SidebarContent(
                  currentIndex: currentIndex,
                  minimized: widget.minimized,
                  onMinimizeChanged: widget.onMinimizeChanged,
                );
              },
            ),
          ),
          Obx(
            () => SizedBox(
              height: playerController.currentSong.value != null
                  ? playerController.playerPanelMinHeight.value
                  : 0.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarContent extends StatelessWidget {
  const _SidebarContent({
    required this.currentIndex,
    required this.minimized,
    required this.onMinimizeChanged,
  });

  final int currentIndex;
  final bool minimized;
  final ValueChanged<bool> onMinimizeChanged;

  @override
  Widget build(BuildContext context) {
    final home = Get.find<HomeScreenController>();
    final c = context.doudouColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            c.raisedBackground,
            c.surfaceBase,
          ],
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
                  _SidebarBrand(minimized: minimized),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: minimized ? 8 : 12),
                    child: Column(
                      children: [
                        _SidebarTile(
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home_rounded,
                          label: context.l10n.home,
                          selected: currentIndex == 0,
                          compact: minimized,
                          onTap: () => home.onSideBarTabSelected(0),
                        ),
                        _SidebarTile(
                          icon: Icons.search_outlined,
                          activeIcon: Icons.search_rounded,
                          label: context.l10n.search,
                          selected: currentIndex == 1,
                          compact: minimized,
                          onTap: () => home.onSideBarTabSelected(1),
                        ),
                        _SidebarTile(
                          icon: Icons.folder_outlined,
                          activeIcon: Icons.folder_rounded,
                          label: context.l10n.library,
                          selected: currentIndex == 2,
                          compact: minimized,
                          onTap: () => home.onSideBarTabSelected(2),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: minimized ? 16 : 24),
                  if (!minimized)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        context.l10n.library.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: c.textTertiary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  SizedBox(height: minimized ? 4 : 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: minimized ? 8 : 12),
                    child: Column(
                      children: [
                        _SidebarTile(
                          icon: Icons.audiotrack,
                          activeIcon: Icons.audiotrack,
                          label: context.l10n.songs,
                          selected: currentIndex == 3,
                          compact: minimized,
                          onTap: () => home.onSideBarTabSelected(3),
                        ),
                        _SidebarTile(
                          icon: Icons.library_music_outlined,
                          activeIcon: Icons.library_music,
                          label: context.l10n.playlists,
                          selected: currentIndex == 4,
                          compact: minimized,
                          onTap: () => home.onSideBarTabSelected(4),
                        ),
                        _SidebarTile(
                          icon: Icons.album_outlined,
                          activeIcon: Icons.album,
                          label: context.l10n.albums,
                          selected: currentIndex == 5,
                          compact: minimized,
                          onTap: () => home.onSideBarTabSelected(5),
                        ),
                        _SidebarTile(
                          icon: Icons.person_outline,
                          activeIcon: Icons.person,
                          label: context.l10n.artists,
                          selected: currentIndex == 6,
                          compact: minimized,
                          onTap: () => home.onSideBarTabSelected(6),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(minimized ? 8 : 12),
            child: Column(
              children: [
                _SidebarTile(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: context.l10n.settings,
                  selected: currentIndex == 7,
                  compact: minimized,
                  onTap: () => home.onSideBarTabSelected(7),
                ),
                const SizedBox(height: 6),
                _SidebarTile(
                  icon: minimized
                      ? Icons.keyboard_double_arrow_right_rounded
                      : Icons.keyboard_double_arrow_left_rounded,
                  activeIcon: minimized
                      ? Icons.keyboard_double_arrow_right_rounded
                      : Icons.keyboard_double_arrow_left_rounded,
                  label: minimized ? "Expand sidebar" : context.l10n.shrinkSidebar,
                  selected: false,
                  compact: minimized,
                  onTap: () => onMinimizeChanged(!minimized),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand({required this.minimized});

  final bool minimized;

  @override
  Widget build(BuildContext context) {
    final c = context.doudouColors;
    return Padding(
      padding: EdgeInsets.all(minimized ? 12 : 16),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: minimized ? 10 : 12,
          vertical: minimized ? 8 : 10,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: c.accentPrimary.withValues(alpha: 0.35),
          ),
          color: c.surfaceOverlay.withValues(alpha: 0.7),
        ),
        child: Row(
          mainAxisAlignment:
              minimized ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.surfaceBase,
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/icons/icon.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.music_note_rounded,
                  color: c.accentPrimary,
                  size: 20,
                ),
              ),
            ),
            if (!minimized) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Doudou',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SidebarTile extends StatefulWidget {
  const _SidebarTile({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.doudouColors;
    final iconColor = widget.selected
        ? c.textPrimary
        : (_hover ? c.textPrimary : c.textSecondary);
    final bgColor = widget.selected
        ? c.accentPrimary.withValues(alpha: 0.16)
        : (_hover ? c.accentPrimary.withValues(alpha: 0.08) : Colors.transparent);
    final borderColor =
        widget.selected ? c.accentPrimary.withValues(alpha: 0.45) : Colors.transparent;

    return Tooltip(
      message: widget.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 4),
            padding: widget.compact
                ? const EdgeInsets.symmetric(horizontal: 10, vertical: 11)
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: bgColor,
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment:
                  widget.compact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  widget.selected ? widget.activeIcon : widget.icon,
                  color: iconColor,
                  size: 20,
                ),
                if (!widget.compact) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            widget.selected ? FontWeight.w600 : FontWeight.w500,
                        color: iconColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
