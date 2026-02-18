import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import '../../../providers/app_state.dart';
import '../widgets/apple_design/apple_theme.dart';
import '../../../services/players/jellyfin_service.dart';
import '../settings/local_music_settings.dart';

// Auth method enum for Jellyfin
enum JellyfinAuthMethod { account, apiKey, quickConnect }

/// Add/Edit Server form - embeddable in Settings, no separate screen.
class AddServerForm extends StatefulWidget {
  final VoidCallback? onSuccess;
  final VoidCallback? onCancel;
  final Map<String, String>? existingServer;

  const AddServerForm({
    super.key,
    this.onSuccess,
    this.onCancel,
    this.existingServer,
  });

  @override
  State<AddServerForm> createState() => _AddServerFormState();
}

class _AddServerFormState extends State<AddServerForm> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _plexTokenController = TextEditingController();
  final _apiKeyController = TextEditingController();

  String _selectedServerType = 'jellyfin';
  bool _isPasswordVisible = false;
  JellyfinAuthMethod _jellyfinAuthMethod = JellyfinAuthMethod.account;

  // Quick Connect state
  bool _isQuickConnectActive = false;
  String? _quickConnectCode;
  String? _quickConnectSecret;
  Timer? _quickConnectPollTimer;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingServer;
    if (existing != null) {
      _selectedServerType = existing['type'] ?? 'jellyfin';
      _serverController.text = existing['url'] ?? _getServerPlaceholder();
      _nameController.text = existing['displayName'] ?? '';
      _usernameController.text = existing['username'] ?? '';
      _apiKeyController.text = existing['apiKey'] ?? '';
      _plexTokenController.text = existing['plexToken'] ?? '';
    } else {
      _serverController.text = _getServerPlaceholder();
    }
  }

  @override
  void dispose() {
    _serverController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _plexTokenController.dispose();
    _apiKeyController.dispose();
    _quickConnectPollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width > 768;
    return _buildLoginForm(context, isDesktop: isDesktop);
  }

  Widget _buildLoginForm(BuildContext context, {required bool isDesktop}) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Form header
              Text(
                widget.existingServer != null ? 'Edit Server' : 'Add Server',
                style: TextStyle(
                  fontFamily: AppleDesignSystem.fontFamily,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                widget.existingServer != null ? 'Update server configuration' : 'Configure a new media server',
                style: TextStyle(
                  fontFamily: AppleDesignSystem.fontFamily,
                  fontSize: 15,
                  color: isDark
                      ? Colors.white.withOpacity(0.6)
                      : Colors.black.withOpacity(0.5),
                ),
              ),

              SizedBox(height: isDesktop ? 32 : 24),

              // Server type selection
              _buildServerTypeSelection(context, isDesktop),

              SizedBox(height: isDesktop ? 28 : 20),

              // Optional name
              _buildModernTextField(
                controller: _nameController,
                label: 'Name (optional)',
                icon: CupertinoIcons.tag,
                placeholder: 'e.g. My Home Server',
                isDark: isDark,
              ),
              SizedBox(height: isDesktop ? 16 : 12),

              // Server URL field (hidden for SoundCloud – uses client credentials only)
              if (_selectedServerType != 'soundcloud')
                _buildModernTextField(
                  controller: _serverController,
                  label: 'Server URL',
                  icon: CupertinoIcons.globe,
                  placeholder: _getServerPlaceholder(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter server URL';
                    }
                    return null;
                  },
                  keyboardType: TextInputType.url,
                  isDark: isDark,
                ),

              if (_selectedServerType == 'soundcloud')
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Register an app at developers.soundcloud.com and paste your Client ID and Client Secret below. Set Redirect URI to http://localhost/callback and click Save.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.white.withOpacity(0.6)
                          : Colors.black.withOpacity(0.5),
                    ),
                  ),
                ),

              if (_selectedServerType != 'soundcloud')
                SizedBox(height: isDesktop ? 16 : 12),

              // Account fields
              ..._buildAccountFieldsModern(context, isDesktop),

              SizedBox(height: isDesktop ? 28 : 20),

              // Error message
              if (appState.errorMessage != null) ...[
                _buildErrorMessage(context, appState.errorMessage!, isDesktop),
                SizedBox(height: isDesktop ? 20 : 16),
              ],

              // Sign in / Save button
              _buildPrimaryButton(
                context: context,
                label: widget.existingServer != null ? 'Save' : 'Sign In',
                icon: CupertinoIcons.arrow_right,
                isLoading: appState.isLoading,
                onPressed: appState.isLoading ? null : _login,
                isDark: isDark,
              ),

              SizedBox(height: isDesktop ? 12 : 10),

              // Cancel button when embedded
              if (widget.onCancel != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildSecondaryButton(
                        context: context,
                        label: 'Cancel',
                        icon: CupertinoIcons.xmark,
                        onPressed: appState.isLoading ? null : widget.onCancel,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isDesktop ? 12 : 10),
              ],

              SizedBox(height: isDesktop ? 24 : 20),
            ],
          ),
        );
      },
    );
  }

  static const List<Map<String, dynamic>> _serverTypeOptions = [
    {'type': 'jellyfin', 'label': 'Jellyfin'},
    {'type': 'plex', 'label': 'Plex'},
    {'type': 'subsonic', 'label': 'Subsonic'},
    {'type': 'soundcloud', 'label': 'SoundCloud'},
    {'type': 'local', 'label': 'Local Music'},
  ];

  Widget _buildServerTypeSelection(BuildContext context, bool isDesktop) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Server Type',
          style: TextStyle(
            fontFamily: AppleDesignSystem.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: isDark
                ? Colors.white.withOpacity(0.7)
                : Colors.black.withOpacity(0.6),
          ),
        ),
        SizedBox(height: isDesktop ? 12 : 10),
        DropdownButtonFormField<String>(
          value: _selectedServerType,
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.08),
                width: 1,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          items: _serverTypeOptions.map((opt) {
            final type = opt['type'] as String;
            final label = opt['label'] as String;
            return DropdownMenuItem<String>(
              value: type,
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppleDesignSystem.fontFamily,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newType) async {
            if (newType == null) return;
            await _triggerButtonPress();
            if (!mounted) return;
            if (newType == 'local') {
              if (!mounted) return;
              Navigator.push(
                // ignore: use_build_context_synchronously
                context,
                CupertinoPageRoute(
                  builder: (context) =>
                      const LocalMusicSettingsScreen(isInitialSetup: true),
                ),
              );
              return;
            }
            setState(() {
              _selectedServerType = newType;
              _serverController.text = _getServerPlaceholder();
              if (newType == 'plex') {
                _usernameController.clear();
                _passwordController.clear();
              } else {
                _plexTokenController.clear();
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String placeholder,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    required bool isDark,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppleDesignSystem.fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isDark
                ? Colors.white.withOpacity(0.7)
                : Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autocorrect: false,
          style: TextStyle(
            fontFamily: AppleDesignSystem.fontFamily,
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(
              fontFamily: AppleDesignSystem.fontFamily,
              color: isDark
                  ? Colors.white.withOpacity(0.3)
                  : Colors.black.withOpacity(0.3),
            ),
            prefixIcon: Icon(
              icon,
              size: 20,
              color: isDark
                  ? Colors.white.withOpacity(0.5)
                  : Colors.black.withOpacity(0.4),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.08),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppleColors.systemPurple.withOpacity(0.8),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppleColors.systemRed.withOpacity(0.8),
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppleColors.systemRed.withOpacity(0.8),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAccountFieldsModern(BuildContext context, bool isDesktop) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    if (_selectedServerType == 'soundcloud') {
      return [
        _buildModernTextField(
          controller: _usernameController,
          label: 'Client ID',
          icon: Icons.vpn_key,
          placeholder: 'Your SoundCloud app Client ID',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your Client ID';
            }
            return null;
          },
          isDark: isDark,
        ),
        SizedBox(height: isDesktop ? 16 : 12),
        _buildModernTextField(
          controller: _passwordController,
          label: 'Client Secret',
          icon: CupertinoIcons.lock,
          placeholder: 'Your SoundCloud app Client Secret',
          obscureText: !_isPasswordVisible,
          isDark: isDark,
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible
                  ? CupertinoIcons.eye_slash
                  : CupertinoIcons.eye,
              size: 20,
              color: isDark
                  ? Colors.white.withOpacity(0.5)
                  : Colors.black.withOpacity(0.4),
            ),
            onPressed: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
          ),
        ),
      ];
    } else if (_selectedServerType == 'plex') {
      return [
        _buildModernTextField(
          controller: _plexTokenController,
          label: 'Plex Token',
          icon: CupertinoIcons.creditcard,
          placeholder: 'X-Plex-Token',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your Plex token';
            }
            return null;
          },
          isDark: isDark,
        ),
      ];
    } else if (_selectedServerType == 'jellyfin') {
      // Jellyfin supports account, API key, and Quick Connect authentication
      return [
        // Toggle between auth methods
        _buildAuthMethodToggle(isDark),

        SizedBox(height: isDesktop ? 16 : 12),

        if (_jellyfinAuthMethod == JellyfinAuthMethod.apiKey) ...[
          _buildModernTextField(
            controller: _apiKeyController,
            label: 'API Key',
            icon: CupertinoIcons.lock_shield,
            placeholder: 'Enter your Jellyfin API key',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your API key';
              }
              return null;
            },
            isDark: isDark,
          ),
        ] else if (_jellyfinAuthMethod == JellyfinAuthMethod.quickConnect) ...[
          _buildQuickConnectUI(isDark, isDesktop),
        ] else ...[
          _buildModernTextField(
            controller: _usernameController,
            label: 'Username',
            icon: CupertinoIcons.person,
            placeholder: 'Enter your username',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter username';
              }
              return null;
            },
            isDark: isDark,
          ),

          SizedBox(height: isDesktop ? 16 : 12),

          _buildModernTextField(
            controller: _passwordController,
            label: 'Password',
            icon: CupertinoIcons.lock,
            placeholder: 'Enter your password (optional)',
            obscureText: !_isPasswordVisible,
            isDark: isDark,
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible
                    ? CupertinoIcons.eye_slash
                    : CupertinoIcons.eye,
                size: 20,
                color: isDark
                    ? Colors.white.withOpacity(0.5)
                    : Colors.black.withOpacity(0.4),
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
          ),
        ],
      ];
    } else {
      // Subsonic or other servers - username/password only
      return [
        _buildModernTextField(
          controller: _usernameController,
          label: 'Username',
          icon: CupertinoIcons.person,
          placeholder: 'Enter your username',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter username';
            }
            return null;
          },
          isDark: isDark,
        ),

        SizedBox(height: isDesktop ? 16 : 12),

        _buildModernTextField(
          controller: _passwordController,
          label: 'Password',
          icon: CupertinoIcons.lock,
          placeholder: 'Enter your password (optional)',
          obscureText: !_isPasswordVisible,
          isDark: isDark,
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible
                  ? CupertinoIcons.eye_slash
                  : CupertinoIcons.eye,
              size: 20,
              color: isDark
                  ? Colors.white.withOpacity(0.5)
                  : Colors.black.withOpacity(0.4),
            ),
            onPressed: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
          ),
        ),
      ];
    }
  }

  Widget _buildAuthMethodToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildAuthMethodOption(
              method: JellyfinAuthMethod.account,
              icon: CupertinoIcons.person,
              label: 'Account',
              isDark: isDark,
            ),
          ),
          Expanded(
            child: _buildAuthMethodOption(
              method: JellyfinAuthMethod.apiKey,
              icon: CupertinoIcons.lock_shield,
              label: 'API Key',
              isDark: isDark,
            ),
          ),
          Expanded(
            child: _buildAuthMethodOption(
              method: JellyfinAuthMethod.quickConnect,
              icon: CupertinoIcons.qrcode,
              label: 'Quick',
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthMethodOption({
    required JellyfinAuthMethod method,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _jellyfinAuthMethod == method;

    return GestureDetector(
      onTap: () {
        setState(() {
          _jellyfinAuthMethod = method;
          // Cancel any existing Quick Connect session when switching away
          if (method != JellyfinAuthMethod.quickConnect) {
            _cancelQuickConnect();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppleColors.systemPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppleDesignSystem.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickConnectUI(bool isDark, bool isDesktop) {
    if (_isQuickConnectActive && _quickConnectCode != null) {
      // Show the Quick Connect code
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppleColors.systemPurple.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  CupertinoIcons.qrcode_viewfinder,
                  size: 48,
                  color: AppleColors.systemPurple,
                ),
                const SizedBox(height: 16),
                Text(
                  'Enter this code on your Jellyfin server',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppleDesignSystem.fontFamily,
                    fontSize: 14,
                    color: isDark
                        ? Colors.white.withOpacity(0.7)
                        : Colors.black.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppleColors.systemPurple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _quickConnectCode!,
                    style: TextStyle(
                      fontFamily: AppleDesignSystem.fontFamily,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: AppleColors.systemPurple,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppleColors.systemPurple,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Waiting for authorization...',
                      style: TextStyle(
                        fontFamily: AppleDesignSystem.fontFamily,
                        fontSize: 13,
                        color: isDark
                            ? Colors.white.withOpacity(0.5)
                            : Colors.black.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _cancelQuickConnect,
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: AppleDesignSystem.fontFamily,
                      color: AppleColors.systemRed,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Show the "Start Quick Connect" button
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.08),
            ),
          ),
          child: Column(
            children: [
              Icon(
                CupertinoIcons.bolt_circle,
                size: 48,
                color: AppleColors.systemPurple.withOpacity(0.8),
              ),
              const SizedBox(height: 12),
              Text(
                'Quick Connect',
                style: TextStyle(
                  fontFamily: AppleDesignSystem.fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in using a code from your Jellyfin server. Go to your user settings in Jellyfin and authorize the code.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppleDesignSystem.fontFamily,
                  fontSize: 13,
                  color: isDark
                      ? Colors.white.withOpacity(0.6)
                      : Colors.black.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _startQuickConnect() async {
    final serverUrl = _serverController.text.trim();
    if (serverUrl.isEmpty) {
      if (mounted) {
        final appState = context.read<AppState>();
        appState.setErrorMessage('Please enter a server URL first');
      }
      return;
    }

    final jellyfinService = JellyfinService();

    // Check if Quick Connect is enabled
    final isEnabled = await jellyfinService.isQuickConnectEnabled(serverUrl);
    if (!isEnabled) {
      if (mounted) {
        final appState = context.read<AppState>();
        appState.setErrorMessage(
          'Quick Connect is not enabled on this server. Please enable it in the server settings or use another login method.',
        );
      }
      return;
    }

    // Initiate Quick Connect
    final result = await jellyfinService.initiateQuickConnect(serverUrl);
    if (result == null) {
      if (mounted) {
        final appState = context.read<AppState>();
        appState.setErrorMessage(
          'Failed to start Quick Connect. Please try again.',
        );
      }
      return;
    }

    setState(() {
      _isQuickConnectActive = true;
      _quickConnectCode = result['code'];
      _quickConnectSecret = result['secret'];
    });

    // Start polling for authorization
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

      // Complete authentication
      final success = await jellyfinService.authenticateWithQuickConnect(
        serverUrl,
        _quickConnectSecret!,
      );

      if (!context.mounted) return;

      if (success) {
        // Update app state with the authenticated service - capture reference immediately after mounted check
        // ignore: use_build_context_synchronously
        final appState = context.read<AppState>();
        final displayName = _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim();
        await appState.loginWithQuickConnect(
          jellyfinService,
          displayName: displayName,
        );

        await _triggerHapticFeedback(isSuccess: true);

        if (!mounted) return;
        setState(() {
          _isQuickConnectActive = false;
          _quickConnectCode = null;
          _quickConnectSecret = null;
        });
        if (mounted) {
          if (widget.onSuccess != null) {
            widget.onSuccess!();
          } else {
            Navigator.of(context).maybePop();
          }
        }
      } else {
        await _triggerHapticFeedback(isSuccess: false);
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        final appState = context.read<AppState>();
        appState.setErrorMessage(
          'Quick Connect authentication failed. Please try again.',
        );
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

  Widget _buildErrorMessage(
    BuildContext context,
    String message,
    bool isDesktop,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppleColors.systemRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppleColors.systemRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: AppleColors.systemRed,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: AppleDesignSystem.fontFamily,
                color: AppleColors.systemRed,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isLoading,
    required VoidCallback? onPressed,
    required bool isDark,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppleColors.systemPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: AppleColors.systemPurple.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Connecting...',
                    style: TextStyle(
                      fontFamily: AppleDesignSystem.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppleDesignSystem.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, size: 18),
                ],
              ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isDark,
    Color? accentColor,
  }) {
    final color = accentColor ?? (isDark ? Colors.white : Colors.black);

    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color.withOpacity(0.8),
          side: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.15)
                : Colors.black.withOpacity(0.12),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppleDesignSystem.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Login and utility methods
  Future<void> _login() async {
    // Handle Quick Connect separately - it doesn't use the form validation
    if (_selectedServerType == 'jellyfin' &&
        _jellyfinAuthMethod == JellyfinAuthMethod.quickConnect) {
      await _triggerButtonPress();
      await _startQuickConnect();
      return;
    }

    if (_formKey.currentState!.validate()) {
      await _triggerButtonPress();

      if (!mounted) return;
      final appState = context.read<AppState>();
      final existingId = widget.existingServer?['id'];
      bool success;

      final displayName = _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim();
      if (_selectedServerType == 'soundcloud') {
        success = await appState.loginWithServerType(
          _selectedServerType,
          'https://api.soundcloud.com',
          _usernameController.text.trim(),
          _passwordController.text,
          displayName: displayName,
        );
      } else if (_selectedServerType == 'plex') {
        success = await appState.loginWithServerType(
          _selectedServerType,
          _serverController.text.trim(),
          '',
          _plexTokenController.text,
          displayName: displayName,
        );
      } else if (_selectedServerType == 'jellyfin' &&
          _jellyfinAuthMethod == JellyfinAuthMethod.apiKey) {
        success = await appState.loginWithApiKey(
          _serverController.text.trim(),
          _apiKeyController.text.trim(),
          displayName: displayName,
        );
      } else {
        success = await appState.loginWithServerType(
          _selectedServerType,
          _serverController.text.trim(),
          _usernameController.text.trim(),
          _passwordController.text,
          displayName: displayName,
        );
      }

      if (success && mounted) {
        if (existingId != null && existingId.isNotEmpty) {
          await appState.removeServer(existingId);
          if (!mounted) return;
        }
        await _triggerHapticFeedback(isSuccess: true);
        if (mounted) {
          if (widget.onSuccess != null) {
            widget.onSuccess!();
          } else {
            Navigator.of(context).maybePop();
          }
        }
      } else if (mounted) {
        // Error vibration
        await _triggerHapticFeedback(isSuccess: false);
      }
    } else {
      // Form validation failed - error vibration
      await _triggerHapticFeedback(isSuccess: false);
    }
  }

  String _getServerPlaceholder() {
    switch (_selectedServerType) {
      case 'jellyfin':
        return 'http://your-jellyfin-server:8096';
      case 'plex':
        return 'http://your-plex-server:32400';
      case 'subsonic':
        return 'http://your-subsonic-server:4533';
      case 'soundcloud':
      case 'local':
        return '';
      default:
        return 'http://your-server:port';
    }
  }

  // Haptic feedback methods
  Future<void> _triggerHapticFeedback({required bool isSuccess}) async {
    try {
      // Check if vibration is available
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) return;

      if (isSuccess) {
        // Success pattern: Light vibration
        HapticFeedback.lightImpact();
        await Vibration.vibrate(duration: 100);
      } else {
        // Error pattern: Strong vibration with pattern
        HapticFeedback.heavyImpact();
        await Vibration.vibrate(pattern: [0, 100, 50, 100]);
      }
    } catch (e) {
      // Silently fail if vibration is not supported
      // Fall back to haptic feedback only
      if (isSuccess) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
    }
  }

  Future<void> _triggerButtonPress() async {
    try {
      HapticFeedback.selectionClick();
    } catch (e) {
      // Silently fail if haptic feedback is not supported
    }
  }
}
