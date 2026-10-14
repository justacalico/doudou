import 'package:flutter/material.dart';

import 'api.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(DoudouServerApp(api: WebuiApi()));
}

class DoudouServerApp extends StatelessWidget {
  const DoudouServerApp({super.key, required this.api});

  final WebuiApi api;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'Doudou server',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: AuthGate(api: api),
    );
  }
}

/// Decides between first run setup, the login form and the dashboard.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.api});

  final WebuiApi api;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _setupRequired;
  bool _ready = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final state = await widget.api.state();
      var ready = false;
      if (widget.api.token != null && !state.setupRequired) {
        ready = await widget.api.tokenValid();
        if (!ready) widget.api.tokenStore.clear();
      }
      if (mounted) {
        setState(() {
          _setupRequired = state.setupRequired;
          _ready = ready;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = '$e');
      }
    }
  }

  void _onAuthed() => setState(() => _ready = true);

  void _onLoggedOut() => setState(() {
    _ready = false;
    _setupRequired = false;
  });

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not reach the server',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(_loadError!),
              const SizedBox(height: 16),
              FilledButton(onPressed: _resolve, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_setupRequired == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_ready) {
      return LoginScreen(
        api: widget.api,
        isSetup: _setupRequired!,
        onDone: _onAuthed,
      );
    }
    return DashboardScreen(api: widget.api, onLoggedOut: _onLoggedOut);
  }
}
