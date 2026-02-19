// Minimal test app to verify desktop audio playback.
// Run: flutter run -t lib/test_audio_playback.dart
// If you hear audio when pressing "Play (concat)" or "Play (single URI)", playback works.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'services/audio/just_audio_media_kit_ext.dart';

// Public short test MP3 (no auth)
const _defaultTestUrl =
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
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

  @override
  void dispose() {
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
      await _player.stop();
      final url = _urlController.text.trim();
      if (url.isEmpty) {
        setState(() {
          _error = 'Enter a URL';
          _status = 'Idle';
        });
        return;
      }
      final source = ConcatenatingAudioSource(
        children: [AudioSource.uri(Uri.parse(url))],
      );
      await _player.setAudioSource(source).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('setAudioSource', const Duration(seconds: 15)),
          );
      await _player.play().timeout(const Duration(seconds: 5));
      setState(() {
        _status = 'Playing (concat) — you should hear audio';
        _error = null;
      });
    } catch (e, st) {
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
      await _player.stop();
      final url = _urlController.text.trim();
      if (url.isEmpty) {
        setState(() {
          _error = 'Enter a URL';
          _status = 'Idle';
        });
        return;
      }
      await _player
          .setAudioSource(AudioSource.uri(Uri.parse(url)))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('setAudioSource', const Duration(seconds: 15)),
          );
      await _player.play().timeout(const Duration(seconds: 5));
      setState(() {
        _status = 'Playing (single URI) — you should hear audio';
        _error = null;
      });
    } catch (e, st) {
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
