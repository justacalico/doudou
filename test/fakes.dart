import 'package:audio_service/audio_service.dart';
import 'package:doudou/models/server.dart';
import 'package:doudou/services/music_service.dart';
import 'package:doudou/services/playback_diagnostics_service.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

class Call {
  Call(this.name, this.extras);
  final String name;
  final Map<String, dynamic>? extras;

  T? extra<T>(String key) {
    final value = extras?[key];
    if (value is T) return value;
    return null;
  }
}

class FakeAudioHandler extends BaseAudioHandler {
  final calls = <Call>[];

  void _record(String name, [Map<String, dynamic>? extras]) {
    calls.add(Call(name, extras));
  }

  @override
  Future<void> play() async => _record('play');

  @override
  Future<void> pause() async => _record('pause');

  @override
  Future<void> skipToNext() async => _record('skipToNext');

  @override
  Future<void> skipToPrevious() async => _record('skipToPrevious');

  @override
  Future<void> seek(Duration position) async =>
      _record('seek', {'position': position});

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async =>
      _record('addQueueItem', {'mediaItem': mediaItem});

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async =>
      _record('addQueueItems', {'mediaItems': mediaItems});

  @override
  Future<void> updateQueue(List<MediaItem> queue) async =>
      _record('updateQueue', {'queue': queue});

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async =>
      _record('removeQueueItem', {'mediaItem': mediaItem});

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async =>
      _record('setShuffleMode', {'shuffleMode': shuffleMode});

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async =>
      _record('setRepeatMode', {'repeatMode': repeatMode});

  @override
  Future<dynamic> customAction(String name,
          [Map<String, dynamic>? extras]) async =>
      _record(name, extras);
}

class FakeMusicServices extends MusicServices {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class DiagCall {
  DiagCall({
    required this.category,
    required this.message,
    this.songId,
    this.backendType,
    this.activeServerType,
    this.data,
  });

  final String category;
  final String message;
  final String? songId;
  final String? backendType;
  final String? activeServerType;
  final Map<String, dynamic>? data;
}

class FakePlaybackDiagnosticsService extends PlaybackDiagnosticsService {
  final calls = <DiagCall>[];

  @override
  bool get enabled => false;

  @override
  void logEvent({
    required String category,
    required String message,
    String? songId,
    String? backendType,
    String? activeServerType,
    Map<String, dynamic>? data,
  }) {
    calls.add(DiagCall(
      category: category,
      message: message,
      songId: songId,
      backendType: backendType,
      activeServerType: activeServerType,
      data: data,
    ));
  }
}

class FakeSettingsScreenController extends SettingsScreenController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  SettingsServer? get activeServer => SettingsServer(
        id: 0,
        name: 'Test',
        type: ServerType.youtubeMusic,
      );
}
