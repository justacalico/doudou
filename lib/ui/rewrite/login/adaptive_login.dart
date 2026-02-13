import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/l10n.dart';
import '../../../providers/app_state.dart';

class AdaptiveLoginView extends StatefulWidget {
  const AdaptiveLoginView({super.key});

  @override
  State<AdaptiveLoginView> createState() => _AdaptiveLoginViewState();
}

class _AdaptiveLoginViewState extends State<AdaptiveLoginView> {
  final TextEditingController _serverController = TextEditingController();
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _credentialController = TextEditingController();

  String _serverType = 'jellyfin';
  bool _isSubmitting = false;

  bool get _isCupertino =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void dispose() {
    _serverController.dispose();
    _identifierController.dispose();
    _credentialController.dispose();
    super.dispose();
  }

  Future<void> _signIn(AppState appState) async {
    if (_isSubmitting || appState.isLoading) {
      return;
    }

    final serverUrl = _serverController.text.trim();
    final identifier = _identifierController.text.trim();
    final credential = _credentialController.text.trim();

    if (_serverType != 'local') {
      if (serverUrl.isEmpty || identifier.isEmpty || credential.isEmpty) {
        appState.setErrorMessage('Please fill in all required fields.');
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      bool success = false;

      if (_serverType == 'local') {
        success = await appState.loginWithLocalMusic();
      } else {
        success = await appState.loginWithServerType(
          _serverType,
          serverUrl,
          identifier,
          credential,
        );
      }

      if (!success && mounted && !_isCupertino) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  appState.errorMessage ?? 'Authentication failed.',
                ),
              ),
            );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _enterOfflineMode(AppState appState) async {
    if (_isSubmitting || appState.isLoading) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await appState.enterOfflineModeWithoutLogin();
      if (!success) {
        appState.setErrorMessage(
          'No downloaded content available for offline mode.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _serverPlaceholder(BuildContext context) {
    final l10n = context.l10n;
    switch (_serverType) {
      case 'plex':
        return l10n.plexPlaceholder;
      case 'subsonic':
        return l10n.subsonicPlaceholder;
      default:
        return l10n.jellyfinPlaceholder;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final l10n = context.l10n;

        final body = SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.appName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _isCupertino ? 36 : 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.appTagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _isCupertino ? 15 : 14,
                        color: _isCupertino
                            ? CupertinoColors.secondaryLabel.resolveFrom(
                                context,
                              )
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _ServerTypeSelector(
                      isCupertino: _isCupertino,
                      serverType: _serverType,
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _serverType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_serverType != 'local') ...[
                      _AdaptiveTextField(
                        isCupertino: _isCupertino,
                        controller: _serverController,
                        label: l10n.serverUrl,
                        placeholder: _serverPlaceholder(context),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 12),
                      _AdaptiveTextField(
                        isCupertino: _isCupertino,
                        controller: _identifierController,
                        label: l10n.username,
                      ),
                      const SizedBox(height: 12),
                      _AdaptiveTextField(
                        isCupertino: _isCupertino,
                        controller: _credentialController,
                        label: _serverType == 'plex'
                            ? l10n.plexToken
                            : l10n.password,
                        obscureText: true,
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Use your local indexed music library.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _isCupertino
                                ? CupertinoColors.secondaryLabel.resolveFrom(
                                    context,
                                  )
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    _AdaptivePrimaryButton(
                      isCupertino: _isCupertino,
                      isLoading: appState.isLoading || _isSubmitting,
                      onPressed: () => _signIn(appState),
                      label: l10n.signIn,
                    ),
                    const SizedBox(height: 12),
                    _AdaptiveSecondaryButton(
                      isCupertino: _isCupertino,
                      isLoading: appState.isLoading || _isSubmitting,
                      onPressed: () => _enterOfflineMode(appState),
                      label: l10n.offlineMode,
                    ),
                    if (appState.errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        appState.errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isCupertino
                              ? CupertinoColors.systemRed.resolveFrom(context)
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );

        if (_isCupertino) {
          return CupertinoPageScaffold(child: body);
        }

        return Scaffold(body: body);
      },
    );
  }
}

class _ServerTypeSelector extends StatelessWidget {
  const _ServerTypeSelector({
    required this.isCupertino,
    required this.serverType,
    required this.onChanged,
  });

  final bool isCupertino;
  final String serverType;
  final ValueChanged<String?> onChanged;

  static const Map<String, String> _labels = {
    'jellyfin': 'Jellyfin',
    'plex': 'Plex',
    'subsonic': 'Subsonic',
    'local': 'Local',
  };

  @override
  Widget build(BuildContext context) {
    if (isCupertino) {
      return CupertinoSlidingSegmentedControl<String>(
        groupValue: serverType,
        children: {
          for (final entry in _labels.entries)
            entry.key: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Text(entry.value),
            ),
        },
        onValueChanged: onChanged,
      );
    }

    return DropdownButtonFormField<String>(
      value: serverType,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: _labels.entries
          .map(
            (entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _AdaptiveTextField extends StatelessWidget {
  const _AdaptiveTextField({
    required this.isCupertino,
    required this.controller,
    required this.label,
    this.placeholder,
    this.obscureText = false,
    this.keyboardType,
  });

  final bool isCupertino;
  final TextEditingController controller;
  final String label;
  final String? placeholder;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    if (isCupertino) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
          CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            obscureText: obscureText,
            keyboardType: keyboardType,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ],
      );
    }

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: placeholder,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _AdaptivePrimaryButton extends StatelessWidget {
  const _AdaptivePrimaryButton({
    required this.isCupertino,
    required this.isLoading,
    required this.onPressed,
    required this.label,
  });

  final bool isCupertino;
  final bool isLoading;
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (isCupertino) {
      return CupertinoButton.filled(
        onPressed: isLoading ? null : onPressed,
        child: isLoading ? const CupertinoActivityIndicator() : Text(label),
      );
    }

    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

class _AdaptiveSecondaryButton extends StatelessWidget {
  const _AdaptiveSecondaryButton({
    required this.isCupertino,
    required this.isLoading,
    required this.onPressed,
    required this.label,
  });

  final bool isCupertino;
  final bool isLoading;
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (isCupertino) {
      return CupertinoButton(
        onPressed: isLoading ? null : onPressed,
        child: Text(label),
      );
    }

    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      child: Text(label),
    );
  }
}
