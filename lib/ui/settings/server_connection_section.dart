import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/ui/theme.dart';
import 'package:doudou/services/players/jellyfin_service.dart';
import 'package:doudou/ui/settings/local_music_settings.dart';

enum JellyfinAuthMethod { account, apiKey, quickConnect }

/// Server connection form for use in Settings. Connect or switch server without leaving the app.
class ServerConnectionSection extends StatefulWidget {
  const ServerConnectionSection({super.key});

  @override
  State<ServerConnectionSection> createState() => _ServerConnectionSectionState();
}

class _ServerConnectionSectionState extends State<ServerConnectionSection> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _plexTokenController = TextEditingController();
  final _apiKeyController = TextEditingController();

  String _selectedServerType = 'jellyfin';
  bool _isPasswordVisible = false;
  JellyfinAuthMethod _jellyfinAuthMethod = JellyfinAuthMethod.account;

  bool _isQuickConnectActive = false;
  String? _quickConnectCode;
  String? _quickConnectSecret;
  Timer? _quickConnectPollTimer;

  @override
  void initState() {
    super.initState();
    _serverController.text = _getServerPlaceholder();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _plexTokenController.dispose();
    _apiKeyController.dispose();
    _quickConnectPollTimer?.cancel();
    super.dispose();
  }

  static const String _unsupportedUrlMessage =
      'This app supports Jellyfin, Plex, Subsonic, and Local music only. YouTube Music and similar services are not supported.';

  String? _validateServerUrl(String? value) {
    final url = (value ?? '').trim().toLowerCase();
    if (url.isEmpty) return 'Enter server URL';
    if (url.contains('youtube') || url.contains('music.youtube')) {
      return _unsupportedUrlMessage;
    }
    return null;
  }

  String _getServerPlaceholder() {
    switch (_selectedServerType) {
      case 'jellyfin':
        return 'http://your-jellyfin-server:8096';
      case 'plex':
        return 'http://your-plex-server:32400';
      case 'subsonic':
        return 'http://your-subsonic-server:4533';
      default:
        return 'http://your-server:port';
    }
  }

  Future<void> _connect() async {
    if (_selectedServerType == 'local') return;

    if (_selectedServerType == 'jellyfin' &&
        _jellyfinAuthMethod == JellyfinAuthMethod.quickConnect) {
      await _startQuickConnect();
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!mounted) return;
    final appState = context.read<AppState>();
    bool success;

    if (_selectedServerType == 'plex') {
      success = await appState.loginWithServerType(
        _selectedServerType,
        _serverController.text.trim(),
        '',
        _plexTokenController.text,
      );
    } else if (_selectedServerType == 'jellyfin' &&
        _jellyfinAuthMethod == JellyfinAuthMethod.apiKey) {
      success = await appState.loginWithApiKey(
        _serverController.text.trim(),
        _apiKeyController.text.trim(),
      );
    } else {
      success = await appState.loginWithServerType(
        _selectedServerType,
        _serverController.text.trim(),
        _usernameController.text.trim(),
        _passwordController.text,
      );
    }

    if (success && mounted) {
      if (Navigator.canPop(context)) Navigator.pop(context);
    }
  }

  Future<void> _startQuickConnect() async {
    final serverUrl = _serverController.text.trim();
    if (serverUrl.isEmpty) {
      if (mounted) {
        context.read<AppState>().setErrorMessage('Please enter a server URL first');
      }
      return;
    }

    final jellyfinService = JellyfinService();
    final isEnabled = await jellyfinService.isQuickConnectEnabled(serverUrl);
    if (!isEnabled && mounted) {
      context.read<AppState>().setErrorMessage(
        'Quick Connect is not enabled on this server.',
      );
      return;
    }

    final result = await jellyfinService.initiateQuickConnect(serverUrl);
    if (result == null && mounted) {
      context.read<AppState>().setErrorMessage('Failed to start Quick Connect.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _isQuickConnectActive = true;
      _quickConnectCode = result!['code'];
      _quickConnectSecret = result['secret'];
    });

    _quickConnectPollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkQuickConnectStatus(),
    );
  }

  Future<void> _checkQuickConnectStatus() async {
    if (_quickConnectSecret == null) return;
    final serverUrl = _serverController.text.trim();
    final jellyfinService = JellyfinService();
    final status = await jellyfinService.checkQuickConnectStatus(
      serverUrl,
      _quickConnectSecret!,
    );

    if (status != null && status['authenticated'] == true) {
      _quickConnectPollTimer?.cancel();
      final success = await jellyfinService.authenticateWithQuickConnect(
        serverUrl,
        _quickConnectSecret!,
      );
      if (!mounted) return;
      if (success) {
        await context.read<AppState>().loginWithQuickConnect(jellyfinService);
        if (mounted) {
          setState(() {
            _isQuickConnectActive = false;
            _quickConnectCode = null;
            _quickConnectSecret = null;
          });
          if (Navigator.canPop(context)) Navigator.pop(context);
        }
      } else {
        context.read<AppState>().setErrorMessage('Quick Connect failed.');
        _cancelQuickConnect();
      }
    }
  }

  void _cancelQuickConnect() {
    _quickConnectPollTimer?.cancel();
    setState(() {
      _isQuickConnectActive = false;
      _quickConnectCode = null;
      _quickConnectSecret = null;
    });
  }

  void _openLocalMusicSettings() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const LocalMusicSettingsScreen(isInitialSetup: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Server type',
            style: theme.textTheme.titleSmall?.copyWith(
              color: DesktopTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _serverTypeChip('jellyfin', 'Jellyfin', AppleColors.systemPurple, isDark),
              _serverTypeChip('plex', 'Plex', AppleColors.systemOrange, isDark),
              _serverTypeChip('subsonic', 'Subsonic', AppleColors.systemBlue, isDark),
              _serverTypeChip('local', 'Local', AppleColors.systemGreen, isDark),
            ],
          ),
          const SizedBox(height: 20),

          if (_selectedServerType == 'local') ...[
            OutlinedButton.icon(
              onPressed: _openLocalMusicSettings,
              icon: const Icon(Icons.folder_rounded),
              label: const Text('Configure local music'),
            ),
          ] else ...[
            TextFormField(
              controller: _serverController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'https://server:8096',
              ),
              validator: _validateServerUrl,
              onChanged: (_) {
                if (_selectedServerType == 'jellyfin') setState(() {});
              },
            ),
            const SizedBox(height: 16),

            if (_selectedServerType == 'jellyfin') ...[
              SegmentedButton<JellyfinAuthMethod>(
                segments: const [
                  ButtonSegment(
                    value: JellyfinAuthMethod.account,
                    label: Text('Account'),
                    icon: Icon(Icons.person_outline, size: 18),
                  ),
                  ButtonSegment(
                    value: JellyfinAuthMethod.apiKey,
                    label: Text('API Key'),
                    icon: Icon(Icons.key, size: 18),
                  ),
                  ButtonSegment(
                    value: JellyfinAuthMethod.quickConnect,
                    label: Text('Quick'),
                    icon: Icon(Icons.qr_code, size: 18),
                  ),
                ],
                selected: {_jellyfinAuthMethod},
                onSelectionChanged: (s) {
                  setState(() {
                    _jellyfinAuthMethod = s.first;
                    if (_jellyfinAuthMethod != JellyfinAuthMethod.quickConnect) {
                      _cancelQuickConnect();
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            if (_selectedServerType == 'jellyfin' &&
                _jellyfinAuthMethod == JellyfinAuthMethod.quickConnect) ...[
              if (_isQuickConnectActive && _quickConnectCode != null)
                _quickConnectCodeWidget(context, theme)
              else
                OutlinedButton(
                  onPressed: context.watch<AppState>().isLoading ? null : _startQuickConnect,
                  child: const Text('Start Quick Connect'),
                ),
            ] else if (_selectedServerType == 'plex') ...[
              TextFormField(
                controller: _plexTokenController,
                decoration: const InputDecoration(
                  labelText: 'Plex Token',
                  hintText: 'X-Plex-Token',
                ),
                validator: (v) =>
                    (v == null || v.toString().trim().isEmpty) ? 'Enter Plex token' : null,
              ),
            ] else if (_selectedServerType == 'jellyfin' &&
                _jellyfinAuthMethod == JellyfinAuthMethod.apiKey) ...[
              TextFormField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'Your Jellyfin API key',
                ),
                validator: (v) =>
                    (v == null || v.toString().trim().isEmpty) ? 'Enter API key' : null,
              ),
            ] else ...[
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'Username',
                ),
                validator: (v) =>
                    (v == null || v.toString().trim().isEmpty) ? 'Enter username' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Password (optional)',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
              ),
            ],

            if (_selectedServerType != 'jellyfin' ||
                _jellyfinAuthMethod != JellyfinAuthMethod.quickConnect ||
                (_isQuickConnectActive && _quickConnectCode != null)) ...[
              const SizedBox(height: 8),
              if (context.watch<AppState>().errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    context.read<AppState>().errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: context.watch<AppState>().isLoading
                    ? null
                    : _connect,
                icon: context.watch<AppState>().isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link_rounded),
                label: Text(
                  context.watch<AppState>().isLoading ? 'Connecting...' : 'Connect',
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _serverTypeChip(
    String type,
    String label,
    Color color,
    bool isDark,
  ) {
    final isSelected = _selectedServerType == type;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) async {
        if (type == 'local') {
          _openLocalMusicSettings();
          return;
        }
        setState(() {
          _selectedServerType = type;
          _serverController.text = _getServerPlaceholder();
          if (type == 'plex') {
            _usernameController.clear();
            _passwordController.clear();
          } else {
            _plexTokenController.clear();
          }
        });
      },
      selectedColor: color.withOpacity(isDark ? 0.3 : 0.2),
      checkmarkColor: color,
    );
  }

  Widget _quickConnectCodeWidget(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesktopTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesktopTheme.glassBorder),
      ),
      child: Column(
        children: [
          const Text('Enter this code on your Jellyfin server'),
          const SizedBox(height: 12),
          Text(
            _quickConnectCode!,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _cancelQuickConnect,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
