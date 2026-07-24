import 'package:audio_service/audio_service.dart';
import 'package:doudou/models/quick_picks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuickPicks', () {
    test('defaults title to "Discover"', () {
      final picks = QuickPicks([]);

      expect(picks.title, 'Discover');
      expect(picks.songList, isEmpty);
    });

    test('stores custom title and song list', () {
      final songs = [
        MediaItem(id: '1', title: 'A'),
        MediaItem(id: '2', title: 'B'),
      ];
      final picks = QuickPicks(songs, title: 'Recommended');

      expect(picks.title, 'Recommended');
      expect(picks.songList.length, 2);
    });

    test('songList is mutable', () {
      final picks = QuickPicks([]);

      picks.songList.add(MediaItem(id: 'x', title: 'X'));

      expect(picks.songList.length, 1);
    });
  });
}
