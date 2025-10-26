import 'package:audio_service/audio_service.dart';

/// Common interface for all audio handlers in the app
abstract class AppAudioHandler {
  /// Set volume normalization
  void setNormalizeVolume(bool enabled);
  
  /// Set gapless playback
  void setGaplessPlayback(bool enabled);
  
  /// Get the underlying BaseAudioHandler for audio service integration
  BaseAudioHandler get handler;
}