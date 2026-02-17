import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import '../../../providers/app_state.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/apple_design/apple_theme.dart';
import '../../../services/players/jellyfin_service.dart';
import '../settings/local_music_settings.dart';
import 'package:doudou/ui/layout/app_shell.dart';

// Auth method enum for Jellyfin
enum JellyfinAuthMethod { account, apiKey, quickConnect }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
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

  late AnimationController _animationController;
  late AnimationController _backgroundController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();

    // Set default server URLs
    _serverController.text = _getServerPlaceholder();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _backgroundController.dispose();
    _pulseController.dispose();
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _plexTokenController.dispose();
    _apiKeyController.dispose();
    _quickConnectPollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width > 768;
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Theme.of(context),
      locale: appState.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Animated gradient background
            _buildAnimatedBackground(isDark),

            // Main content
            SafeArea(
              child: isDesktop
                  ? _buildDesktopLayout(context)
                  : _buildMobileLayout(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground(bool isDark) {
    return AnimatedBuilder(
      animation: _backgroundController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF0D0D0D),
                      const Color(0xFF1A1A2E),
                      const Color(0xFF16213E),
                      const Color(0xFF0F0F23),
                    ]
                  : [
                      const Color(0xFFF8F9FA),
                      const Color(0xFFE8EAF6),
                      const Color(0xFFE3F2FD),
                      const Color(0xFFF3E5F5),
                    ],
              stops: const [0.0, 0.3, 0.6, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Floating orbs
              ..._buildFloatingOrbs(isDark),
              // Subtle grid pattern
              if (isDark) _buildGridPattern(),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildFloatingOrbs(bool isDark) {
    final size = MediaQuery.of(context).size;
    return [
      // Primary orb - purple
      AnimatedBuilder(
        animation: _backgroundController,
        builder: (context, _) {
          final progress = _backgroundController.value;
          return Positioned(
            left: size.width * 0.1 + math.sin(progress * math.pi * 2) * 50,
            top: size.height * 0.2 + math.cos(progress * math.pi * 2) * 30,
            child: _buildOrb(
              200,
              isDark
                  ? AppleColors.systemPurple.withOpacity(0.3)
                  : AppleColors.systemPurple.withOpacity(0.15),
            ),
          );
        },
      ),
      // Secondary orb - blue
      AnimatedBuilder(
        animation: _backgroundController,
        builder: (context, _) {
          final progress = _backgroundController.value;
          return Positioned(
            right: size.width * 0.05 + math.cos(progress * math.pi * 2) * 40,
            top: size.height * 0.4 + math.sin(progress * math.pi * 2) * 50,
            child: _buildOrb(
              160,
              isDark
                  ? AppleColors.systemBlue.withOpacity(0.25)
                  : AppleColors.systemBlue.withOpacity(0.12),
            ),
          );
        },
      ),
      // Tertiary orb - pink
      AnimatedBuilder(
        animation: _backgroundController,
        builder: (context, _) {
          final progress = _backgroundController.value;
          return Positioned(
            left: size.width * 0.3 + math.sin(progress * math.pi * 2 + 1) * 60,
            bottom:
                size.height * 0.1 + math.cos(progress * math.pi * 2 + 1) * 40,
            child: _buildOrb(
              180,
              isDark
                  ? AppleColors.systemPink.withOpacity(0.2)
                  : AppleColors.systemPink.withOpacity(0.1),
            ),
          );
        },
      ),
    ];
  }

  Widget _buildOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
      ),
    );
  }

  Widget _buildGridPattern() {
    return Opacity(
      opacity: 0.03,
      child: CustomPaint(size: Size.infinite, painter: _GridPainter()),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Row(
              children: [
                // Left side - Branding
                Expanded(flex: 5, child: _buildBrandingSection(isDark)),

                const SizedBox(width: 64),

                // Right side - Login form with glassmorphism
                Expanded(
                  flex: 4,
                  child: _buildGlassCard(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(40),
                      child: _buildLoginForm(context, isDesktop: true),
                    ),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandingSection(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // App icon with glow
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppleColors.systemPurple, AppleColors.systemIndigo],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppleColors.systemPurple.withOpacity(
                      0.3 + _pulseController.value * 0.2,
                    ),
                    blurRadius: 30 + _pulseController.value * 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.music_note_2,
                size: 50,
                color: Colors.white,
              ),
            );
          },
        ),

        const SizedBox(height: 40),

        // Welcome text
        SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(-0.3, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: _animationController,
                  curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
                ),
              ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to',
                style: TextStyle(
                  fontFamily: AppleDesignSystem.fontFamily,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? Colors.white.withOpacity(0.7)
                      : Colors.black.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    AppleColors.systemPurple,
                    AppleColors.systemPink,
                    AppleColors.systemIndigo,
                  ],
                ).createShader(bounds),
                child: const Text(
                  'Doudou',
                  style: TextStyle(
                    fontFamily: AppleDesignSystem.fontFamily,
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Tagline
        SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(-0.2, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: _animationController,
                  curve: const Interval(0.4, 0.9, curve: Curves.easeOut),
                ),
              ),
          child: Text(
            'Your personal music companion.\nStream from your own media server with\nstyle and privacy.',
            style: TextStyle(
              fontFamily: AppleDesignSystem.fontFamily,
              fontSize: 18,
              height: 1.6,
              color: isDark
                  ? Colors.white.withOpacity(0.6)
                  : Colors.black.withOpacity(0.5),
            ),
          ),
        ),

        const SizedBox(height: 48),

        // Feature pills
        SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(-0.1, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: _animationController,
                  curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
                ),
              ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildFeaturePill('Privacy First', isDark),
              _buildFeaturePill('High Quality Audio', isDark),
              _buildFeaturePill('All Platforms', isDark),
              _buildFeaturePill('No Cloud Required', isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturePill(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.08),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppleDesignSystem.fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark
              ? Colors.white.withOpacity(0.8)
              : Colors.black.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, required bool isDark}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.15)
                  : Colors.white.withOpacity(0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                blurRadius: 40,
                spreadRadius: 0,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Mobile header with logo
              _buildMobileHeader(isDark),

              const SizedBox(height: 32),

              // Login form card
              _buildGlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildLoginForm(context, isDesktop: false),
                ),
                isDark: isDark,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeader(bool isDark) {
    return Column(
      children: [
        // Animated logo
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppleColors.systemPurple, AppleColors.systemIndigo],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppleColors.systemPurple.withOpacity(
                      0.25 + _pulseController.value * 0.15,
                    ),
                    blurRadius: 20 + _pulseController.value * 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.music_note_2,
                size: 40,
                color: Colors.white,
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        // App name with gradient
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppleColors.systemPurple, AppleColors.systemPink],
          ).createShader(bounds),
          child: Text(
            'Doudou',
            style: TextStyle(
              fontFamily: AppleDesignSystem.fontFamily,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Your personal music companion',
          style: TextStyle(
            fontFamily: AppleDesignSystem.fontFamily,
            fontSize: 16,
            color: isDark
                ? Colors.white.withOpacity(0.6)
                : Colors.black.withOpacity(0.5),
          ),
        ),
      ],
    );
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
                'Sign In',
                style: TextStyle(
                  fontFamily: AppleDesignSystem.fontFamily,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Connect to your media server',
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
                    'Register an app at developers.soundcloud.com and paste your Client ID and Client Secret below.',
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

              // Sign in button
              _buildPrimaryButton(
                context: context,
                label: 'Sign In',
                icon: CupertinoIcons.arrow_right,
                isLoading: appState.isLoading,
                onPressed: appState.isLoading ? null : _login,
                isDark: isDark,
              ),

              SizedBox(height: isDesktop ? 12 : 10),

              // Secondary actions
              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryButton(
                      context: context,
                      label: 'Offline',
                      icon: CupertinoIcons.arrow_down_circle,
                      onPressed: appState.isLoading ? null : _enterOfflineMode,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSecondaryButton(
                      context: context,
                      label: 'Try Demo',
                      icon: CupertinoIcons.play_circle,
                      onPressed: appState.isLoading ? null : _loginDemo,
                      isDark: isDark,
                      accentColor: AppleColors.systemGreen,
                    ),
                  ),
                ],
              ),

              SizedBox(height: isDesktop ? 24 : 20),
            ],
          ),
        );
      },
    );
  }

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

        // Server type cards in a row (horizontal scroll on mobile)
        if (isDesktop)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildServerTypeCard(
                  'jellyfin',
                  'Jellyfin',
                  'assets/icons/jellyfin.svg',
                  AppleColors.systemPurple,
                  isDark,
                ),
                const SizedBox(width: 12),
                _buildServerTypeCard(
                  'plex',
                  'Plex',
                  'assets/icons/plex.svg',
                  AppleColors.systemOrange,
                  isDark,
                ),
                const SizedBox(width: 12),
                _buildServerTypeCard(
                  'subsonic',
                  'Subsonic',
                  'assets/icons/subsonic.svg',
                  AppleColors.systemBlue,
                  isDark,
                ),
                const SizedBox(width: 12),
                _buildServerTypeCard(
                  'soundcloud',
                  'SoundCloud',
                  null,
                  const Color(0xFFFF5500),
                  isDark,
                  icon: CupertinoIcons.cloud_fill,
                ),
                const SizedBox(width: 12),
                _buildServerTypeCard(
                  'local',
                  'Local',
                  null,
                  AppleColors.systemGreen,
                  isDark,
                  icon: CupertinoIcons.folder_fill,
                ),
              ],
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildServerTypeChip(
                  'jellyfin',
                  'Jellyfin',
                  'assets/icons/jellyfin.svg',
                  AppleColors.systemPurple,
                  isDark,
                ),
                const SizedBox(width: 10),
                _buildServerTypeChip(
                  'plex',
                  'Plex',
                  'assets/icons/plex.svg',
                  AppleColors.systemOrange,
                  isDark,
                ),
                const SizedBox(width: 10),
                _buildServerTypeChip(
                  'subsonic',
                  'Subsonic',
                  'assets/icons/subsonic.svg',
                  AppleColors.systemBlue,
                  isDark,
                ),
                const SizedBox(width: 10),
                _buildServerTypeChip(
                  'soundcloud',
                  'SoundCloud',
                  null,
                  const Color(0xFFFF5500),
                  isDark,
                  icon: CupertinoIcons.cloud_fill,
                ),
                const SizedBox(width: 10),
                _buildServerTypeChip(
                  'local',
                  'Local',
                  null,
                  AppleColors.systemGreen,
                  isDark,
                  icon: CupertinoIcons.folder_fill,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildServerTypeCard(
    String type,
    String label,
    String? iconPath,
    Color color,
    bool isDark, {
    IconData? icon,
  }) {
    final isSelected = _selectedServerType == type;

    return GestureDetector(
      onTap: () async {
        await _triggerButtonPress();
        if (type == 'local') {
          // Navigate to local music setup
          if (mounted) {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) =>
                    const LocalMusicSettingsScreen(isInitialSetup: true),
              ),
            );
          }
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 88,
        height: 100,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(isDark ? 0.2 : 0.12)
              : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color.withOpacity(0.6)
                : (isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.08)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: icon != null
                  ? Icon(icon, color: color, size: 24)
                  : SvgPicture.asset(
                      iconPath!,
                      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppleDesignSystem.fontFamily,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? color
                    : (isDark
                          ? Colors.white.withOpacity(0.8)
                          : Colors.black.withOpacity(0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerTypeChip(
    String type,
    String label,
    String? iconPath,
    Color color,
    bool isDark, {
    IconData? icon,
  }) {
    final isSelected = _selectedServerType == type;

    return GestureDetector(
      onTap: () async {
        await _triggerButtonPress();
        if (type == 'local') {
          // Navigate to local music setup
          if (mounted) {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) =>
                    const LocalMusicSettingsScreen(isInitialSetup: true),
              ),
            );
          }
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(isDark ? 0.2 : 0.12)
              : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color.withOpacity(0.6)
                : (isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.08)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: icon != null
                  ? Icon(icon, color: color, size: 20)
                  : SvgPicture.asset(
                      iconPath!,
                      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                    ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppleDesignSystem.fontFamily,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? color
                    : (isDark
                          ? Colors.white.withOpacity(0.8)
                          : Colors.black.withOpacity(0.7)),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.checkmark_circle_fill,
                size: 18,
                color: color,
              ),
            ],
          ],
        ),
      ),
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
        await appState.loginWithQuickConnect(jellyfinService);

        await _triggerHapticFeedback(isSuccess: true);

        if (!mounted) return;
        setState(() {
          _isQuickConnectActive = false;
          _quickConnectCode = null;
          _quickConnectSecret = null;
        });
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
            Icon(icon, size: 18, color: accentColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppleDesignSystem.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Demo login method
  Future<void> _loginDemo() async {
    await _triggerButtonPress();

    if (!mounted) return;
    final appState = context.read<AppState>();

    final success = await appState.loginWithServerType(
      'jellyfin',
      'https://demo.jellyfin.org/stable/web',
      'demo',
      '',
    );

    if (success && mounted) {
      await _triggerHapticFeedback(isSuccess: true);
    } else if (mounted) {
      await _triggerHapticFeedback(isSuccess: false);
    }
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
      // Trigger button press haptic feedback
      await _triggerButtonPress();

      if (!mounted) return;
      final appState = context.read<AppState>();
      bool success;

      if (_selectedServerType == 'soundcloud') {
        success = await appState.loginWithServerType(
          _selectedServerType,
          'https://api.soundcloud.com',
          _usernameController.text.trim(),
          _passwordController.text,
        );
      } else if (_selectedServerType == 'plex') {
        // Plex token auth
        success = await appState.loginWithServerType(
          _selectedServerType,
          _serverController.text.trim(),
          '',
          _plexTokenController.text,
        );
      } else if (_selectedServerType == 'jellyfin' &&
          _jellyfinAuthMethod == JellyfinAuthMethod.apiKey) {
        // Jellyfin API key auth
        success = await appState.loginWithApiKey(
          _serverController.text.trim(),
          _apiKeyController.text.trim(),
        );
      } else {
        // Standard username/password auth
        success = await appState.loginWithServerType(
          _selectedServerType,
          _serverController.text.trim(),
          _usernameController.text.trim(),
          _passwordController.text,
        );
      }

      if (success && mounted) {
        // Success vibration
        await _triggerHapticFeedback(isSuccess: true);
        // Force navigation to home screen
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            CupertinoPageRoute(builder: (context) => const AppShell()),
            (route) => false,
          );
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

  Future<void> _enterOfflineMode() async {
    // Trigger button press haptic feedback
    await _triggerButtonPress();

    if (!mounted) return;
    final appState = context.read<AppState>();
    final success = await appState.enterOfflineModeWithoutLogin();

    if (success && mounted) {
      // Success vibration
      await _triggerHapticFeedback(isSuccess: true);
    } else if (mounted) {
      // Error vibration for no offline content
      await _triggerHapticFeedback(isSuccess: false);

      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('No Downloaded Content'),
          content: const Text(
            'You need to have downloaded music to use offline mode. Please sign in first to download some music.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
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

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const gridSize = 40.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
