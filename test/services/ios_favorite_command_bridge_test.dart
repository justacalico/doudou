import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/services/ios_favorite_command_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'doudou/test_lockscreen_favorite';
  const codec = StandardMethodCodec();

  late MethodChannel channel;
  late List<MethodCall> sentCalls;
  late Rx<bool> isFavorite;
  late Rx<MediaItem?> currentSong;
  late StreamController<PlaybackState> playbackStates;
  late int toggleCount;
  late IosFavoriteCommandBridge bridge;

  MediaItem song(String id) => MediaItem(id: id, title: 'Song $id');

  setUp(() {
    channel = const MethodChannel(channelName);
    sentCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      sentCalls.add(call);
      return null;
    });
    isFavorite = false.obs;
    currentSong = Rx<MediaItem?>(null);
    playbackStates = StreamController<PlaybackState>.broadcast();
    toggleCount = 0;
    bridge = IosFavoriteCommandBridge(
      isFavorite: isFavorite,
      currentSong: currentSong,
      playbackState: playbackStates.stream,
      onToggleFavorite: () async {
        toggleCount++;
        isFavorite.value = !isFavorite.value;
      },
      channel: channel,
    );
  });

  tearDown(() {
    bridge.dispose();
    playbackStates.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> sendPlatformMessage(String method) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channelName,
      codec.encodeMethodCall(MethodCall(method)),
      (_) {},
    );
    await pumpEventQueue();
  }

  List<MethodCall> statePushes() =>
      sentCalls.where((c) => c.method == 'setFavoriteState').toList();

  group('state pushes', () {
    test('pushes a disabled state on start while no song is playing',
        () async {
      bridge.start();
      await pumpEventQueue();

      final pushes = statePushes();
      expect(pushes, hasLength(1));
      expect(pushes.single.arguments, {'enabled': false, 'active': false});
    });

    test('pushes an inactive favourite state when a song starts', () async {
      bridge.start();
      currentSong.value = song('a');
      await pumpEventQueue();

      expect(statePushes().last.arguments,
          {'enabled': true, 'active': false});
    });

    test('pushes an active state when the song is a favourite', () async {
      bridge.start();
      currentSong.value = song('a');
      isFavorite.value = true;
      await pumpEventQueue();

      expect(statePushes().last.arguments, {'enabled': true, 'active': true});
    });

    test('disables the button again when the song is cleared', () async {
      bridge.start();
      currentSong.value = song('a');
      isFavorite.value = true;
      currentSong.value = null;
      await pumpEventQueue();

      expect(statePushes().last.arguments,
          {'enabled': false, 'active': false});
    });

    test('re-pushes state when playback starts', () async {
      bridge.start();
      currentSong.value = song('a');
      isFavorite.value = true;
      await pumpEventQueue();
      final pushesBefore = statePushes().length;

      // simulates audio_service's setState that disables the feedback
      // commands when the command center is activated
      playbackStates.add(PlaybackState(playing: true));
      await pumpEventQueue();

      expect(statePushes().length, pushesBefore + 1);
      expect(statePushes().last.arguments, {'enabled': true, 'active': true});
    });

    test('does not re-push for identical playback states', () async {
      bridge.start();
      await pumpEventQueue();
      final pushesBefore = statePushes().length;

      playbackStates.add(PlaybackState(playing: true));
      playbackStates.add(PlaybackState(playing: true));
      await pumpEventQueue();

      expect(statePushes().length, pushesBefore + 1);
    });
  });

  group('lock screen presses', () {
    test('toggles the favourite when the lock screen button is pressed',
        () async {
      bridge.start();
      currentSong.value = song('a');
      await pumpEventQueue();

      await sendPlatformMessage('onFavoritePressed');

      expect(toggleCount, 1);
      expect(isFavorite.value, isTrue);
      expect(statePushes().last.arguments,
          {'enabled': true, 'active': true});
    });

    test('ignores presses while no song is playing', () async {
      bridge.start();
      await pumpEventQueue();

      await sendPlatformMessage('onFavoritePressed');

      expect(toggleCount, 0);
    });

    test('ignores unknown method calls', () async {
      bridge.start();
      currentSong.value = song('a');
      await pumpEventQueue();

      await sendPlatformMessage('somethingElse');

      expect(toggleCount, 0);
    });
  });

  group('dispose', () {
    test('stops pushing state after dispose', () async {
      bridge.start();
      currentSong.value = song('a');
      await pumpEventQueue();
      final pushesBefore = statePushes().length;

      bridge.dispose();
      isFavorite.value = true;
      currentSong.value = song('b');
      await pumpEventQueue();

      expect(statePushes().length, pushesBefore);
    });
  });
}
