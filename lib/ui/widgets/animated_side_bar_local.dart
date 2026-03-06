import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/utils/app_l10n.dart';

class SideBarAnimatedLocal extends StatefulWidget {
  final ValueChanged<int>? onTap;
  final Color sideBarColor;
  final Duration sideBarAnimationDuration;
  final Duration floatingAnimationDuration;
  final Color animatedContainerColor;
  final Color selectedIconColor;
  final Color unselectedIconColor;
  final Color dividerColor;
  final Color hoverColor;
  final Color splashColor;
  final Color highlightColor;
  final Color unSelectedTextColor;
  final double widthSwitch;
  final double borderRadius;
  final double sideBarWidth;
  final double sideBarSmallWidth;
  final String mainLogoImage;
  final String? appName;
  final List<SideBarItemLocal> sidebarItems;
  final String? shrinkSidebarLabel;
  final bool settingsDivider;
  final Curve curve;
  final TextStyle textStyle;
  final int initialIndex;
  final ValueListenable<int>? currentIndexListenable;
  final bool? minimized;
  final ValueChanged<bool>? onMinimizeChanged;
  final bool useDoudouLogo;

  const SideBarAnimatedLocal({
    super.key,
    this.sideBarColor = const Color(0xff1D1D1D),
    this.animatedContainerColor = const Color(0xff323232),
    this.unSelectedTextColor = const Color(0xffA0A5A9),
    this.selectedIconColor = Colors.white,
    this.unselectedIconColor = const Color(0xffA0A5A9),
    this.hoverColor = Colors.black38,
    this.splashColor = Colors.black87,
    this.highlightColor = Colors.black,
    this.borderRadius = 0,
    this.sideBarWidth = 260,
    this.sideBarSmallWidth = 84,
    this.settingsDivider = true,
    this.curve = Curves.easeOutCubic,
    this.sideBarAnimationDuration = const Duration(milliseconds: 240),
    this.floatingAnimationDuration = const Duration(milliseconds: 180),
    this.dividerColor = const Color(0xff929292),
    this.textStyle =
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    required this.mainLogoImage,
    this.appName,
    required this.sidebarItems,
    this.shrinkSidebarLabel,
    required this.widthSwitch,
    required this.onTap,
    this.initialIndex = 0,
    this.currentIndexListenable,
    this.minimized,
    this.onMinimizeChanged,
    this.useDoudouLogo = false,
  });

  @override
  State<SideBarAnimatedLocal> createState() => _SideBarAnimatedLocalState();
}

