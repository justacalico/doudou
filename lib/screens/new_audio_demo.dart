import 'package:flutter/material.dart';
import '../services/audio_service_integration.dart';
import '../services/media_service_manager.dart';


/// Simple demo of the new audio system
class NewAudioDemo extends StatefulWidget {
  final MediaServiceManager mediaServiceManager;

  const NewAudioDemo({
    Key? key,
    required this.mediaServiceManager,
  }) : super(key: key);

  @override
  State<NewAudioDemo> createState() => _NewAudioDemoState();
}

class _NewAudioDemoState extends State<NewAudioDemo> {
  bool _isInitialized = false;
  String _status = 'Not initialized';
  String _platformType = 'unknown';

  @override
  void initState() {
    super.initState();
    _initializeAudioSystem();
  }

  Future<void> _initializeAudioSystem() async {
    try {
      setState(() {
        _status = 'Initializing...';
      });

      final audioService = AudioServiceIntegration.instance;
      await audioService.initialize(widget.mediaServiceManager);
      
      setState(() {
        _isInitialized = audioService.isInitialized;
        _platformType = audioService.platformType;
        _status = _isInitialized ? 'Ready' : 'Failed to initialize';
      });

      print('New audio system initialized successfully for platform: $_platformType');
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isInitialized = false;
      });
      print('Failed to initialize new audio system: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Audio System Demo'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio System Status',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('Platform: $_platformType'),
                    Text('Status: $_status'),
                    Text('Initialized: ${_isInitialized ? '✅' : '❌'}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            if (_isInitialized) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audio Handler Information',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text('Handler Type: ${AudioServiceIntegration.instance.audioHandler?.runtimeType ?? 'Unknown'}'),
                      const SizedBox(height: 16),
                      
                      Text(
                        'Available Methods:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text('• playTrack(Track)'),
                      const Text('• playPlaylist(List<Track>, startIndex)'),
                      const Text('• playPause()'),
                      const Text('• skipToNext()'),
                      const Text('• skipToPrevious()'),
                      const Text('• setVolume(double)'),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Platform-Specific Features',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      
                      if (_platformType == 'web') ...[
                        const Text('✅ Web Audio API integration'),
                        const Text('✅ Browser media controls (when supported)'),
                        const Text('✅ Direct just_audio playback'),
                      ] else if (_platformType == 'android' || _platformType == 'ios') ...[
                        const Text('✅ AudioService background playback'),
                        const Text('✅ System media controls'),
                        const Text('✅ Lock screen controls'),
                        const Text('✅ Notification controls'),
                      ] else if (_platformType == 'linux' || _platformType == 'macos' || _platformType == 'windows') ...[
                        const Text('✅ Media Kit enhanced codec support'),
                        const Text('✅ Native desktop integration'),
                        const Text('✅ Hardware media key support'),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            
            const Spacer(),
            
            if (_isInitialized)
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Audio system ready for $_platformType platform!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Audio System Ready!'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              )
            else
              Center(
                child: ElevatedButton.icon(
                  onPressed: _initializeAudioSystem,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Initialization'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Note: We don't dispose the global audio service here as it might be used elsewhere
    super.dispose();
  }
}