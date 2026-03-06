import 'package:flutter/cupertino.dart';
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
    this.curve = Curves.easeOut,
    this.sideBarAnimationDuration = const Duration(milliseconds: 700),
    this.floatingAnimationDuration = const Duration(milliseconds: 500),
    this.dividerColor = const Color(0xff929292),
    this.textStyle =
        const TextStyle(fontFamily: "SFPro", fontSize: 16, color: Colors.white),
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
                    left: useWideLayout ? 20 : 18,
                    right: useWideLayout ? 20 : 18,
                    top: 24),
                child: Container(
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
                    physics: const BouncingScrollPhysics(),
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
                Padding(
                  padding: EdgeInsets.only(
                    left: isMinimized ? 18 : 20,
                    right: isMinimized ? 18 : 20,
                    bottom: 24,
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
                        height: sideBarItemHeight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Icon(
                                isMinimized
                                    ? CupertinoIcons.arrow_right
                                    : Icons.keyboard_double_arrow_left,
                                color: widget.unselectedIconColor,
                              ),
                              if (!isMinimized && widget.shrinkSidebarLabel != null) ...[
                                const SizedBox(width: 12),
                                Text(
                                  widget.shrinkSidebarLabel!,
                                  overflow: TextOverflow.ellipsis,
                                  style: widget.textStyle.copyWith(
                                      color: widget.unSelectedTextColor),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                )
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildNavItems({required bool useWideLayout}) {
    final list = <Widget>[];
    for (var i = 0; i < widget.sidebarItems.length; i++) {
      if (i > 0) {
        if (i == widget.sidebarItems.length - 1 && widget.settingsDivider) {
          list.add(Divider(
            height: 12,
            thickness: 0.2,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  color: isSelected ? Colors.white : unselectedIconColor,
                  size: 24,
                ),
                if (showLabel) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: textStyle.copyWith(
                        color: isSelected ? Colors.white : unSelectedTextColor,
                      ),
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
