/// Global Audio System - Main entry point
/// 
/// This library provides a unified, platform-agnostic audio playback system.
/// 
/// ## Getting Started
/// 
/// ```dart
/// import 'package:doudou/services/audio/global/global_audio.dart';
/// 
/// // Initialize at app startup
/// await AudioManager.initialize(
///   adapterFactory: JustAudioAdapterFactory(),
///   mediaServiceManager: mediaServiceManager,
/// );
/// 
/// // Use the audio manager
/// await AudioManager.instance.playTrack(track);
/// ```
/// 
/// ## Architecture
/// 
/// - [AudioManager] - Singleton that manages all audio playback
/// - [AudioState] - Immutable state objects representing current audio state
/// - [PlatformAudioAdapter] - Interface for platform-specific implementations
/// - [JustAudioAdapter] - Default implementation using just_audio package
/// 
/// ## Key Features
/// 
/// - Thread-safe operation queue prevents race conditions
/// - Immutable state objects ensure consistency
/// - Automatic retry logic for transient failures
/// - Proper error handling with graceful degradation
/// - Platform-agnostic design
library global_audio;

// Core classes
export 'audio_state.dart';
export 'audio_manager.dart';
export 'audio_operation_queue.dart';

// Platform adapters
export 'platform_audio_adapter.dart';
export 'just_audio_adapter.dart';

// Integration with existing app
export 'audio_manager_integration.dart';
