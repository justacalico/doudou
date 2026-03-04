import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../player_controller.dart';

class LyricsBlockHighlightView extends StatefulWidget {
  const LyricsBlockHighlightView({super.key, required this.padding});

  final EdgeInsetsGeometry padding;

  @override
  State<LyricsBlockHighlightView> createState() =>
      _LyricsBlockHighlightViewState();
}

class _LyricsBlockHighlightViewState extends State<LyricsBlockHighlightView> {
  final ScrollController _scrollController = ScrollController();
  int _lastAutoScrolledIndex = -1;

  void _autoScrollToLine(int index) {
    if (index < 0 || !_scrollController.hasClients) return;
    if (_lastAutoScrolledIndex == index) return;
    _lastAutoScrolledIndex = index;

    const itemHeight = 68.0;
    final viewport = _scrollController.position.viewportDimension;
    final target = (index * itemHeight) - (viewport * 0.38);
    final clamped = target.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<PlayerController>();
    final theme = Theme.of(context);
    final textStyle = pc.isDesktopLyricsDialogOpen
        ? theme.textTheme.titleMedium
        : theme.textTheme.titleMedium?.copyWith(color: Colors.white);

    return Obx(() {
      final lines = pc.syncedLyricLines;
      if (lines.isEmpty) {
        return Center(
          child: Text(
            "syncedLyricsNotAvailable".tr,
            style: textStyle,
          ),
        );
      }

      final current = pc.currentSyncedLyricLineIndex(
        pc.progressBarStatus.value.current,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoScrollToLine(current);
      });

      final inactiveColor =
          (textStyle?.color ?? Colors.white).withValues(alpha: 0.62);
      final activeTextColor = textStyle?.color ?? Colors.white;

      return ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: widget.padding,
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final isActive = index == current;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isActive
                    ? theme.colorScheme.primary.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                style: (textStyle ?? const TextStyle()).copyWith(
                  color: isActive ? activeTextColor : inactiveColor,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                ),
                child: Text(
                  lines[index].text,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      );
    });
  }
}
