import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '/utils/app_l10n.dart';
import '/utils/helper.dart';
import '/models/server.dart';
import '/services/discord_rpc_service.dart';
import '/services/library_sync_service.dart';
import '/services/music_service.dart';
import '/services/tv_service.dart';
import '/ui/constants/layout.dart';
import '/ui/design/doudou_colors.dart';
import '/ui/design/doudou_layout.dart';
import '/ui/design/doudou_tokens.dart';
import '/ui/player/player_controller.dart';
import '/ui/screens/Library/library_controller.dart';
import '/ui/screens/Settings/add_server_dialog.dart';
import '/ui/screens/Settings/settings_dialogs.dart';
import '/ui/screens/Settings/settings_screen_controller.dart';
import '/ui/utils/theme_controller.dart';
import '/ui/widgets/backup_dialog.dart';
import '/ui/widgets/cust_switch.dart';
import '/ui/widgets/export_file_dialog.dart';
import '/ui/widgets/link_piped.dart';
import '/ui/widgets/new_version_dialog.dart';
import '/ui/widgets/restore_dialog.dart';
import '/ui/widgets/snackbar.dart';
import '/ui/widgets/tv_focus_highlight.dart';

part 'settings_screen_settingsviewstatebase.dart';
part 'settings_screen_settingsviewbuild.dart';
part 'settings_screen_settingsviewcontent.dart';
part 'settings_screen_settingsviewdownload.dart';
part 'settings_screen_settingsviewinfo.dart';
part 'settings_screen_settingsviewlayout.dart';
part 'settings_screen_settingsviewmisc.dart';
part 'settings_screen_settingsviewnav.dart';
part 'settings_screen_settingsviewpersonalisation.dart';
part 'settings_screen_settingsviewplayback.dart';
part 'settings_screen_settingsviewsection.dart';
part 'settings_screen_settingsviewserver.dart';

class SettingsScreen extends GetView<SettingsScreenController> {
  const SettingsScreen({super.key, this.isBottomNavActive = false});
  final bool isBottomNavActive;

  @override
  Widget build(BuildContext context) {
    return _SettingsView(isBottomNavActive: isBottomNavActive);
  }
}

enum _SettingsSectionId {
  personalisation,
  content,
  playback,
  servers,
  download,
  backup,
  misc,
  info,
}

class _SettingsView extends StatefulWidget {
  const _SettingsView({required this.isBottomNavActive});
  final bool isBottomNavActive;

  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView>
    with __SettingsViewStateBase, _SettingsViewBuildMixin, _SettingsViewContentMixin, _SettingsViewDownloadMixin, _SettingsViewInfoMixin, _SettingsViewLayoutMixin, _SettingsViewMiscMixin, _SettingsViewNavMixin, _SettingsViewPersonalisationMixin, _SettingsViewPlaybackMixin, _SettingsViewSectionMixin, _SettingsViewServerMixin {
}


class _SettingsListTile extends StatelessWidget {
  const _SettingsListTile({
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  final Widget? leading;
  final String title;
  final Object? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.doudouColors;

    Widget? leadingWidget;
    if (leading is Widget) {
      leadingWidget = leading as Widget;
    }

    Widget? subtitleWidget;
    if (subtitle is Widget) {
      subtitleWidget = subtitle as Widget;
    } else if (subtitle is String) {
      subtitleWidget = Text(
        subtitle as String,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.textTertiary,
        ),
      );
    } else if (subtitle is TextSpan) {
      subtitleWidget = RichText(
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        text: subtitle as TextSpan,
      );
    }

    Widget tile = ListTile(
      enabled: enabled,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: DoudouSpace.s12,
        vertical: DoudouSpace.s2,
      ),
      leading: leadingWidget,
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: subtitleWidget,
      trailing: trailing,
      onTap: onTap,
    );

    if (onTap != null && _isTv(context)) {
      tile = TvFocusHighlight(
        borderRadius: 10,
        onSelect: onTap,
        child: tile,
      );
    }

    return tile;
  }

  bool _isTv(BuildContext context) {
    if (!Get.isRegistered<TvService>()) return false;
    return Get.find<TvService>().isTV.value;
  }
}

class _SettingsDropdown<T> extends StatelessWidget {
  const _SettingsDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> items;
  final void Function(T) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DropdownButton<T>(
      isDense: true,
      value: value,
      underline: const SizedBox.shrink(),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
      style: theme.textTheme.bodyMedium,
      dropdownColor: theme.cardColor,
      borderRadius: DoudouRadii.r12,
      items: items
          .map((e) => DropdownMenuItem<T>(
                value: e.$1,
                child: Text(e.$2),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    this.icon,
    this.title,
    this.borderRadius = DoudouRadii.r16,
    this.margin = const EdgeInsets.symmetric(horizontal: DoudouSpace.s4),
    this.color,
    required this.children,
  });

  final IconData? icon;
  final String? title;
  final BorderRadius borderRadius;
  final EdgeInsets margin;
  final Color? color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.doudouColors;

    return Card(
      color: color ?? theme.cardColor,
      elevation: 0,
      margin: margin,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DoudouSpace.s16,
                DoudouSpace.s16,
                DoudouSpace.s16,
                DoudouSpace.s8,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: colors.textSecondary),
                    const SizedBox(width: DoudouSpace.s8),
                  ],
                  Text(
                    title!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          if (title != null) const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsNavTile extends StatefulWidget {
  const _SettingsNavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SettingsNavTile> createState() => _SettingsNavTileState();
}

class _SettingsNavTileState extends State<_SettingsNavTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.doudouColors;
    final iconColor = widget.selected
        ? c.textPrimary
        : (_hover ? c.textPrimary : c.textSecondary);
    final bgColor = widget.selected
        ? c.surfaceSelected
        : (_hover ? c.stateHover : Colors.transparent);

    return Semantics(
      button: true,
      selected: widget.selected,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (v) => setState(() => _hover = v),
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: bgColor,
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: iconColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        widget.selected ? FontWeight.w600 : FontWeight.w500,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSubPage extends StatelessWidget {
  const _SettingsSubPage({
    required this.icon,
    required this.title,
    required this.childrenBuilder,
  });

  final IconData icon;
  final String title;
  final List<Widget> Function(BuildContext) childrenBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DoudouSpace.s16),
          child: _SettingsCard(
            icon: icon,
            title: title,
            children: childrenBuilder(context),
          ),
        ),
      ),
    );
  }
}
