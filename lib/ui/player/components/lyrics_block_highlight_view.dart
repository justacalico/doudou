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
  final Map<int, GlobalKey> _lineKeys = {};
  int _lastAutoScrolledIndex = -1;

  void _autoScrollToLine(int index) {
    if (index < 0) return;
    if (_lastAutoScrolledIndex == index) return;
    _lastAutoScrolledIndex = index;
    final key = _lineKeys[index];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.35,
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
      final syncedRaw = pc.lyrics['synced']?.toString() ?? '';
      final currentPosition = pc.progressBarStatus.value.current;
      final lines = pc.syncedLyricLines;
      if (syncedRaw.trim().isEmpty || lines.isEmpty) {
        return Center(
          child: Text(
            "syncedLyricsNotAvailable".tr,
            style: textStyle,
          ),
        );
      }

      final current = pc.currentSyncedLyricLineIndex(currentPosition);
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
          final lineKey = _lineKeys.putIfAbsent(index, () => GlobalKey());
          final isActive = index == current;
          return Padding(
            key: lineKey,
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
