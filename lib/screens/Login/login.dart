import 'package:flutter/cupertino.dart';
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

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      resizeToAvoidBottomInset: true,
      child: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Consumer<AppState>(
            builder: (context, appState, child) {
              return Form(
                key: _formKey,
                child: Column(
                  children: [
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
                            'Sign in to your Jellyfin server',
                            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 17,
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // Server URL Field
                    CupertinoFormSection(
                      margin: EdgeInsets.zero,
                      children: [
                        CupertinoFormRow(
                          prefix: const Icon(CupertinoIcons.globe),
                          child: CupertinoTextFormFieldRow(
                            controller: _serverController,
                            placeholder: 'http://your-jellyfin-server:8096',
                            prefix: const Text('Server URL'),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter server URL';
                              }
                              return null;
                            },
                            keyboardType: TextInputType.url,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Username Field
                    CupertinoFormSection(
                      margin: EdgeInsets.zero,
                      children: [
                        CupertinoFormRow(
                          prefix: const Icon(CupertinoIcons.person),
                          child: CupertinoTextFormFieldRow(
                            controller: _usernameController,
                            placeholder: 'Username',
                            prefix: const Text('Username'),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter username';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    CupertinoFormSection(
                      margin: EdgeInsets.zero,
                      children: [
                        CupertinoFormRow(
                          prefix: const Icon(CupertinoIcons.lock),
                          child: CupertinoTextFormFieldRow(
                            controller: _passwordController,
                            placeholder: 'Password',
                            prefix: const Text('Password'),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter password';
                              }
                              return null;
                            },
                            obscureText: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Error Message
                    if (appState.errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemRed.withOpacity(0.1),
                          border: Border.all(color: CupertinoColors.systemRed.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          appState.errorMessage!,
                          style: const TextStyle(color: CupertinoColors.systemRed),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (appState.errorMessage != null) const SizedBox(height: 16),

                    // Login Button
                    CupertinoButton(
                      onPressed: appState.isLoading ? null : _login,
                      color: CupertinoColors.systemPurple,
                      borderRadius: BorderRadius.circular(8),
                      child: appState.isLoading
                          ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                          : const Text(
                              'Login',
                              style: TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    
                    // Add bottom spacing to ensure content doesn't get cut off
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
      final success = await context.read<AppState>().login(
        _serverController.text.trim(),
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (success && mounted) {
        // Navigation will be handled by the main app based on login state
      }
    }
  }
}
