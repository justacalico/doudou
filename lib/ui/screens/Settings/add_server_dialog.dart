import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/utils/app_l10n.dart';
import '/models/server.dart';
import '/services/tv_service.dart';
import '/ui/design/doudou_tokens.dart';
import '/ui/screens/Settings/settings_dialogs.dart';
import '/ui/screens/Settings/settings_screen_controller.dart';
import '/ui/widgets/common_dialog_widget.dart';
import '/ui/widgets/tv_focus_highlight.dart';

class AddServerDialog extends StatefulWidget {
  const AddServerDialog({
    super.key,
    required this.serverType,
    this.existing,
  });

  final ServerType serverType;
  final SettingsServer? existing;

  @override
  State<AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<AddServerDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late String _protocol;

  @override
  void initState() {
    super.initState();
    var existingUrl = widget.existing?.serverUrl ?? '';
    if (existingUrl.startsWith('http://')) {
      _protocol = 'http';
      existingUrl = existingUrl.substring(7);
    } else if (existingUrl.startsWith('https://')) {
      _protocol = 'https';
      existingUrl = existingUrl.substring(8);
    } else {
      _protocol = 'https';
    }
    _urlController = TextEditingController(text: existingUrl);
    _usernameController =
        TextEditingController(text: widget.existing?.username ?? '');
    _passwordController =
        TextEditingController(text: widget.existing?.password ?? '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _buildServerUrl() {
    var url = _urlController.text.trim();
    url = url.replaceFirst(RegExp(r'^https?://'), '');
    if (url.isEmpty) return '';
    return '$_protocol://$url';
  }

  bool get _needsCredentials =>
      widget.serverType == ServerType.subsonic ||
      widget.serverType == ServerType.jellyfin ||
      widget.serverType == ServerType.plex;

  String _title(BuildContext context) {
    final l10n = context.l10n;
    if (widget.existing != null) return l10n.editServer;
    return '${l10n.addServer} - ${serverTypeLabel(context, widget.serverType)}';
  }

  @override
  Widget build(BuildContext context) {
    if (Get.isRegistered<TvService>() && Get.find<TvService>().isTV.value) {
      return _TvAddServerWizard(
        serverType: widget.serverType,
        existing: widget.existing,
        urlController: _urlController,
        usernameController: _usernameController,
        passwordController: _passwordController,
        protocol: _protocol,
        onProtocolChanged: (v) => setState(() => _protocol = v),
        buildServerUrl: _buildServerUrl,
        needsCredentials: _needsCredentials,
        title: _title(context),
      );
    }

    final controller = Get.find<SettingsScreenController>();
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return CommonDialog(
      child: Padding(
        padding: const EdgeInsets.all(DoudouSpace.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _title(context),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_needsCredentials) ...[
              const SizedBox(height: DoudouSpace.s16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 110,
                    child: DropdownButtonFormField<String>(
                      initialValue: _protocol,
                      decoration: InputDecoration(
                        labelText: l10n.protocol,
                        filled: true,
                        fillColor: theme.inputDecorationTheme.fillColor,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'https', child: Text('HTTPS')),
                        DropdownMenuItem(value: 'http', child: Text('HTTP')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _protocol = v);
                      },
                    ),
                  ),
                  const SizedBox(width: DoudouSpace.s12),
                  Expanded(
                    child: TextFormField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        labelText: l10n.serverUrl,
                        hintText: 'example.com',
                      ),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              if (widget.serverType != ServerType.plex) ...[
                const SizedBox(height: DoudouSpace.s12),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(labelText: l10n.username),
                  textInputAction: TextInputAction.next,
                ),
              ],
              const SizedBox(height: DoudouSpace.s12),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: widget.serverType == ServerType.plex
                      ? l10n.plexToken
                      : l10n.password,
                ),
                obscureText: true,
              ),
            ] else ...[
              const SizedBox(height: DoudouSpace.s12),
              Text(
                l10n.youtubeMusicNoLogin,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: DoudouSpace.s24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: DoudouSpace.s8),
                FilledButton(
                  onPressed: () {
                    if (_needsCredentials) {
                      final serverUrl = _buildServerUrl();
                      if (serverUrl.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.serverUrlRequired)),
                        );
                        return;
                      }
                      if (widget.existing != null) {
                        controller.updateServer(
                          widget.existing!.id,
                          serverUrl: serverUrl,
                          username: _usernameController.text,
                          password: _passwordController.text,
                        );
                      } else {
                        controller.addServerWithCredentials(
                          widget.serverType,
                          serverUrl: serverUrl,
                          username: _usernameController.text,
                          password: _passwordController.text,
                        );
                      }
                    } else {
                      if (widget.existing != null) {
                        controller.updateServer(widget.existing!.id);
                      } else {
                        controller.addServerWithCredentials(widget.serverType);
                      }
                    }
                    Navigator.of(context).pop();
                  },
                  child: Text(widget.existing != null ? l10n.save : l10n.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TvAddServerWizard extends StatefulWidget {
  const _TvAddServerWizard({
    required this.serverType,
    this.existing,
    required this.urlController,
    required this.usernameController,
    required this.passwordController,
    required this.protocol,
    required this.onProtocolChanged,
    required this.buildServerUrl,
    required this.needsCredentials,
    required this.title,
  });

  final ServerType serverType;
  final SettingsServer? existing;
  final TextEditingController urlController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final String protocol;
  final ValueChanged<String> onProtocolChanged;
  final String Function() buildServerUrl;
  final bool needsCredentials;
  final String title;

  @override
  State<_TvAddServerWizard> createState() => _TvAddServerWizardState();
}

class _TvAddServerWizardState extends State<_TvAddServerWizard> {
  int _stage = 0;
  late int _maxStage;

  @override
  void initState() {
    super.initState();
    if (!widget.needsCredentials) {
      _maxStage = 0;
    } else if (widget.serverType == ServerType.plex) {
      _maxStage = 2;
    } else {
      _maxStage = 3;
    }
  }

  void _next() {
    if (_stage < _maxStage) {
      setState(() => _stage++);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_stage > 0) {
      setState(() => _stage--);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _submit() {
    final controller = Get.find<SettingsScreenController>();
    final l10n = context.l10n;

    if (widget.needsCredentials) {
      final serverUrl = widget.buildServerUrl();
      if (serverUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.serverUrlRequired)),
        );
        return;
      }
      if (widget.existing != null) {
        controller.updateServer(
          widget.existing!.id,
          serverUrl: serverUrl,
          username: widget.usernameController.text,
          password: widget.passwordController.text,
        );
      } else {
        controller.addServerWithCredentials(
          widget.serverType,
          serverUrl: serverUrl,
          username: widget.usernameController.text,
          password: widget.passwordController.text,
        );
      }
    } else {
      if (widget.existing != null) {
        controller.updateServer(widget.existing!.id);
      } else {
        controller.addServerWithCredentials(widget.serverType);
      }
    }
    Navigator.of(context).pop();
  }

  String _stageTitle() {
    final l10n = context.l10n;
    if (!widget.needsCredentials) return l10n.youtubeMusicNoLogin;
    switch (_stage) {
      case 0:
        return 'Protocol';
      case 1:
        return l10n.serverUrl;
      case 2:
        return widget.serverType == ServerType.plex
            ? l10n.plexToken
            : l10n.username;
      case 3:
        return l10n.password;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
      child: FocusTraversalGroup(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (widget.needsCredentials)
                    Text(
                      'Step ${_stage + 1} of ${_maxStage + 1}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: DoudouSpace.s8),
              Text(
                _stageTitle(),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: DoudouSpace.s32),
              Flexible(
                child: _buildStageContent(context),
              ),
              const SizedBox(height: DoudouSpace.s40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TvFocusHighlight(
                    borderRadius: 8,
                    debugLabel: 'BackBtn',
                    onSelect: _back,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Text(
                        _stage == 0 ? l10n.cancel : 'Back',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  TvFocusHighlight(
                    borderRadius: 8,
                    autofocus: _stage == 0,
                    debugLabel: 'NextBtn',
                    onSelect: _next,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _stage == _maxStage
                            ? (widget.existing != null ? l10n.save : l10n.add)
                            : 'Next',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageContent(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    if (!widget.needsCredentials) {
      return Text(
        l10n.youtubeMusicNoLogin,
        style: theme.textTheme.titleMedium,
      );
    }

    switch (_stage) {
      case 0:
        return Row(
          children: [
            Expanded(
              child: _TvProtocolChoice(
                label: 'HTTPS',
                selected: widget.protocol == 'https',
                onSelect: () {
                  widget.onProtocolChanged('https');
                  _next();
                },
              ),
            ),
            const SizedBox(width: DoudouSpace.s16),
            Expanded(
              child: _TvProtocolChoice(
                label: 'HTTP',
                selected: widget.protocol == 'http',
                onSelect: () {
                  widget.onProtocolChanged('http');
                  _next();
                },
              ),
            ),
          ],
        );

      case 1:
        return TextField(
          controller: widget.urlController,
          autofocus: true,
          style: const TextStyle(fontSize: 22),
          decoration: InputDecoration(
            labelText: l10n.serverUrl,
            labelStyle: const TextStyle(fontSize: 18),
            hintText: 'example.com',
            hintStyle: const TextStyle(fontSize: 18),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _next(),
        );

      case 2:
        if (widget.serverType == ServerType.plex) {
          return TextField(
            controller: widget.passwordController,
            autofocus: true,
            style: const TextStyle(fontSize: 22),
            decoration: InputDecoration(
              labelText: l10n.plexToken,
              labelStyle: const TextStyle(fontSize: 18),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _next(),
          );
        }
        return TextField(
          controller: widget.usernameController,
          autofocus: true,
          style: const TextStyle(fontSize: 22),
          decoration: InputDecoration(
            labelText: l10n.username,
            labelStyle: const TextStyle(fontSize: 18),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _next(),
        );

      case 3:
        return TextField(
          controller: widget.passwordController,
          autofocus: true,
          style: const TextStyle(fontSize: 22),
          decoration: InputDecoration(
            labelText: l10n.password,
            labelStyle: const TextStyle(fontSize: 18),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
          ),
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _next(),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

class _TvProtocolChoice extends StatelessWidget {
  const _TvProtocolChoice({
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TvFocusHighlight(
      borderRadius: 12,
      onSelect: onSelect,
      debugLabel: 'Protocol_$label',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? theme.colorScheme.outline : theme.dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
