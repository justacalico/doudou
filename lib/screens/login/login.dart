import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import '../../providers/app_state.dart';

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
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
    
    // Set default server URLs
    _serverController.text = _getServerPlaceholder();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
    
    if (isDesktop) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: Theme.of(context),
        home: Scaffold(
          backgroundColor: _getBackgroundColor(context),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _buildDesktopLayout(context, constraints);
              },
            ),
          ),
        ),
      );
    } else {
      // Mobile: Provide MaterialLocalizations while using system theme
      final brightness = MediaQuery.of(context).platformBrightness;
      return Localizations(
        locale: const Locale('en', 'US'),
        delegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        child: Material(
          child: CupertinoPageScaffold(
            backgroundColor: brightness == Brightness.light 
              ? CupertinoColors.systemBackground 
              : CupertinoColors.black,
            child: SafeArea(
              child: _buildMobileLayout(context),
            ),
          ),
        ),
      );
    }
  }

  Color _getBackgroundColor(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    if (brightness == Brightness.dark) {
      return const Color(0xFF0A0A0A);
    }
    return const Color(0xFFF8F9FA);
  }

  Widget _buildDesktopLayout(BuildContext context, BoxConstraints constraints) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Row(
        children: [
          // Left side - Hero section
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    CupertinoColors.systemPurple.resolveFrom(context),
                    CupertinoColors.systemIndigo.resolveFrom(context),
                    CupertinoColors.systemBlue.resolveFrom(context),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Animated background pattern
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BackgroundPatternPainter(
                        animation: _animationController,
                      ),
                    ),
                  ),
                  
                  // Hero content
                  Padding(
                    padding: const EdgeInsets.all(60),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // App icon with glow effect
                        TweenAnimationBuilder(
                          duration: const Duration(milliseconds: 800),
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.3 * value),
                                      blurRadius: 30 * value,
                                      spreadRadius: 5 * value,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  CupertinoIcons.music_note_2,
                                  size: 60,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Welcome text with animation
                        SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(-0.5, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _animationController,
                            curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
                          )),
                          child: Text(
                            'Welcome to\nDoudou',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(-0.3, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _animationController,
                            curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
                          )),
                          child: Text(
                            'Your personal music companion.\nStream from Jellyfin, Plex, or Navidrome.',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white.withOpacity(0.9),
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Right side - Login form
          Expanded(
            flex: 4,
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(60),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.3, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _animationController,
                        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
                      )),
                      child: _buildLoginForm(context, isDesktop: true),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
          placeholder: 'Enter your password',
          obscureText: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter password';
            }
            return null;
          },
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
      'https://demo.jellyfin.org/stable',
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