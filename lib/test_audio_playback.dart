// Minimal test app to verify desktop audio playback.
// Run: flutter run -t lib/test_audio_playback.dart
// If you hear audio when pressing "Play (concat)" or "Play (single URI)", playback works.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'services/audio/just_audio_media_kit_ext.dart';

// #region agent log
void _log(String message, Map<String, dynamic> data, {String? hypothesisId}) {
  try {
    final logFile = File('/mnt/FUCKICE/Code/gitlab/Openlyst/doudou/.cursor/debug-5d0505.log');
    final entry = {
      'sessionId': '5d0505',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'location': 'test_audio_playback.dart',
      'message': message,
      'data': data,
      if (hypothesisId != null) 'hypothesisId': hypothesisId,
    };
    logFile.writeAsStringSync('${jsonEncode(entry)}\n', mode: FileMode.append);
  } catch (e) {
    debugPrint('Log write failed: $e');
  }
}
// #endregion

// Public short test MP3 (no auth)
const _defaultTestUrl =
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    // On Linux, create minimal MPV config with audio output auto-detection
    if (defaultTargetPlatform == TargetPlatform.linux) {
      try {
        final home = Platform.environment['HOME'];
        if (home != null) {
          final configDir = Directory('$home/.config/mpv');
          if (!await configDir.exists()) await configDir.create(recursive: true);
          final configFile = File('${configDir.path}/mpv.conf');
          String existingContent = '';
          if (await configFile.exists()) {
            existingContent = await configFile.readAsString();
          }
          // Add ao=auto if not present
          if (!existingContent.contains('ao=')) {
            await configFile.writeAsString(
              '${existingContent.isEmpty ? '' : '$existingContent\n'}# Test: auto-detect audio output\nao=auto\n',
              mode: FileMode.write,
            );
            debugPrint('Test: Created MPV config with ao=auto');
          }
        }
      } catch (e) {
        debugPrint('Test: Failed to create MPV config: $e');
      }
    }
    JustAudioMediaKitExt.ensureInitialized();
  }

  runApp(const MaterialApp(
    home: _TestAudioPlaybackPage(),
    debugShowCheckedModeBanner: false,
  ));
}

class _TestAudioPlaybackPage extends StatefulWidget {
  const _TestAudioPlaybackPage();

  @override
  State<_TestAudioPlaybackPage> createState() => _TestAudioPlaybackPageState();
}

class _TestAudioPlaybackPageState extends State<_TestAudioPlaybackPage> {
  final _urlController = TextEditingController(text: _defaultTestUrl);
  final _player = AudioPlayer();
  String _status = 'Idle';
  String? _error;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  @override
  void initState() {
    super.initState();
    // #region agent log
    _playerStateSub = _player.playerStateStream.listen((state) {
      _log('Player state changed', {
        'processingState': state.processingState.toString(),
        'playing': state.playing,
      }, hypothesisId: 'B');
    });
    _positionSub = _player.positionStream.listen((pos) {
      _log('Position update', {
        'positionMs': pos.inMilliseconds,
      }, hypothesisId: 'D');
    });
    _durationSub = _player.durationStream.listen((dur) {
      _log('Duration update', {
        'durationMs': dur?.inMilliseconds,
      }, hypothesisId: 'A');
    });
    // #endregion
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _urlController.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _playWithConcat() async {
    setState(() {
      _error = null;
      _status = 'Loading (concat source)...';
    });
    try {
      // #region agent log
      _log('_playWithConcat: starting', {}, hypothesisId: 'A');
      // #endregion
      await _player.stop();
      final url = _urlController.text.trim();
      if (url.isEmpty) {
        setState(() {
          _error = 'Enter a URL';
          _status = 'Idle';
        });
        return;
      }
      // #region agent log
      _log('_playWithConcat: before setAudioSource', {'url': url, 'volume': _player.volume}, hypothesisId: 'A');
      // #endregion
      final source = ConcatenatingAudioSource(
        children: [AudioSource.uri(Uri.parse(url))],
      );
      await _player.setAudioSource(source).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('setAudioSource', const Duration(seconds: 15)),
          );
      // #region agent log
      _log('_playWithConcat: after setAudioSource', {
        'processingState': _player.processingState.toString(),
        'playing': _player.playing,
        'durationMs': _player.duration?.inMilliseconds,
      }, hypothesisId: 'A');
      // #endregion
      // #region agent log
      _log('_playWithConcat: before play()', {
        'processingState': _player.processingState.toString(),
        'playing': _player.playing,
        'volume': _player.volume,
      }, hypothesisId: 'B');
      // #endregion
      await _player.play().timeout(const Duration(seconds: 5));
      // #region agent log
      _log('_playWithConcat: after play()', {
        'processingState': _player.processingState.toString(),
        'playing': _player.playing,
        'positionMs': _player.position.inMilliseconds,
        'durationMs': _player.duration?.inMilliseconds,
      }, hypothesisId: 'B');
      // #endregion
      // Wait 2 seconds and check if position advanced
      await Future.delayed(const Duration(seconds: 2));
      // #region agent log
      _log('_playWithConcat: 2s after play()', {
        'processingState': _player.processingState.toString(),
        'playing': _player.playing,
        'positionMs': _player.position.inMilliseconds,
        'durationMs': _player.duration?.inMilliseconds,
      }, hypothesisId: 'D');
      // #endregion
      setState(() {
        _status = 'Playing (concat) — you should hear audio';
        _error = null;
      });
    } catch (e, st) {
      // #region agent log
      _log('_playWithConcat: ERROR', {'error': e.toString(), 'stackTrace': st.toString()}, hypothesisId: 'E');
      // #endregion
      setState(() {
        _error = '$e';
        _status = 'Error';
      });
      debugPrint('Play (concat) error: $e\n$st');
    }
  }

