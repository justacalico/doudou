part of 'settings_screen.dart';

mixin _SettingsViewLayoutMixin on __SettingsViewStateBase {
  String _clusterLabel(BuildContext context, String key) {
    final l10n = context.l10n;
    return switch (key) {
      'accounts' => l10n.accounts,
      'user' => l10n.user,
      'appearance' => l10n.appearance,
      _ => key,
    };
  }

  Widget _buildHeader(BuildContext context, bool useTwoPane) {
    final theme = Theme.of(context);
    final colors = context.doudouColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DoudouSpace.s4,
        10,
        DoudouSpace.s8,
        DoudouSpace.s16,
      ),
      child: Row(
        children: [
          if (useTwoPane) ...[
            Icon(
              Icons.settings_outlined,
              color: colors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: DoudouSpace.s8),
          ],
          Expanded(
            child: Text(
              context.l10n.settings,
              style: (useTwoPane
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.titleLarge)
                  ?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoPane(
    BuildContext context,
    SettingsScreenController settings,
    LibrarySyncService sync,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 260,
          child: _buildSectionNav(context),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: Duration(
              milliseconds: (220 * settings.animationSpeedFactor).round(),
            ),
            child: KeyedSubtree(
              key: ValueKey(_selected),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: _SettingsCard(
                        icon: _sectionIcon(_selected),
                        title: _sectionTitle(context, _selected),
                        borderRadius: BorderRadius.zero,
                        margin: EdgeInsets.zero,
                        color: Theme.of(context).scaffoldBackgroundColor,
                        children: _buildSectionChildren(
                          context,
                          settings,
                          sync,
                          _selected,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSinglePane(
    BuildContext context,
    SettingsScreenController settings,
    LibrarySyncService sync,
    double bottomPadding,
  ) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(bottom: bottomPadding),
      itemCount: _groupedClusters.length,
      itemBuilder: (context, index) {
        final group = _groupedClusters[index];
        final header = _clusterLabel(context, group.$2);
        final sections = group.$3;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                DoudouSpace.s8,
                index == 0 ? DoudouSpace.s2 : DoudouSpace.s20,
                DoudouSpace.s8,
                DoudouSpace.s8,
              ),
              child: Text(
                header,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.doudouColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
              ),
            ),
            _SettingsCard(
              children: [
                for (int i = 0; i < sections.length; i++) ...[
                  _buildMobileSectionRow(
                    context,
                    settings,
                    sync,
                    sections[i],
                  ),
                  if (i < sections.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionNav(BuildContext context) {
    final colors = context.doudouColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceBase,
        border: Border(
          right: BorderSide(color: colors.borderSubtle),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(DoudouSpace.s12),
        children: [
          for (final group in _groupedClusters) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DoudouSpace.s4,
                DoudouSpace.s8,
                DoudouSpace.s4,
                DoudouSpace.s8,
              ),
              child: Text(
                _clusterLabel(context, group.$2),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ).copyWith(color: colors.textSecondary),
              ),
            ),
            for (final id in group.$3) _buildNavTile(context, id),
          ],
        ],
      ),
    );
  }

  Widget _buildNavTile(BuildContext context, _SettingsSectionId id) {
    final meta = __SettingsViewStateBase._sectionMeta.firstWhere((e) => e.$1 == id);
    final label = _sectionTitle(context, id);
    final tile = _SettingsNavTile(
      icon: meta.$2,
      label: label,
      selected: _selected == id,
      onTap: () => setState(() => _selected = id),
    );

    if (_isTv(context)) {
      return TvFocusHighlight(
        borderRadius: 8,
        onSelect: () => setState(() => _selected = id),
        child: tile,
      );
    }
    return tile;
  }

  Widget _buildMobileSectionRow(
    BuildContext context,
    SettingsScreenController settings,
    LibrarySyncService sync,
    _SettingsSectionId id,
  ) {
    final meta = __SettingsViewStateBase._sectionMeta.firstWhere((e) => e.$1 == id);
    final theme = Theme.of(context);
    final colors = context.doudouColors;

    final tile = ListTile(
      dense: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          meta.$2,
          size: 18,
          color: colors.textSecondary,
        ),
      ),
      title: Text(
        _sectionTitle(context, id),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        _sectionSubtitle(context, id),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.textTertiary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colors.textDisabled,
      ),
      onTap: () => _openSectionSubPage(context, settings, sync, id),
    );

    if (_isTv(context)) {
      return TvFocusHighlight(
        borderRadius: 10,
        onSelect: () => _openSectionSubPage(context, settings, sync, id),
        child: tile,
      );
    }
    return tile;
  }

  void _openSectionSubPage(
    BuildContext context,
    SettingsScreenController settings,
    LibrarySyncService sync,
    _SettingsSectionId id,
  ) {
    final meta = __SettingsViewStateBase._sectionMeta.firstWhere((e) => e.$1 == id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => _SettingsSubPage(
          icon: meta.$2,
          title: _sectionTitle(ctx, id),
          childrenBuilder: (ctx) =>
              _buildSectionChildren(ctx, settings, sync, id),
        ),
      ),
    );
  }

}
