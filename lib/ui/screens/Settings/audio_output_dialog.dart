import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/models/audio_output_device.dart';
import '/services/audio_output_service.dart';
import '/ui/design/doudou_tokens.dart';
import '/ui/widgets/common_dialog_widget.dart';
import '/utils/app_l10n.dart';

IconData audioOutputIcon(AudioOutputKind kind) {
  return switch (kind) {
    AudioOutputKind.speaker => Icons.speaker,
    AudioOutputKind.earpiece => Icons.phone_iphone,
    AudioOutputKind.wired => Icons.headset,
    AudioOutputKind.bluetooth => Icons.bluetooth,
    AudioOutputKind.airplay => Icons.airplay,
    AudioOutputKind.usb => Icons.usb,
    AudioOutputKind.hdmi => Icons.tv,
    AudioOutputKind.cast => Icons.cast,
    AudioOutputKind.other => Icons.devices,
  };
}

/// Route picker for the playback output. Android lists real selectable
/// routes; on iOS only the speaker/receiver override is selectable and
/// everything else goes through the system picker.
class AudioOutputDialog extends StatefulWidget {
  const AudioOutputDialog({super.key, this.service});

  final AudioOutputService? service;

  @override
  State<AudioOutputDialog> createState() => _AudioOutputDialogState();
}

class _AudioOutputDialogState extends State<AudioOutputDialog> {
  late final AudioOutputService _service =
      widget.service ?? AudioOutputService();
  List<AudioOutputDevice>? _devices;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final devices = await _service.devices();
    if (mounted) setState(() => _devices = devices);
  }

  Future<void> _select(AudioOutputDevice device) async {
    if (!device.selectable) {
      await _service.showSystemPicker();
      return;
    }
    if (await _service.select(device)) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devices = _devices;

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
                  context.l10n.audioOutput,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Flexible(
                child: devices == null
                    ? const Padding(
                        padding: EdgeInsets.all(DoudouSpace.s24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : devices.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(DoudouSpace.s24),
                            child:
                                Text(context.l10n.audioOutputNoDevices),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                for (final device in devices)
                                  ListTile(
                                    leading:
                                        Icon(audioOutputIcon(device.kind)),
                                    title: Text(device.name),
                                    trailing: device.selected
                                        ? Icon(
                                            Icons.check,
                                            color: theme.colorScheme.primary,
                                          )
                                        : null,
                                    onTap: () => _select(device),
                                  ),
                              ],
                            ),
                          ),
              ),
              if (GetPlatform.isIOS)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      right: DoudouSpace.s12,
                      top: DoudouSpace.s8,
                    ),
                    child: TextButton(
                      onPressed: () => _service.showSystemPicker(),
                      child: Text(context.l10n.audioOutputPickDevice),
                    ),
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
                    child: Text(context.l10n.done),
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
