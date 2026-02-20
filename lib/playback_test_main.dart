import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'services/base_service.dart';
import 'services/players/jellyfin_service.dart';
import 'services/media_service_manager.dart';
import 'services/audio_service_integration.dart';
import 'services/audio/just_audio_media_kit_ext.dart';
import 'ui/playback_test/playback_test_page.dart';

/// Playback test app entrypoint.
/// Run with: flutter run -t lib/playback_test_main.dart -d linux
///
/// Uses the same configured servers as the main app (SharedPreferences).
/// Select a provider, click Test to connect and play one track.
/// Logs (including player/MPV-related output) are shown in the UI and in the console.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      await PlatformAudioConfig.createMpvConfig();
    }
    JustAudioMediaKitExt.ensureInitialized(
      linux: !Platform.isLinux,
      windows: defaultTargetPlatform == TargetPlatform.windows,
      macOS: defaultTargetPlatform == TargetPlatform.macOS,
    );
  }

  await JellyfinService.initializeVersion();

  runApp(const PlaybackTestApp());
}

class PlaybackTestApp extends StatelessWidget {
  const PlaybackTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doudou Playback Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        useMaterial3: true,
      ),
      home: ChangeNotifierProvider(
        create: (_) => PlaybackTestState(),
        child: const PlaybackTestPage(),
      ),
    );
  }
}

/// State for the playback test: servers list, selected server, connection state, logs.
class PlaybackTestState extends ChangeNotifier {
  static const String _keyConfiguredServers = 'configured_servers';

  List<Map<String, String>> _servers = [];
  Map<String, String>? _selectedServer;
  bool _loading = false;
  String? _error;
  final List<String> _logs = [];
  String _status = '';

  List<Map<String, String>> get servers => List.unmodifiable(_servers);
  Map<String, String>? get selectedServer => _selectedServer;
  bool get loading => _loading;
  String? get error => _error;
  List<String> get logs => List.unmodifiable(_logs);
  String get status => _status;

  set selectedServer(Map<String, String>? value) {
    _selectedServer = value;
    _error = null;
    notifyListeners();
  }

  void _log(String message) {
    final line = '${DateTime.now().toIso8601String().substring(11, 23)} $message';
    _logs.add(line);
    debugPrint(line);
    notifyListeners();
  }

  void _setStatus(String s) {
    _status = s;
    notifyListeners();
  }

  void _setError(String? e) {
    _error = e;
    if (e != null) _log('ERROR: $e');
    notifyListeners();
  }

  Future<void> loadServers() async {
    _log('Loading configured servers...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyConfiguredServers);
      if (json == null) {
        _servers = [];
        _log('No configured servers found. Add servers in the main app first.');
      } else {
        final list = jsonDecode(json) as List<dynamic>? ?? [];
        _servers = list
            .map((e) => (e as Map<String, dynamic>).map(
                  (k, v) => MapEntry(k, v?.toString() ?? ''),
                ))
            .toList();
        _log('Loaded ${_servers.length} server(s).');
      }
      _error = null;
    } catch (e, st) {
      _setError('Failed to load servers: $e');
      _log('$st');
    }
    notifyListeners();
  }

