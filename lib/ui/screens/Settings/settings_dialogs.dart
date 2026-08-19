import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/utils/app_l10n.dart';
import '/models/server.dart';
import '/services/tv_service.dart';
import '/ui/design/doudou_tokens.dart';
import '/ui/screens/Settings/settings_screen_controller.dart';
import '/ui/utils/theme_controller.dart';
import '/ui/widgets/common_dialog_widget.dart';
import '/ui/widgets/tv_focus_highlight.dart';

IconData serverIcon(ServerType type) {
  const icons = <ServerType, IconData>{
    ServerType.youtubeMusic: Icons.play_circle_outline,
    ServerType.subsonic: Icons.waves,
    ServerType.jellyfin: Icons.tv,
    ServerType.plex: Icons.cloud,
  };
  return icons[type] ?? Icons.storage_outlined;
}

String serverTypeLabel(BuildContext context, ServerType type) {
  final l10n = context.l10n;
  return switch (type) {
    ServerType.youtubeMusic => l10n.youtubeMusic,
    ServerType.subsonic => l10n.subsonic,
    ServerType.jellyfin => l10n.jellyfin,
    ServerType.plex => l10n.plex,
  };
}

bool ytmProviderUnlocked = false;

class ThemeSelectorDialog extends StatelessWidget {
  const ThemeSelectorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Get.find<SettingsScreenController>();

    final options = [
      (ThemeType.dynamic, context.l10n.dynamicTheme),
      (ThemeType.system, context.l10n.systemDefault),
      (ThemeType.dark, context.l10n.dark),
      (ThemeType.oled, context.l10n.oled),
      (ThemeType.light, context.l10n.light),
    ];

