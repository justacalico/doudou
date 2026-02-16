import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/services/base_service.dart';

import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/templates/page_template.dart';

/// Settings page built from PageTemplate; content uses simple list sections.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _category = 'general';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final isLocal =
            appState.mediaServiceManager.currentServerType == ServerType.local;
        return PageTemplate(
          title: l10n.settings,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Sidebar(
                selected: _category,
                onSelect: (v) => setState(() => _category = v),
                l10n: l10n,
                isLocalMusic: isLocal,
              ),
              const SizedBox(width: DesktopTheme.spacingLg),
              Expanded(
                child: SingleChildScrollView(
                  child: _category == 'general'
                      ? _GeneralSection(l10n: l10n, appState: appState)
                      : _category == 'about'
                          ? _AboutSection(l10n: l10n)
                          : Padding(
                              padding: const EdgeInsets.all(
                                  DesktopTheme.spacingLg),
                              child: Text(
                                l10n.settings,
                                style: TextStyle(
                                    color: DesktopTheme.textSecondary),
                              ),
                            ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final AppLocalizations l10n;
  final bool isLocalMusic;

  const _Sidebar({
    required this.selected,
    required this.onSelect,
    required this.l10n,
    required this.isLocalMusic,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      'general',
      'audio',
      'appearance',
      if (!isLocalMusic) 'server',
      'about',
    ];
    final labels = {
      'general': l10n.generalSettings.split(' ').first,
      'audio': l10n.audioSettings.split(' ').first,
      'appearance': l10n.appearanceSettings.split(' ').first,
      'server': l10n.server,
      'about': l10n.about,
    };
    return Container(
      width: 200,
      padding: const EdgeInsets.only(right: DesktopTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: categories
            .map(
              (id) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: selected == id
                      ? DesktopTheme.glassOverlay
                      : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(DesktopTheme.radiusSm),
                  child: InkWell(
                    onTap: () => onSelect(id),
                    borderRadius:
                        BorderRadius.circular(DesktopTheme.radiusSm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesktopTheme.spacingMd,
                        vertical: DesktopTheme.spacingSm + 4,
                      ),
                      child: Text(
                        labels[id] ?? id,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected == id
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: selected == id
                              ? Theme.of(context).colorScheme.primary
                              : DesktopTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _GeneralSection extends StatelessWidget {
  final AppLocalizations l10n;
  final AppState appState;

  const _GeneralSection({required this.l10n, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DesktopTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.generalSettings,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: DesktopTheme.textPrimary,
            ),
          ),
          const SizedBox(height: DesktopTheme.spacingMd),
          Text(
            l10n.language,
            style: TextStyle(
              fontSize: 14,
              color: DesktopTheme.textSecondary,
            ),
          ),
          const SizedBox(height: DesktopTheme.spacingXs),
          Text(
            appState.locale?.toString() ?? 'System',
            style: TextStyle(
              fontSize: 14,
              color: DesktopTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final AppLocalizations l10n;

  const _AboutSection({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DesktopTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.about,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: DesktopTheme.textPrimary,
            ),
          ),
          const SizedBox(height: DesktopTheme.spacingMd),
          Text(
            'Doudou',
            style: TextStyle(
              fontSize: 14,
              color: DesktopTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
