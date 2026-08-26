part of 'settings_screen.dart';

mixin _SettingsViewBuildMixin on __SettingsViewStateBase {
  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsScreenController>();
    final sync = Get.find<LibrarySyncService>();
    final layout = DoudouLayout.of(context);
    final useTwoPane =
        layout.isDesktop || (layout.isTablet && layout.size.width >= 840);
    final showHeader = !useTwoPane || !layout.isDesktop;
    final mq = MediaQuery.of(context);

    final topPadding = mq.padding.top +
        (layout.isPhone
            ? kTopPaddingNarrow
            : (showHeader ? kTopPaddingDesktop : 0.0));
    final horizontalPadding = widget.isBottomNavActive
        ? kContentLeftPaddingWithBottomNav
        : (useTwoPane ? 0.0 : layout.contentPadding.left);
    final rightPadding = widget.isBottomNavActive
        ? kContentRightPaddingSettingsWithBottomNav
        : layout.contentPadding.right;
    final bottomPadding = widget.isBottomNavActive
        ? kSettingsListBottomPadding
        : kContentBottomPaddingWithPlayer;

    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        rightPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) _buildHeader(context, useTwoPane),
          Expanded(
            child: useTwoPane
                ? _buildTwoPane(context, settings, sync)
                : _buildSinglePane(context, settings, sync, bottomPadding),
          ),
        ],
      ),
    );

    return content;
  }

}
