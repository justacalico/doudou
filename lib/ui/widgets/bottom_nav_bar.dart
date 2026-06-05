import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:doudou/ui/design/doudou_colors.dart';
import 'package:doudou/ui/design/doudou_motion.dart';
import 'package:doudou/ui/design/doudou_tokens.dart';
import 'package:doudou/ui/screens/Home/home_screen_controller.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final homeScreenController = Get.find<HomeScreenController>();
    final c = context.doudouColors;

    return Obx(() {
      final idx = homeScreenController.tabIndex.value;
      final safeIdx = idx.clamp(0, 3);
      final items = _navItems(context);

      return Center(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ClipRRect(
              borderRadius: DoudouRadii.r24,
              child: Container(
                height: 66,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.surfaceOverlay.withValues(alpha: 0.85),
                  borderRadius: DoudouRadii.r24,
                  border: Border.all(color: c.borderSubtle),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const pillInset = 6.0;
                    final itemWidth =
                        (constraints.maxWidth - pillInset * 2) /
                            items.length;
                    final pillWidth = 48.0;
                    final pillLeft = pillInset + (itemWidth * safeIdx) + (itemWidth - pillWidth) / 2;

                    return Stack(
                      children: [
                        AnimatedPositioned(
                          duration: DoudouMotion.selection,
                          curve: DoudouMotion.standard,
                          left: pillLeft,
                          top: 2,
                          bottom: 2,
                          width: pillWidth,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: c.textPrimary.withValues(alpha: 0.08),
                              borderRadius: DoudouRadii.r20,
                              boxShadow: [
                                BoxShadow(
                                  color: c.textPrimary.withValues(alpha: 0.05),
                                  blurRadius: 20,
                                  spreadRadius: -4,
                                ),
                              ],
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: DoudouRadii.r20,
                                boxShadow: [
                                  BoxShadow(
                                    color: c.textPrimary.withValues(alpha: 0.04),
                                    blurRadius: 16,
                                    spreadRadius: -8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: List.generate(items.length, (index) {
                            final selected = index == safeIdx;
                            final hovered = _hoveredIndex == index;
                            final item = items[index];
                            final fg =
                                (selected || hovered) ? c.accentPrimary : c.textTertiary;

                            return Expanded(
                              child: MouseRegion(
                                onEnter: (_) =>
                                    setState(() => _hoveredIndex = index),
                                onExit: (_) => setState(() {
                                  if (_hoveredIndex == index) {
                                    _hoveredIndex = null;
                                  }
                                }),
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: InkResponse(
                                    radius: 28,
                                    containedInkWell: true,
                                    highlightShape: BoxShape.rectangle,
                                    hoverColor: Colors.transparent,
                                    splashColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    onTap: () {
                                      if (index == safeIdx) return;
                                      HapticFeedback.selectionClick();
                                      homeScreenController
                                          .onBottonBarTabSelected(index);
                                    },
                                    child: SizedBox(
                                      height: double.infinity,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          AnimatedSlide(
                                            duration: DoudouMotion.selection,
                                            curve: DoudouMotion.standard,
                                            offset: (selected || hovered)
                                                ? const Offset(0, -0.03)
                                                : Offset.zero,
                                            child: AnimatedScale(
                                              duration: DoudouMotion.selection,
                                              curve: DoudouMotion.standard,
                                              scale: (selected || hovered)
                                                  ? 1.08
                                                  : 1.0,
                                              child: SizedBox(
                                                width: DoudouIconSize.nav + 4,
                                                height: DoudouIconSize.nav + 4,
                                                child: Center(
                                                  child: AnimatedSwitcher(
                                                    duration:
                                                        DoudouMotion.selection,
                                                    switchInCurve:
                                                        DoudouMotion.standard,
                                                    switchOutCurve:
                                                        DoudouMotion.standard,
                                                    transitionBuilder:
                                                        (child, animation) {
                                                      return ScaleTransition(
                                                        scale: Tween<double>(
                                                          begin: 0.9,
                                                          end: 1.0,
                                                        ).animate(animation),
                                                        child: FadeTransition(
                                                          opacity: animation,
                                                          child: child,
                                                        ),
                                                      );
                                                    },
                                                    child: Icon(
                                                      selected
                                                          ? item.icon
                                                          : item.outlinedIcon,
                                                      key: ValueKey<bool>(
                                                          selected),
                                                      size:
                                                          DoudouIconSize.nav,
                                                      color: fg,
                                                      shadows:
                                                          (selected || hovered)
                                                              ? [
                                                                  Shadow(
                                                                    color: c
                                                                        .accentPrimary
                                                                        .withValues(
                                                                            alpha:
                                                                                0.45),
                                                                    blurRadius:
                                                                        14,
                                                                  ),
                                                                ]
                                                              : null,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _NavItem {
  _NavItem({
    required this.icon,
    required this.outlinedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData outlinedIcon;
  final String label;
}

List<_NavItem> _navItems(BuildContext context) => [
      _NavItem(
        icon: Icons.home_rounded,
        outlinedIcon: Icons.home_outlined,
        label: context.l10n.home,
      ),
      _NavItem(
        icon: Icons.search_rounded,
        outlinedIcon: Icons.search_outlined,
        label: context.l10n.search,
      ),
      _NavItem(
        icon: Icons.library_music_rounded,
        outlinedIcon: Icons.library_music_outlined,
        label: context.l10n.library,
      ),
      _NavItem(
        icon: Icons.settings_rounded,
        outlinedIcon: Icons.settings_outlined,
        label: context.l10n.settings,
      ),
    ];