  Future<void> _playWithSingleUri() async {
    setState(() {
      _error = null;
      _status = 'Loading (single URI)...';
    });
    try {
      // #region agent log
      _log('_playWithSingleUri: starting', {}, hypothesisId: 'A');
      // #endregion
      await _player.stop();
      final url = _urlController.text.trim();
      if (url.isEmpty) {
        setState(() {
          _error = 'Enter a URL';
          _status = 'Idle';
        });
        return;
      }
      // #region agent log
      _log('_playWithSingleUri: before setAudioSource', {'url': url, 'volume': _player.volume}, hypothesisId: 'A');
      // #endregion
      await _player
          .setAudioSource(AudioSource.uri(Uri.parse(url)))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('setAudioSource', const Duration(seconds: 15)),
          );
      // #region agent log
      _log('_playWithSingleUri: after setAudioSource', {
        'processingState': _player.processingState.toString(),
        'playing': _player.playing,
        'durationMs': _player.duration?.inMilliseconds,
      }, hypothesisId: 'A');
      // #endregion
      // #region agent log
      _log('_playWithSingleUri: before play()', {
        'processingState': _player.processingState.toString(),
        'playing': _player.playing,
        'volume': _player.volume,
      }, hypothesisId: 'B');
      // #endregion
      await _player.play().timeout(const Duration(seconds: 5));
      // #region agent log
      _log('_playWithSingleUri: after play()', {
        'processingState': _player.processingState.toString(),
        'playing': _player.playing,
        'positionMs': _player.position.inMilliseconds,
        'durationMs': _player.duration?.inMilliseconds,
      }, hypothesisId: 'B');
      // #endregion
      // Wait 2 seconds and check if position advanced
      await Future.delayed(const Duration(seconds: 2));
      // #region agent log
      _log('_playWithSingleUri: 2s after play()', {
        'processingState': _player.processingState.toString(),
        'playing': _player.playing,
        'positionMs': _player.position.inMilliseconds,
        'durationMs': _player.duration?.inMilliseconds,
      }, hypothesisId: 'D');
      // #endregion
      setState(() {
        _status = 'Playing (single URI) — you should hear audio';
        _error = null;
      });
    } catch (e, st) {
      // #region agent log
      _log('_playWithSingleUri: ERROR', {'error': e.toString(), 'stackTrace': st.toString()}, hypothesisId: 'E');
      // #endregion
      setState(() {
        _error = '$e';
        _status = 'Error';
      });
      debugPrint('Play (single URI) error: $e\n$st');
    }
  }

  Future<void> _stop() async {
    await _player.stop();
    setState(() {
      _status = 'Stopped';
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio playback test')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Same init as main app (JustAudioMediaKitExt). '
              'Use default URL or paste your Jellyfin/Navidrome stream URL.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Stream URL',
                border: OutlineInputBorder(),
                hintText: _defaultTestUrl,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _playWithConcat,
                  child: const Text('Play (concat)'),
                ),
                ElevatedButton(
                  onPressed: _playWithSingleUri,
                  child: const Text('Play (single URI)'),
                ),
                OutlinedButton(
                  onPressed: _stop,
                  child: const Text('Stop'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _status,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
