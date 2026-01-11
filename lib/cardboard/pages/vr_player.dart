import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import '../../providers/app_state.dart';
import '../widgets/vr_player_controls.dart';
import '../widgets/vr_album_art.dart';

/// VR Player Screen for Google Cardboard
///
/// This screen provides a stereoscopic 3D view optimized for Google Cardboard.
/// The UI is split into left and right eye views with appropriate spacing for VR headsets.
class VRPlayerScreen extends StatefulWidget {
  const VRPlayerScreen({super.key});

  @override
  State<VRPlayerScreen> createState() => _VRPlayerScreenState();
}

class _VRPlayerScreenState extends State<VRPlayerScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return StreamBuilder<MediaItem?>(
            stream: appState.mediaItem,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == null) {
                return _buildNoTrackView();
              }

              return Row(
                children: [
                  Expanded(
                    child: _buildEyeView(context, appState, isLeftEye: true),
                  ),
                  Expanded(
                    child: _buildEyeView(context, appState, isLeftEye: false),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEyeView(
    BuildContext context,
    AppState appState, {
    required bool isLeftEye,
  }) {
    return StreamBuilder<MediaItem?>(
      stream: appState.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) {
          return _buildNoTrackContent();
        }

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black,
                Colors.purple.shade900.withOpacity(0.3),
                Colors.black,
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 1),

              VRAlbumArt(imageUrl: mediaItem.artUri?.toString(), size: 200),

              const SizedBox(height: 40),

              _buildMediaItemInfo(mediaItem),

              const Spacer(flex: 1),

              VRPlayerControls(appState: appState),

              const SizedBox(height: 60),

              _buildExitButton(context),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaItemInfo(MediaItem mediaItem) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            mediaItem.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 12),

          if (mediaItem.artist != null)
            Text(
              mediaItem.artist!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 20,
                fontWeight: FontWeight.w300,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

          const SizedBox(height: 8),

          if (mediaItem.album != null)
            Text(
              mediaItem.album!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
                fontWeight: FontWeight.w300,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildNoTrackView() {
    return Center(
      child: Row(
        children: [
          Expanded(child: _buildNoTrackContent()),
          Expanded(child: _buildNoTrackContent()),
        ],
      ),
    );
  }

  Widget _buildNoTrackContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.music_off, size: 80, color: Colors.white.withOpacity(0.5)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }
}
