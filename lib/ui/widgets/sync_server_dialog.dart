import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/services/server_sync_service.dart';
import '/ui/design/doudou_tokens.dart';
import '/ui/widgets/common_dialog_widget.dart';
import '/utils/app_l10n.dart';

/// Connects the app to a doudou sync server: enter the server address and
/// password once and every device logged in shares the same library.
class SyncServerDialog extends StatefulWidget {
  const SyncServerDialog({super.key});

  @override
  State<SyncServerDialog> createState() => _SyncServerDialogState();
}

class _SyncServerDialogState extends State<SyncServerDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _passwordController;
  final _connecting = false.obs;
  final _error = RxnString();

  ServerSyncService get _sync => Get.find<ServerSyncService>();

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _sync.serverUrl.value);
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    _connecting.value = true;
    _error.value = null;
    final error = await _sync.connect(
      url: _urlController.text,
      password: _passwordController.text,
    );
    _connecting.value = false;
    _error.value = error;
  }

  /// Bare addresses get an http:// prefix in DoudouSyncClient.normalizeUrl,
  /// so anything that does not explicitly start with https ends up cleartext.
  bool get _showsHttpWarning =>
      _urlController.text.trim().isNotEmpty &&
      !_urlController.text.trim().startsWith('https://');

  String _formatTime(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:'
      '${time.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
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
              l10n.deviceSync,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: DoudouSpace.s8),
            Text(
              l10n.deviceSyncDes,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: DoudouSpace.s16),
            Obx(() {
              if (!_sync.enabled.value) return const SizedBox.shrink();
              final lastSync = _sync.lastSyncAt.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: DoudouSpace.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _sync.connected.value
                          ? l10n.connectionSuccess
                          : (_sync.lastError.value.isNotEmpty
                              ? '${l10n.connectionFailed}: ${_sync.lastError.value}'
                              : l10n.syncing),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _sync.connected.value
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                      ),
                    ),
                    if (lastSync != null)
                      Text(
                        l10n.lastSyncTime(_formatTime(lastSync)),
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              );
            }),
            Obx(() {
              if (_sync.enabled.value && !_sync.authExpired.value) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: l10n.serverUrl,
                      hintText: '192.168.1.10:8461',
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_showsHttpWarning)
                    Padding(
                      padding: const EdgeInsets.only(top: DoudouSpace.s8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 18, color: theme.colorScheme.error),
                          const SizedBox(width: DoudouSpace.s8),
                          Expanded(
                            child: Text(
                              l10n.httpInsecureWarning,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: DoudouSpace.s12),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(labelText: l10n.password),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _connect(),
                  ),
                ],
              );
            }),
            Obx(() {
              final error = _error.value;
              if (error == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: DoudouSpace.s12),
                child: Text(
                  error,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              );
            }),
            const SizedBox(height: DoudouSpace.s24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.close),
                ),
                const SizedBox(width: DoudouSpace.s8),
                Obx(() {
                  if (_sync.enabled.value) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: _sync.disconnect,
                          child: Text(l10n.disconnect),
                        ),
                        const SizedBox(width: DoudouSpace.s8),
                        FilledButton(
                          onPressed: _sync.isSyncing.value
                              ? null
                              : _sync.syncNow,
                          child: Text(_sync.isSyncing.value
                              ? l10n.syncing
                              : l10n.sync),
                        ),
                      ],
                    );
                  }
                  return FilledButton(
                    onPressed: _connecting.value ? null : _connect,
                    child: Text(_connecting.value
                        ? l10n.syncing
                        : l10n.connect),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