  /// Connect to [server], init audio, fetch one track and play it. Log everything.
  Future<void> testPlayback(Map<String, String> server) async {
    _loading = true;
    _error = null;
    _log('--- Test playback start ---');
    _setStatus('Connecting...');
    notifyListeners();

    MediaServiceManager? mediaManager;
    JellyfinService? jellyfinService;

    try {
      final serverType = server['type'] ?? 'jellyfin';
      var serverUrl = server['url'] ?? '';
      final authMethod = server['authMethod'] ?? 'password';

      if (serverType == 'local') {
        _setError('Local music not supported in this test. Use Jellyfin, Navidrome, Plex, etc.');
        return;
      }

      ServerType type;
      switch (serverType) {
        case 'plex':
          type = ServerType.plex;
          break;
        case 'subsonic':
          type = ServerType.subsonic;
          break;
        case 'soundcloud':
          type = ServerType.soundcloud;
          break;
        case 'youtubeMusic':
          type = ServerType.youtubeMusic;
          break;
        default:
          type = ServerType.jellyfin;
      }

      _log('Provider: $serverType ($type)');
      _log('URL: $serverUrl');

      if (type != ServerType.plex &&
          type != ServerType.local &&
          type != ServerType.soundcloud &&
          type != ServerType.youtubeMusic &&
          !serverUrl.startsWith('http://') &&
          !serverUrl.startsWith('https://')) {
        serverUrl = 'http://$serverUrl';
      }
      if (type == ServerType.soundcloud &&
          (serverUrl.isEmpty || !serverUrl.startsWith('http'))) {
        serverUrl = 'https://api.soundcloud.com';
      }
      if (type == ServerType.youtubeMusic &&
          (serverUrl.isEmpty || !serverUrl.startsWith('http'))) {
        serverUrl = 'https://music.youtube.com';
      }

      if (type == ServerType.jellyfin) {
        jellyfinService = JellyfinService();
        mediaManager = MediaServiceManager.withJellyfinService(jellyfinService);
        mediaManager.initializeService(ServerType.jellyfin);
        mediaManager.setServerId(server['id']);
        mediaManager.setServer(serverUrl);
        if (authMethod == 'api_key' && server['apiKey'] != null) {
          _log('Authenticating with API key...');
          final ok = await jellyfinService
              .authenticateWithApiKey(serverUrl, server['apiKey']!)
              .timeout(const Duration(seconds: 10));
          if (!ok) {
            _setError('Jellyfin API key authentication failed');
            return;
          }
          mediaManager.setAuthenticatedJellyfinService(jellyfinService);
          _log('Jellyfin authenticated (API key).');
        } else {
          final identifier = server['identifier'] ?? '';
          final credential = server['credential'] ?? '';
          _log('Authenticating with password...');
          final ok = await mediaManager
              .authenticate(serverUrl, identifier, credential)
              .timeout(const Duration(seconds: 10));
          if (!ok) {
            _setError('Authentication failed');
            return;
          }
          _log('Jellyfin authenticated (password).');
        }
      } else {
        mediaManager = MediaServiceManager();
        mediaManager.initializeService(type);
        mediaManager.setServerId(server['id']);
        mediaManager.setServer(serverUrl);
        final identifier = server['identifier'] ?? '';
        final credential = server['credential'] ?? '';
        _log('Authenticating...');
        final ok = await mediaManager
            .authenticate(serverUrl, identifier, credential)
            .timeout(const Duration(seconds: 10));
        if (!ok) {
          _setError('Authentication failed');
          return;
        }
        _log('Authenticated.');
      }

      _setStatus('Initializing audio...');
      _log('Initializing audio service...');
      final audioService = AudioServiceIntegration.instance;
      await audioService.initialize(mediaManager);
      _log('Audio service initialized. Platform: ${audioService.platformType}');

      _setStatus('Fetching a track...');
      final tracks = await mediaManager.getTracks(limit: 1);
      if (tracks.isEmpty) {
        final starred = await mediaManager.getStarredTracks();
        if (starred.isEmpty) {
          _setError('No tracks found. Add some music to the server.');
          return;
        }
        _log('Using first starred track.');
        final track = starred.first;
        _log('Playing: ${track.name} (${track.id})');
        _setStatus('Playing: ${track.name}');
        await audioService.playTrack(track);
      } else {
        final track = tracks.first;
        _log('Playing: ${track.name} (${track.id})');
        _setStatus('Playing: ${track.name}');
        await audioService.playTrack(track);
      }

      _log('Play requested. Check console for [Playback] and player logs.');
      _setStatus('Playing. Watch logs below and in console.');
    } catch (e, st) {
      _setError('$e');
      _log('Stack: $st');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }
}
