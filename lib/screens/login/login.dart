import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _plexTokenController = TextEditingController();
  
  String _selectedServerType = 'jellyfin'; // Default to Jellyfin

  @override
  void dispose() {
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
    final isTablet = screenSize.width > 480 && screenSize.width <= 768;
    
    return Scaffold(
      backgroundColor: _getBackgroundColor(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (isDesktop) {
              return _buildDesktopLayout(context, constraints);
            } else {
              return _buildMobileLayout(context, constraints);
            }
          },
        ),
      ),
    );
  }

  Color _getBackgroundColor(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    if (brightness == Brightness.dark) {
      return const Color(0xFF0A0A0A);
    }
    return const Color(0xFFF8F9FA);
  }

  Widget _buildDesktopLayout(BuildContext context, BoxConstraints constraints) {
    return Container(
      decoration: _buildBackgroundDecoration(context),
      child: Row(
        children: [
          // Left side - Hero section with gradient
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
                  // Animated background elements
                  _buildAnimatedBackground(),
                  
                  // Hero content
                  Padding(
                    padding: const EdgeInsets.all(60),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // App icon with glow effect
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.3),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            CupertinoIcons.music_note_2,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Welcome text
                        Text(
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
                        
                        const SizedBox(height: 20),
                        
                        Text(
                          'Your personal music companion.\nStream from Jellyfin, Plex, or Navidrome.',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.6,
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
                    child: _buildLoginForm(context, isDesktop: true),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, BoxConstraints constraints) {
    return Container(
      decoration: _buildBackgroundDecoration(context),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            children: [
              // Mobile header with gradient
              Container(
                height: constraints.maxHeight * 0.4,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      CupertinoColors.systemPurple.resolveFrom(context),
                      CupertinoColors.systemBlue.resolveFrom(context),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    _buildAnimatedBackground(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // App icon
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.music_note_2,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Welcome text
                          Text(
                            'Welcome to Doudou',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 12),
                          
                          Text(
                            'Your personal music companion',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Form section
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildLoginForm(context, isDesktop: false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundDecoration(BuildContext context) {
    return Container(); // Simple container for now, can be enhanced with patterns
  }

  Widget _buildAnimatedBackground() {
    return Positioned.fill(
      child: CustomPaint(
        painter: _BackgroundPatternPainter(),
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
              
              if (!isDesktop) const SizedBox(height: 40),
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
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
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
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
                ? color.withOpacity(0.1)
                : Theme.of(context).cardColor,
              border: Border.all(
                color: isSelected 
                  ? color
                  : Theme.of(context).dividerColor,
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
                        color: isSelected ? color : Theme.of(context).colorScheme.onSurface,
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
                          color: isSelected ? color : Theme.of(context).colorScheme.onSurface,
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
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
            fontSize: isDesktop ? 16 : 16,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.error,
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
                fontSize: isDesktop ? 14 : 14,
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
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Signing In...',
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Text(
              'Sign In',
              style: TextStyle(
                fontSize: isDesktop ? 16 : 16,
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
          foregroundColor: Theme.of(context).colorScheme.primary,
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline,
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
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Use Offline Mode',
              style: TextStyle(
                fontSize: isDesktop ? 16 : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
                    // Header section with logo and title
                    Container(
                      padding: const EdgeInsets.only(top: 60, bottom: 40),
                      child: Column(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemPurple,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Icon(
                              CupertinoIcons.music_note_2,
                              size: 50,
                              color: CupertinoColors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Welcome to Doudou',
                            style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle.copyWith(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getServerSubtitle(),
                            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 17,
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // Server Type Selection
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose Your Server',
                            style: TextStyle(
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildServerButton(
                                context,
                                'Jellyfin',
                                'assets/icons/jellyfin.svg',
                                CupertinoColors.systemPurple,
                                _selectedServerType == 'jellyfin',
                                () {
                                  setState(() {
                                    _selectedServerType = 'jellyfin';
                                    _serverController.text = 'http://your-jellyfin-server:8096';
                                    _plexTokenController.clear();
                                  });
                                },
                              ),
                              _buildServerButton(
                                context,
                                'Plex',
                                'assets/icons/plex.svg',
                                CupertinoColors.systemOrange,
                                _selectedServerType == 'plex',
                                () {
                                  setState(() {
                                    _selectedServerType = 'plex';
                                    _serverController.text = 'http://your-plex-server:32400';
                                    _usernameController.clear();
                                    _passwordController.clear();
                                  });
                                },
                              ),
                              _buildServerButton(
                                context,
                                'Navidrome',
                                'assets/icons/navidrome.svg',
                                CupertinoColors.systemBlue,
                                _selectedServerType == 'navidrome',
                                () {
                                  setState(() {
                                    _selectedServerType = 'navidrome';
                                    _serverController.text = 'http://your-navidrome-server:4533';
                                    _plexTokenController.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),

                    // Form fields section
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: CupertinoFormSection.insetGrouped(
                        header: Text(
                          'Server Details',
                          style: TextStyle(
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        children: [
                          CupertinoTextFormFieldRow(
                            controller: _serverController,
                            prefix: Icon(
                              CupertinoIcons.globe,
                              color: CupertinoColors.systemGrey.resolveFrom(context),
                            ),
                            placeholder: _getServerPlaceholder(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter server URL';
                              }
                              return null;
                            },
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                            style: TextStyle(
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: CupertinoFormSection.insetGrouped(
                        header: Text(
                          _getAccountSectionTitle(),
                          style: TextStyle(
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        children: _buildAccountFields(),
                      ),
                    ),

                    
                    const SizedBox(height: 32),

                    // Error Message
                    if (appState.errorMessage != null)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: CupertinoColors.systemRed.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.exclamationmark_triangle,
                              color: CupertinoColors.systemRed,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                appState.errorMessage!,
                                style: TextStyle(
                                  color: CupertinoColors.systemRed,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (appState.errorMessage != null) const SizedBox(height: 24),

                    // Sign In Button
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      width: double.infinity,
                      child: CupertinoButton.filled(
                        onPressed: appState.isLoading ? null : _login,
                        borderRadius: BorderRadius.circular(12),
                        child: appState.isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CupertinoActivityIndicator(
                                      color: CupertinoColors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Signing In...',
                                    style: TextStyle(
                                      color: CupertinoColors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Offline Mode Button
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      width: double.infinity,
                      child: CupertinoButton(
                        onPressed: appState.isLoading ? null : _enterOfflineMode,
                        borderRadius: BorderRadius.circular(12),
                        color: CupertinoColors.systemGrey5.resolveFrom(context),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              CupertinoIcons.arrow_down_circle,
                              size: 20,
                              color: CupertinoColors.systemPurple,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Use Offline Mode',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: CupertinoColors.label.resolveFrom(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Bottom spacing
                    SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      String identifier;
      String credential;
      
      if (_selectedServerType == 'plex') {
        identifier = ''; // Plex doesn't use username for token auth
        credential = _plexTokenController.text;
      } else {
        identifier = _usernameController.text.trim();
        credential = _passwordController.text;
      }
      
      final success = await context.read<AppState>().loginWithServerType(
        _selectedServerType,
        _serverController.text.trim(),
        identifier,
        credential,
      );

      if (success && mounted) {
        // Navigation will be handled by the main app based on login state
      }
    }
  }
  
  Future<void> _enterOfflineMode() async {
    final appState = context.read<AppState>();
    final success = await appState.enterOfflineModeWithoutLogin();
    
    if (!success && mounted) {
      // Show an alert to the user if no downloaded content is available
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
    // If successful, navigation will be handled by the main app based on login state
  }

  String _getServerSubtitle() {
    switch (_selectedServerType) {
      case 'jellyfin':
        return 'Sign in to your Jellyfin server';
      case 'plex':
        return 'Sign in to your Plex server';
      case 'navidrome':
        return 'Sign in to your Navidrome server';
      default:
        return 'Sign in to your server';
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

  String _getAccountSectionTitle() {
    switch (_selectedServerType) {
      case 'plex':
        return 'Authentication';
      default:
        return 'Account';
    }
  }

  List<Widget> _buildAccountFields() {
    if (_selectedServerType == 'plex') {
      return [
        CupertinoTextFormFieldRow(
          controller: _plexTokenController,
          prefix: Icon(
            CupertinoIcons.creditcard,
            color: CupertinoColors.systemGrey.resolveFrom(context),
          ),
          placeholder: 'X-Plex-Token',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your Plex token';
            }
            return null;
          },
          autocorrect: false,
          style: TextStyle(
            color: CupertinoColors.label.resolveFrom(context),
          ),
        ),
      ];
    } else {
      return [
        CupertinoTextFormFieldRow(
          controller: _usernameController,
          prefix: Icon(
            CupertinoIcons.person,
            color: CupertinoColors.systemGrey.resolveFrom(context),
          ),
          placeholder: 'Username',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter username';
            }
            return null;
          },
          autocorrect: false,
          style: TextStyle(
            color: CupertinoColors.label.resolveFrom(context),
          ),
        ),
        CupertinoTextFormFieldRow(
          controller: _passwordController,
          prefix: Icon(
            CupertinoIcons.lock,
            color: CupertinoColors.systemGrey.resolveFrom(context),
          ),
          placeholder: 'Password',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter password';
            }
            return null;
          },
          obscureText: true,
          autocorrect: false,
          style: TextStyle(
            color: CupertinoColors.label.resolveFrom(context),
          ),
        ),
      ];
    }
  }

  Widget _buildServerButton(
    BuildContext context,
    String label,
    String svgAssetPath,
    Color color,
    bool isSelected,
    VoidCallback onPressed,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 16),
          onPressed: onPressed,
          borderRadius: BorderRadius.circular(16),
          color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.2) : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? color : color.withOpacity(0.3),
                    width: isSelected ? 3 : 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SvgPicture.asset(
                    svgAssetPath,
                    width: 36,
                    height: 36,
                    colorFilter: ColorFilter.mode(
                      color,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
