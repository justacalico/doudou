import '../../models/server.dart';
import 'jellyfin_backend.dart';
import 'music_backend.dart';
import 'plex_backend.dart';
import 'subsonic_backend.dart';
import 'youtube_music_backend.dart';

MusicBackend createBackend(SettingsServer server) {
  switch (server.type) {
    case ServerType.youtubeMusic:
      return YouTubeMusicBackend();
    case ServerType.jellyfin:
      return JellyfinBackend(server);
    case ServerType.subsonic:
      return SubsonicBackend(server);
    case ServerType.plex:
      return PlexBackend(server);
  }
}
