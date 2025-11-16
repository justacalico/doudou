import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import '../../providers/app_state.dart';
import '../widgets/vr_player_controls.dart';
import '../widgets/vr_3d_environment.dart';
import '../services/vr_scene_manager.dart';
import 'dart:async';

/// VR Player Screen for Google Cardboard
/// 
/// This screen provides a full 360-degree 3D environment with stereoscopic viewing
/// and head tracking support for an immersive music experience.
class VRPlayerScreen extends StatefulWidget {
  const VRPlayerScreen({super.key});

  @override
  State<VRPlayerScreen> createState() => _VRPlayerScreenState();
}

class _VRPlayerScreenState extends State<VRPlayerScreen> {
  late VRSceneManager _sceneManager;
  Timer? _updateTimer;
  bool _showControls = true;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize 3D scene manager
    _sceneManager = VRSceneManager();
    _sceneManager.initialize();
    
    // Set landscape orientation for VR mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Hide system UI for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // Start update loop for scene rendering
    _updateTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (mounted) {
        setState(() {}); // Trigger rebuild for head tracking updates
      }
    });
    
    // Auto-hide controls after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _sceneManager.dispose();
    
    // Restore normal orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
  
  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }
  
  void _recenterView() {
    _sceneManager.calibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('View recentered'),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.purple,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Consumer<AppState>(
          builder: (context, appState, child) {
            return StreamBuilder<MediaItem?>(
              stream: appState.mediaItem,
              builder: (context, snapshot) {
                final mediaItem = snapshot.data;
                final albumArtUrl = mediaItem?.artUri?.toString();
                
                if (mediaItem == null) {
                  return _buildNoTrackView();
                }

                return Row(
                  children: [
                    // Left Eye View - 360° 3D Environment
                    Expanded(
                      child: _build3DEnvironment(
                        context, 
                        appState, 
                        albumArtUrl: albumArtUrl,
                        mediaItem: mediaItem,
                        isLeftEye: true,
                      ),
                    ),
                    // Right Eye View - 360° 3D Environment
                    Expanded(
                      child: _build3DEnvironment(
                        context, 
                        appState, 
                        albumArtUrl: albumArtUrl,
                        mediaItem: mediaItem,
                        isLeftEye: false,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _build3DEnvironment(
    BuildContext context,
    AppState appState, {
    required String? albumArtUrl,
    required MediaItem mediaItem,
    required bool isLeftEye,
  }) {
    return Stack(
      children: [
        // 360-degree 3D environment with head tracking
        VR3DEnvironment(
          sceneManager: _sceneManager,
          albumArtUrl: albumArtUrl,
          isLeftEye: isLeftEye,
        ),
        
        // Overlay controls (only show when toggled)
        if (_showControls)
          _buildControlsOverlay(context, appState, mediaItem),
      ],
    );
  }

  Widget _buildControlsOverlay(
    BuildContext context,
    AppState appState,
    MediaItem mediaItem,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top bar with track info and recenter button
          _buildTopBar(mediaItem),
          
          // Bottom bar with controls
          _buildBottomBar(context, appState),
        ],
      ),
    );
  }

  Widget _buildTopBar(MediaItem mediaItem) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mediaItem.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (mediaItem.artist != null)
                    Text(
                      mediaItem.artist!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Recenter button
            IconButton(
              onPressed: _recenterView,
              icon: const Icon(Icons.center_focus_strong),
              color: Colors.white,
              iconSize: 28,
              tooltip: 'Recenter View',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, AppState appState) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Player controls
            VRPlayerControls(appState: appState),
            
            const SizedBox(height: 16),
            
            // Exit button
            _buildExitButton(context),
          ],
        ),
      ),
    );
  }



  Widget _buildNoTrackView() {
    return Center(
      child: Row(
        children: [
          // Left Eye
          Expanded(
            child: _buildNoTrackContent(),
          ),
          // Right Eye
          Expanded(
            child: _buildNoTrackContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTrackContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.music_off,
          size: 80,
          color: Colors.white.withOpacity(0.5),
        ),
        const SizedBox(height: 20),
        Text(
          'No track playing',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 24,
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 80),
        _buildExitButton(null),
      ],
    );
  }

  Widget _buildExitButton(BuildContext? context) {
    return ElevatedButton.icon(
      onPressed: () {
        if (context != null) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(this.context).pop();
        }
      },
      icon: const Icon(Icons.exit_to_app, size: 20),
      label: const Text(
        'Exit VR Mode',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }
}
