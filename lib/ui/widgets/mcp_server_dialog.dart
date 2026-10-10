import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '/services/mcp_server_service.dart';
import '/ui/design/doudou_tokens.dart';
import '/ui/widgets/common_dialog_widget.dart';
import '/ui/widgets/custom_switch.dart';
import '/ui/widgets/snackbar.dart';
import '/utils/app_l10n.dart';

/// Configures the embedded MCP server: enable switch, port and the loopback
/// address local MCP clients connect to.
class McpServerDialog extends StatefulWidget {
  const McpServerDialog({super.key});

  @override
  State<McpServerDialog> createState() => _McpServerDialogState();
}

class _McpServerDialogState extends State<McpServerDialog> {
  late final TextEditingController _portController;
  final _portError = RxnString();

  McpServerService get _mcp => Get.find<McpServerService>();

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController(text: '${_mcp.port.value}');
    _portController.addListener(() => _portError.value = null);
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  Future<void> _applyPort() async {
    final value = int.tryParse(_portController.text.trim());
    final invalidMessage = context.l10n.mcpServerInvalidPort;
    if (value != null && await _mcp.setPort(value)) return;
    _portError.value = invalidMessage;
  }

  Future<void> _exportBundle() async {
    final l10n = context.l10n;
    var path = await FilePicker.platform.saveFile(
      dialogTitle: l10n.mcpServerExport,
      fileName: 'doudou.mcpb',
      type: FileType.custom,
      allowedExtensions: const ['mcpb'],
    );
    if (path == null || path.isEmpty) return;
    if (!path.endsWith('.mcpb')) path = '$path.mcpb';
    var saved = true;
    try {
      await File(path).writeAsBytes(_mcp.buildBundle());
    } on FileSystemException {
      saved = false;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(snackbar(
        context, saved ? l10n.mcpServerExported : l10n.mcpServerExportFailed));
  }

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
              l10n.mcpServer,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: DoudouSpace.s8),
            Text(
              l10n.mcpServerDes,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: DoudouSpace.s12),
            Obx(() => Row(
                  children: [
                    Expanded(
                      child: Text(l10n.enabled,
                          style: theme.textTheme.bodyLarge),
                    ),
                    CustSwitch(
                      value: _mcp.enabled.value,
                      onChanged: (v) => _mcp.setEnabled(v),
                    ),
                  ],
                )),
            const SizedBox(height: DoudouSpace.s8),
            Obx(() => TextFormField(
                  controller: _portController,
                  enabled: _mcp.enabled.value,
                  decoration: InputDecoration(
                    labelText: l10n.mcpServerPort,
                    errorText: _portError.value,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.done,
                  onEditingComplete: _applyPort,
                )),
            const SizedBox(height: DoudouSpace.s12),
            Obx(() {
              if (!_mcp.running.value) {
                final error = _mcp.lastError.value;
                if (error == null || !_mcp.enabled.value) {
                  return const SizedBox.shrink();
                }
                return Text(
                  error,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.error),
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      _mcp.listenUrl,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    tooltip: l10n.mcpServerCopyAddress,
                    onPressed: () => Clipboard.setData(
                        ClipboardData(text: _mcp.listenUrl)),
                  ),
                ],
              );
            }),
            const SizedBox(height: DoudouSpace.s12),
            Text(
              l10n.mcpServerExportDes,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: DoudouSpace.s4),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: Text(l10n.mcpServerExport),
                onPressed: _exportBundle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