    return CommonDialog(
      child: Material(
        color:
            theme.dialogTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        borderRadius: DoudouRadii.r16,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DoudouSpace.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DoudouSpace.s24,
                  DoudouSpace.s8,
                  DoudouSpace.s24,
                  DoudouSpace.s4,
                ),
                child: Text(
                  context.l10n.themeMode,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Obx(() {
                    return RadioGroup<ThemeType>(
                      groupValue: settings.themeModetype.value,
                      onChanged: (v) {
                        if (v != null) settings.onThemeChange(v);
                      },
                      child: Column(
                        children: options.map((o) {
                          return RadioListTile<ThemeType>(
                            title: Text(o.$2),
                            value: o.$1,
                          );
                        }).toList(),
                      ),
                    );
                  }),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(
                    right: DoudouSpace.s12,
                    top: DoudouSpace.s8,
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.cancel),
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

class DiscoverContentSelectorDialog extends StatelessWidget {
  const DiscoverContentSelectorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Get.find<SettingsScreenController>();

    final options = [
      ('QP', context.l10n.quickpicks),
      ('TMV', context.l10n.topmusicvideos),
      ('TR', context.l10n.trending),
      ('BOLI', context.l10n.basedOnLast),
    ];

    return CommonDialog(
      child: Material(
        color:
            theme.dialogTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        borderRadius: DoudouRadii.r16,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DoudouSpace.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DoudouSpace.s24,
                  DoudouSpace.s8,
                  DoudouSpace.s24,
                  DoudouSpace.s4,
                ),
                child: Text(
                  context.l10n.setDiscoverContent,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Obx(() {
                    return RadioGroup<String>(
                      groupValue: settings.discoverContentType.value,
                      onChanged: (v) {
                        if (v != null) {
                          settings.onContentChange(v);
                          Navigator.of(context).pop();
                        }
                      },
                      child: Column(
                        children: options.map((o) {
                          return RadioListTile<String>(
                            title: Text(o.$2),
                            value: o.$1,
                          );
                        }).toList(),
                      ),
                    );
                  }),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(
                    right: DoudouSpace.s12,
                    top: DoudouSpace.s8,
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.cancel),
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

class PlaybackDiagnosticsPage extends StatefulWidget {
  const PlaybackDiagnosticsPage({super.key});

  @override
  State<PlaybackDiagnosticsPage> createState() =>
      _PlaybackDiagnosticsPageState();
}

class _PlaybackDiagnosticsPageState extends State<PlaybackDiagnosticsPage> {
  static const int _maxShownEvents = 400;
  bool _prettyFormat = false;

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsScreenController>();
    final theme = Theme.of(context);

    final text = settings.getPlaybackDiagnosticsText(
      limit: _maxShownEvents,
      pretty: _prettyFormat,
    );
    final count = settings.playbackDiagnosticsCount;
    final isEmpty = text.trim().isEmpty;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.l10n.playbackDiagnostics),
        actions: [
          IconButton(
            tooltip: context.l10n.toggleFormat,
            onPressed: () => setState(() => _prettyFormat = !_prettyFormat),
            icon: Icon(_prettyFormat ? Icons.code : Icons.notes),
          ),
          IconButton(
            tooltip: context.l10n.copyDiagnostics,
            onPressed: () async {
              final copied = await settings.copyPlaybackDiagnosticsToClipboard(
                limit: _maxShownEvents,
                pretty: _prettyFormat,
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(copied
                      ? 'Diagnostics copied to clipboard'
                      : 'No diagnostics to copy'),
                ),
              );
            },
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(DoudouSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Events: $count (showing up to $_maxShownEvents)',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: DoudouSpace.s12),
            Expanded(
              child: Card(
                color: theme.cardColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: DoudouRadii.r12,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(DoudouSpace.s12),
                  child: isEmpty
                      ? const Center(
                          child: Text(
                            'No diagnostics yet.\nEnable diagnostics and reproduce the issue.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : SingleChildScrollView(
                          child: SelectableText(
                            text,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddProviderDialog extends StatelessWidget {
  const AddProviderDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final types = ServerType.values.where((t) {
      if (t == ServerType.youtubeMusic &&
          kIsPlayStore &&
          !ytmProviderUnlocked) {
        return false;
      }
      return true;
    }).toList();

    final isTv =
        Get.isRegistered<TvService>() && Get.find<TvService>().isTV.value;

    if (isTv) {
      return _TvAddProviderDialog(types: types);
    }

    return CommonDialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DoudouSpace.s16,
          DoudouSpace.s20,
          DoudouSpace.s16,
          DoudouSpace.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.addServer,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: DoudouSpace.s12),
            for (int i = 0; i < types.length; i++) ...[
              ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                leading: Icon(serverIcon(types[i])),
                title: Text(serverTypeLabel(context, types[i])),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: () => Navigator.of(context).pop(types[i]),
              ),
              if (i < types.length - 1) const Divider(height: 1),
            ],
            const SizedBox(height: DoudouSpace.s8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.cancel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TvAddProviderDialog extends StatelessWidget {
  const _TvAddProviderDialog({required this.types});

  final List<ServerType> types;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
      child: FocusTraversalGroup(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.addServer,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: DoudouSpace.s32),
              for (int i = 0; i < types.length; i++) ...[
                TvFocusHighlight(
                  borderRadius: 12,
                  autofocus: i == 0,
                  debugLabel: 'ServerType_${types[i].name}',
                  onSelect: () => Navigator.of(context).pop(types[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 28,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(
                      children: [
                        Icon(serverIcon(types[i]), size: 32),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Text(
                            serverTypeLabel(context, types[i]),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 28),
                      ],
                    ),
                  ),
                ),
                if (i < types.length - 1)
                  const SizedBox(height: DoudouSpace.s12),
              ],
              const SizedBox(height: DoudouSpace.s32),
              Align(
                alignment: Alignment.centerLeft,
                child: TvFocusHighlight(
                  borderRadius: 8,
                  debugLabel: 'CancelProvider',
                  onSelect: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Text(
                      l10n.cancel,
                      style: theme.textTheme.titleMedium,
                    ),
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
