import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../../providers/app_state.dart';
import '../../widgets/apple_design/apple_theme.dart';

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
  
  String _selectedServerType = 'jellyfin';
  bool _isPasswordVisible = false;
  int _currentStep = 0; // 0 = server selection, 1 = credentials
  
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
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width > 768;
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Theme.of(context),
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
            bottom: size.height * 0.1 + math.cos(progress * math.pi * 2 + 1) * 40,
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
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGridPattern() {
    return Opacity(
      opacity: 0.03,
      child: CustomPaint(
        size: Size.infinite,
        painter: _GridPainter(),
      ),
    );
  }

  Color _getBackgroundColor(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    if (brightness == Brightness.dark) {
      return AppleColors.backgroundPrimaryDark;
    }
    return AppleColors.backgroundPrimary;
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
                Expanded(
                  flex: 5,
                  child: _buildBrandingSection(isDark),
                ),
                
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
                  colors: [
                    AppleColors.systemPurple,
                    AppleColors.systemIndigo,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppleColors.systemPurple.withOpacity(0.3 + _pulseController.value * 0.2),
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
          position: Tween<Offset>(
            begin: const Offset(-0.3, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
          )),
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
          position: Tween<Offset>(
            begin: const Offset(-0.2, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.4, 0.9, curve: Curves.easeOut),
          )),
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
          position: Tween<Offset>(
            begin: const Offset(-0.1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
          )),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildFeaturePill('🔒 Privacy First', isDark),
              _buildFeaturePill('🎵 High Quality Audio', isDark),
              _buildFeaturePill('📱 All Platforms', isDark),
              _buildFeaturePill('☁️ No Cloud Required', isDark),
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
          color: isDark ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.7),
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
    
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Small mobile header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.5),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
              )),
              child: Text(
                'Doudou - Welcome',
                style: CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: brightness == Brightness.light 
                    ? CupertinoColors.black 
                    : CupertinoColors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
          // Form section
          Padding(
            padding: const EdgeInsets.all(24),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
              )),
              child: _buildLoginForm(context, isDesktop: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context, {required bool isDesktop}) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Server type selection
              _buildServerTypeSelection(context, isDesktop),
              
              SizedBox(height: isDesktop ? 32 : 24),
              
              // Server URL field
              _buildTextField(
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
                isDesktop: isDesktop,
              ),
              
              SizedBox(height: isDesktop ? 20 : 16),
              
              // Account fields
              ..._buildAccountFieldsModern(context, isDesktop),
              
              SizedBox(height: isDesktop ? 32 : 24),
              
              // Error message
              if (appState.errorMessage != null) ...[
                _buildErrorMessage(context, appState.errorMessage!, isDesktop),
                SizedBox(height: isDesktop ? 24 : 20),
              ],
              
              // Sign in button
              _buildSignInButton(context, appState, isDesktop),
              
              SizedBox(height: isDesktop ? 16 : 12),
              
              // Offline mode button
              _buildOfflineModeButton(context, appState, isDesktop),
              
              SizedBox(height: isDesktop ? 16 : 12),
              
              // Demo button
              _buildDemoButton(context, appState, isDesktop),
              
              SizedBox(height: isDesktop ? 40 : 60),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServerTypeSelection(BuildContext context, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Your Server',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MediaQuery.of(context).platformBrightness == Brightness.dark
              ? CupertinoColors.white
              : CupertinoColors.black,
          ),
        ),
        
        SizedBox(height: isDesktop ? 16 : 12),
        
        if (isDesktop)
          Row(
            children: [
              Expanded(child: _buildServerCard('jellyfin', 'Jellyfin', 'assets/icons/jellyfin.svg', CupertinoColors.systemPurple, isDesktop)),
              const SizedBox(width: 16),
              Expanded(child: _buildServerCard('plex', 'Plex', 'assets/icons/plex.svg', CupertinoColors.systemOrange, isDesktop)),
              const SizedBox(width: 16),
              Expanded(child: _buildServerCard('navidrome', 'Navidrome', 'assets/icons/navidrome.svg', CupertinoColors.systemBlue, isDesktop)),
            ],
          )
        else
          Column(
            children: [
              _buildServerCard('jellyfin', 'Jellyfin', 'assets/icons/jellyfin.svg', CupertinoColors.systemPurple, isDesktop),
              const SizedBox(height: 12),
              _buildServerCard('plex', 'Plex', 'assets/icons/plex.svg', CupertinoColors.systemOrange, isDesktop),
              const SizedBox(height: 12),
              _buildServerCard('navidrome', 'Navidrome', 'assets/icons/navidrome.svg', CupertinoColors.systemBlue, isDesktop),
            ],
          ),
      ],
    );
  }

  Widget _buildServerCard(String type, String label, String iconPath, Color color, bool isDesktop) {
    final isSelected = _selectedServerType == type;
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await _triggerButtonPress();
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
          child: Container(
            padding: EdgeInsets.all(isDesktop ? 20 : 16),
            decoration: BoxDecoration(
              color: isSelected 
                ? color.withOpacity(0.15)
                : (isDark 
                    ? const Color(0xFF2C2C2E) 
                    : CupertinoColors.systemGrey6.color),
              border: Border.all(
                color: isSelected 
                  ? color
                  : (isDark 
                      ? const Color(0xFF3A3A3C) 
                      : CupertinoColors.systemGrey4.color),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
            ),
            child: isDesktop
              ? Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SvgPicture.asset(
                        iconPath,
                        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected 
                          ? color 
                          : (isDark 
                              ? CupertinoColors.white 
                              : CupertinoColors.black),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SvgPicture.asset(
                        iconPath,
                        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: isSelected 
                            ? color 
                            : (isDark 
                                ? CupertinoColors.white 
                                : CupertinoColors.black),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        CupertinoIcons.check_mark_circled_solid,
                        color: color,
                        size: 24,
                      ),
                  ],
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String placeholder,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    required bool isDesktop,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: MediaQuery.of(context).platformBrightness == Brightness.dark
              ? CupertinoColors.white
              : CupertinoColors.black,
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
            fontSize: 16,
            color: MediaQuery.of(context).platformBrightness == Brightness.dark
              ? CupertinoColors.white
              : CupertinoColors.black,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(
              color: MediaQuery.of(context).platformBrightness == Brightness.dark
                ? CupertinoColors.systemGrey
                : CupertinoColors.systemGrey2,
            ),
            prefixIcon: Icon(
              icon, 
              size: 20,
              color: MediaQuery.of(context).platformBrightness == Brightness.dark
                ? CupertinoColors.systemGrey
                : CupertinoColors.systemGrey2,
            ),
            filled: true,
            fillColor: MediaQuery.of(context).platformBrightness == Brightness.dark
              ? const Color(0xFF2C2C2E)
              : CupertinoColors.systemGrey6.color,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: MediaQuery.of(context).platformBrightness == Brightness.dark
                  ? const Color(0xFF3A3A3C)
                  : CupertinoColors.systemGrey4.color,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: CupertinoColors.systemPurple.color,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: CupertinoColors.systemRed.color,
                width: 1,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isDesktop ? 16 : 14,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAccountFieldsModern(BuildContext context, bool isDesktop) {
    if (_selectedServerType == 'plex') {
      return [
        _buildTextField(
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
          isDesktop: isDesktop,
        ),
      ];
    } else {
      return [
        _buildTextField(
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
          isDesktop: isDesktop,
        ),
        
        SizedBox(height: isDesktop ? 20 : 16),
        
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          icon: CupertinoIcons.lock,
          placeholder: 'Enter your password (optional)',
          obscureText: true,
          isDesktop: isDesktop,
        ),
      ];
    }
  }

  Widget _buildErrorMessage(BuildContext context, String message, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: Theme.of(context).colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInButton(BuildContext context, AppState appState, bool isDesktop) {
    return SizedBox(
      height: isDesktop ? 56 : 50,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: appState.isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: CupertinoColors.systemPurple.color,
          foregroundColor: CupertinoColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 24 : 20,
            vertical: isDesktop ? 16 : 14,
          ),
        ),
        child: appState.isLoading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: CupertinoColors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Signing In...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Text(
              'Sign In',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
      ),
    );
  }

  Widget _buildOfflineModeButton(BuildContext context, AppState appState, bool isDesktop) {
    return SizedBox(
      height: isDesktop ? 56 : 50,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: appState.isLoading ? null : _enterOfflineMode,
        style: OutlinedButton.styleFrom(
          foregroundColor: CupertinoColors.systemPurple.color,
          side: BorderSide(
            color: MediaQuery.of(context).platformBrightness == Brightness.dark
              ? const Color(0xFF3A3A3C)
              : CupertinoColors.systemGrey4.color,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 24 : 20,
            vertical: isDesktop ? 16 : 14,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.arrow_down_circle,
              size: 20,
              color: CupertinoColors.systemPurple.color,
            ),
            const SizedBox(width: 8),
            Text(
              'Use Offline Mode',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoButton(BuildContext context, AppState appState, bool isDesktop) {
    return SizedBox(
      height: isDesktop ? 56 : 50,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: appState.isLoading ? null : _loginDemo,
        style: OutlinedButton.styleFrom(
          foregroundColor: CupertinoColors.systemGreen.color,
          side: BorderSide(
            color: CupertinoColors.systemGreen.color.withOpacity(0.5),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 24 : 20,
            vertical: isDesktop ? 16 : 14,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.play_circle,
              size: 20,
              color: CupertinoColors.systemGreen.color,
            ),
            const SizedBox(width: 8),
            Text(
              'Try Demo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
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
    if (_formKey.currentState!.validate()) {
      // Trigger button press haptic feedback
      await _triggerButtonPress();
      
      String identifier;
      String credential;
      
      if (_selectedServerType == 'plex') {
        identifier = '';
        credential = _plexTokenController.text;
      } else {
        identifier = _usernameController.text.trim();
        credential = _passwordController.text;
      }
      
      if (!mounted) return;
      final appState = context.read<AppState>();
      final success = await appState.loginWithServerType(
        _selectedServerType,
        _serverController.text.trim(),
        identifier,
        credential,
      );

      if (success && mounted) {
        // Success vibration
        await _triggerHapticFeedback(isSuccess: true);
        // Navigation handled by main app
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
          content: const Text('You need to have downloaded music to use offline mode. Please sign in first to download some music.'),
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
      case 'navidrome':
        return 'http://your-navidrome-server:4533';
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

class _BackgroundPatternPainter extends CustomPainter {
  final Animation<double>? animation;

  _BackgroundPatternPainter({this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final animationValue = animation?.value ?? 0.5;
    
    // Create floating circles pattern
    for (int i = 0; i < 20; i++) {
      final x = (i * 80.0 + animationValue * 50) % (size.width + 100);
      final y = (i * 60.0 + animationValue * 30) % (size.height + 100);
      final radius = 20 + (i % 3) * 10.0;
      
      canvas.drawCircle(
        Offset(x, y),
        radius,
        paint..color = Colors.white.withOpacity(0.05 + (i % 3) * 0.02),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}