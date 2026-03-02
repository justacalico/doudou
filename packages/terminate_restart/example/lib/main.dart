import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terminate_restart/terminate_restart.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  TerminateRestart.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Terminate Restart Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E1E1E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E1E1E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/home': (context) => const MyHomePage(title: 'Terminate Restart Demo'),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2A2A2A),
                border: Border.all(
                  color: const Color(0xFF3A3A3A),
                  width: 2,
                ),
              ),
              child: const FaIcon(
                FontAwesomeIcons.arrowsRotate,
                size: 48,
                color: Colors.greenAccent,
              ),
            )
                .animate(
                  onPlay: (controller) => controller.repeat(),
                )
                .rotate(
                  duration: 2.seconds,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 24),
            Text(
              'TERMINATE RESTART',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ).animate().fadeIn(
                  duration: 800.milliseconds,
                  curve: Curves.easeOut,
                ),
          ],
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  bool _clearData = false;

  @override
  void initState() {
    super.initState();
    _loadCounter();
    _initializeCounter();
  }

  Future<void> _loadCounter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _counter = prefs.getInt('counter') ?? 0;
    });
  }

  Future<void> _initializeCounter() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt('counter') == null) {
      await prefs.setInt('counter', 0);
    }
  }

  Future<void> _incrementCounter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _counter++;
      prefs.setInt('counter', _counter);
    });
  }

  Future<void> _handleUIRestart() async {
    await TerminateRestart.instance.restartApp(
      options: TerminateRestartOptions(
        terminate: false,
        clearData: _clearData,
      ),
    );
  }

  Future<void> _handleTerminateRestart() async {
    await TerminateRestart.instance.restartApp(
      options: TerminateRestartOptions(
        terminate: true,
        clearData: _clearData,
      ),
    );
  }

  Future<void> _handleConfirmationRestart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        icon: const FaIcon(
          FontAwesomeIcons.triangleExclamation,
          size: 32,
          color: Colors.greenAccent,
        ),
        title: Text(
          'Confirm Restart',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to restart the app? This will close the current instance and start a new one.',
          style: GoogleFonts.inter(
            color: Colors.grey[400],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, false),
            icon: const FaIcon(
              FontAwesomeIcons.xmark,
              size: 16,
              color: Colors.grey,
            ),
            label: Text(
              'CANCEL',
              style: GoogleFonts.inter(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const FaIcon(
              FontAwesomeIcons.arrowsRotate,
              size: 16,
            ),
            label: Text(
              'RESTART',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _handleTerminateRestart();
    }
  }

  @override
  Widget build(BuildContext context) {
    // final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          widget.title.toUpperCase(),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              // Counter Section
              Center(
                child: Container(
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2A2A2A),
                    border: Border.all(
                      color: const Color(0xFF3A3A3A),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$_counter',
                        style: GoogleFonts.inter(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                          .animate(
                            onPlay: (controller) => controller.repeat(),
                          )
                          .shimmer(
                            duration: 2.seconds,
                            color: Colors.grey[800]!,
                          ),
                      Text(
                        'COUNTER',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[400],
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().scale(),
              const SizedBox(height: 48),

              // Settings Section
              Text(
                'SETTINGS',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  title: Text(
                    'Clear Data',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Reset app data when restarting',
                    style: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                  value: _clearData,
                  onChanged: (value) => setState(() => _clearData = value),
                  activeColor: Colors.greenAccent,
                ),
              ).animate().slideX(begin: -0.2).fadeIn(),
              const SizedBox(height: 48),

              // Restart Options Section
              Text(
                'RESTART OPTIONS',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _handleUIRestart,
                      icon: const FaIcon(
                        FontAwesomeIcons.display,
                        size: 16,
                      ),
                      label: const Text('UI RESTART'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        textStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _handleTerminateRestart,
                      icon: const FaIcon(
                        FontAwesomeIcons.powerOff,
                        size: 16,
                      ),
                      label: const Text('TERMINATE & RESTART'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: const Color(0xFF3A3A3A),
                        foregroundColor: Colors.white,
                        textStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _handleConfirmationRestart,
                      icon: const FaIcon(
                        FontAwesomeIcons.triangleExclamation,
                        size: 16,
                      ),
                      label: const Text('WITH CONFIRMATION'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        foregroundColor: Colors.grey[400],
                        side: BorderSide(color: Colors.grey[800]!),
                        textStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().slideX(begin: 0.2).fadeIn(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.greenAccent,
              Colors.greenAccent.shade400,
            ],
          ),
        ),
        child: FloatingActionButton.large(
          onPressed: _incrementCounter,
          tooltip: 'Increment',
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: const FaIcon(
            FontAwesomeIcons.plus,
            color: Colors.black,
          ),
        ),
      )
          .animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          )
          .scaleXY(
            begin: 1.0,
            end: 1.1,
            duration: 1.seconds,
            curve: Curves.easeInOut,
          ),
    );
  }
}