class _SideBarAnimatedLocalState extends State<SideBarAnimatedLocal>
    with SingleTickerProviderStateMixin {
  late double sideBarItemHeight;
  double _itemIndex = 0.0;
  bool _minimize = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    if (widget.sidebarItems.isEmpty) {
      throw "Side bar Items Can't be empty";
    }
    sideBarItemHeight = 48;
    _itemIndex = widget.initialIndex.toDouble();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200))
      ..addListener(() => setState(() {}));
    widget.currentIndexListenable?.addListener(_onCurrentIndexChanged);
  }

  void _onCurrentIndexChanged() {
    if (mounted) {
      final i = widget.currentIndexListenable?.value ?? widget.initialIndex;
      setState(() => _itemIndex = i.toDouble());
    }
  }

  @override
  void didUpdateWidget(covariant SideBarAnimatedLocal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndexListenable != widget.currentIndexListenable) {
      oldWidget.currentIndexListenable?.removeListener(_onCurrentIndexChanged);
      widget.currentIndexListenable?.addListener(_onCurrentIndexChanged);
      final i = widget.currentIndexListenable?.value ?? widget.initialIndex;
      _itemIndex = i.toDouble();
    } else if (widget.currentIndexListenable == null &&
        widget.initialIndex != oldWidget.initialIndex) {
      _itemIndex = widget.initialIndex.toDouble();
    }
  }

  @override
  void dispose() {
    widget.currentIndexListenable?.removeListener(_onCurrentIndexChanged);
    _animationController.dispose();
    super.dispose();
  }

  void moveToNewIndex(int index) {
    HapticFeedback.selectionClick();
    setState(() => _itemIndex = index.toDouble());
    widget.onTap?.call(index);
  }

  bool get _effectiveMinimize =>
      widget.minimized ?? _minimize;

  @override
  Widget build(BuildContext context) {
    final isMinimized = _effectiveMinimize;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final maxW = constraints.maxWidth;
        final screenW = MediaQuery.sizeOf(context).width;
        final useWideLayout = screenW >= widget.widthSwitch && !isMinimized;
        final isStatusBarAvailable = MediaQuery.of(context).padding.top > 0;
        final slotWidth = maxW.isFinite ? maxW : (useWideLayout ? widget.sideBarWidth : widget.sideBarSmallWidth);
        final platform = Theme.of(context).platform;
        final scrollPhysics = platform == TargetPlatform.iOS
            ? const BouncingScrollPhysics()
            : const ClampingScrollPhysics();
        return AnimatedContainer(
          curve: widget.curve,
          height: height,
          margin: EdgeInsets.zero,
          width: slotWidth,
          decoration: BoxDecoration(
            color: widget.sideBarColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          duration: widget.sideBarAnimationDuration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(
                    left: useWideLayout ? 24 : 18,
                    right: useWideLayout ? 24 : 18,
                    top: 24),
                child: widget.useDoudouLogo
                    ? _buildDoudouLogo(useWideLayout)
                    : Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: useWideLayout ? 12 : 6,
                          vertical: useWideLayout ? 10 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: widget.animatedContainerColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: useWideLayout
                            ? Row(
                                children: [
                                  Image.asset(
                                    widget.mainLogoImage,
                                    width: 40,
                                    height: 40,
                                  ),
                                  if (widget.appName != null) ...[
                                    const SizedBox(width: 12),
                                    Text(
                                      widget.appName!,
                                      style: widget.textStyle,
                                    ),
                                  ],
                                ],
                              )
                            : Center(
                                child: Image.asset(
                                  widget.mainLogoImage,
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.contain,
                                ),
                              ),
                      ),
              ),
              Expanded(
                child: ClipRect(
                  child: SingleChildScrollView(
                    physics: scrollPhysics,
                    padding: EdgeInsets.only(
                        top: isStatusBarAvailable ? 20 : 40,
                        left: useWideLayout ? 20 : 18,
                        right: useWideLayout ? 20 : 18,
                        bottom: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _buildNavItems(useWideLayout: useWideLayout),
                    ),
                  ),
                ),
              ),
              if (MediaQuery.sizeOf(context).width >= widget.widthSwitch)
                _buildCollapseButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDoudouLogo(bool useWideLayout) {
    final accent = widget.selectedIconColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.95),
                accent.withValues(alpha: 0.75),
              ],
            ),
            boxShadow: const [],
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        if (useWideLayout && widget.appName != null) ...[
          const SizedBox(width: 12),
          Text(
            widget.appName!,
            style: widget.textStyle.copyWith(letterSpacing: -0.2),
          ),
        ],
      ],
    );
  }

  Widget _buildCollapseButton() {
    return Padding(
      padding: EdgeInsets.only(
        left: _effectiveMinimize ? 18 : 20,
        right: _effectiveMinimize ? 18 : 20,
        bottom: 16,
        top: 8,
      ),
      child: Tooltip(
        message: widget.shrinkSidebarLabel ?? context.l10n.shrinkSidebar,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: InkWell(
            onTap: () {
              final next = !_effectiveMinimize;
              if (widget.onMinimizeChanged != null) {
                widget.onMinimizeChanged!(next);
              } else {
                setState(() => _minimize = next);
              }
            },
            borderRadius: BorderRadius.circular(12),
            hoverColor: widget.hoverColor,
            splashColor: widget.splashColor,
            highlightColor: widget.highlightColor,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: Center(
                child: Icon(
                  _effectiveMinimize ? Icons.menu : Icons.close,
                  size: 20,
                  color: widget.unselectedIconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildNavItems({required bool useWideLayout}) {
    final list = <Widget>[];
    for (var i = 0; i < widget.sidebarItems.length; i++) {
      if (i > 0) {
        if (i == widget.sidebarItems.length - 1 && widget.settingsDivider) {
          list.add(Divider(
            height: 16,
            thickness: 1,
            color: widget.dividerColor,
          ));
        } else {
          list.add(const SizedBox(height: 8));
        }
      }
      final item = widget.sidebarItems[i];
      final isSelected = _itemIndex.floor() == i;
      list.add(_sideBarItem(
        textStyle: widget.textStyle,
        unselectedIconColor: widget.unselectedIconColor,
        unSelectedTextColor: widget.unSelectedTextColor,
        showLabel: useWideLayout,
        isSelected: isSelected,
        selectedIcon: item.iconSelected,
        height: sideBarItemHeight,
        hoverColor: widget.hoverColor,
        splashColor: widget.splashColor,
        highlightColor: widget.highlightColor,
        animatedContainerColor: widget.animatedContainerColor,
        icon: item.iconUnselected ?? item.iconSelected,
        text: item.text,
        onTap: () => moveToNewIndex(i),
      ));
    }
    return list;
  }

  Widget _sideBarItem({
    required IconData icon,
    required IconData selectedIcon,
    required String text,
    required bool showLabel,
    required bool isSelected,
    required double height,
    required Color hoverColor,
    required Color unselectedIconColor,
    required Color splashColor,
    required Color highlightColor,
    required Color unSelectedTextColor,
    required Color animatedContainerColor,
    required VoidCallback onTap,
    required TextStyle textStyle,
  }) {
    final selectedColor = widget.selectedIconColor;
    return Tooltip(
      message: text,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: onTap,
          hoverColor: hoverColor,
          splashColor: splashColor,
          highlightColor: highlightColor,
          child: Container(
            height: height,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: isSelected
                ? BoxDecoration(
                    color: animatedContainerColor,
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected ? selectedColor : unselectedIconColor,
                  size: 22,
                ),
                if (showLabel) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: textStyle.copyWith(
                        color: isSelected ? selectedColor : unSelectedTextColor,
                        fontWeight: isSelected ? FontWeight.w500 : null,
                      ),
                    ),
                  ),
                ],
                if (isSelected && showLabel)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: selectedColor.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
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

class SideBarItemLocal {
  final IconData iconSelected;
  final IconData? iconUnselected;
  final String text;

  const SideBarItemLocal({
    required this.iconSelected,
    this.iconUnselected,
    required this.text,
  });
}
