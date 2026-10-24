import 'dart:async' show Completer;

import 'package:audio_service/audio_service.dart';
import 'package:doudou/app/settings/app_settings_controller.dart';
import 'package:doudou/models/playlist.dart';
import 'package:doudou/services/discord_rpc_service.dart';
import 'package:doudou/services/downloader.dart';
import 'package:doudou/services/library_sync_service.dart';
import 'package:doudou/services/mcp_server_service.dart';
import 'package:doudou/services/music_service.dart';
import 'package:doudou/services/piped_service.dart';
import 'package:doudou/services/playback_diagnostics_service.dart';
import 'package:doudou/services/server_sync_service.dart';
import 'package:doudou/services/tv_service.dart';
import 'package:doudou/ui/player/player_controller.dart';
import 'package:doudou/ui/screens/Album/album_screen_controller.dart';
import 'package:doudou/ui/screens/Artists/artist_screen_controller.dart';
import 'package:doudou/ui/screens/Home/home_screen_controller.dart';
import 'package:doudou/ui/screens/Library/library_controller.dart';
import 'package:doudou/ui/screens/Playlist/playlist_screen_controller.dart';
import 'package:doudou/ui/screens/Search/search_result_screen_controller.dart';
import 'package:doudou/ui/screens/Search/search_screen_controller.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:doudou/ui/shell_controller.dart';
import 'package:doudou/ui/utils/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../fakes.dart';

class GoldenPlayerController extends PlayerController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  // ignore: must_call_super
  void onReady() {}
}

class GoldenDeps {
  GoldenDeps({required this.player, required this.audio});

  final PlayerController player;
  final FakeAudioHandler audio;
}

class FakeHomeScreenController extends HomeScreenController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class FakeLibraryPlaylistsController extends LibraryPlaylistsController {
  FakeLibraryPlaylistsController([List<Playlist>? extra])
      : extraPlaylists = extra ?? [];

  final List<Playlist> extraPlaylists;

  static final builtins = <Playlist>[
    Playlist(
        title: 'Recently played',
        playlistId: 'LIBRP',
        thumbnailUrl: Playlist.thumbPlaceholderUrl,
        isCloudPlaylist: false),
    Playlist(
        title: 'Favourites',
        playlistId: 'LIBFAV',
        thumbnailUrl: Playlist.thumbPlaceholderUrl,
        isCloudPlaylist: false),
    Playlist(
        title: 'Cached or offline',
        playlistId: 'SongsCache',
        thumbnailUrl: Playlist.thumbPlaceholderUrl,
        isCloudPlaylist: false),
    Playlist(
        title: 'Downloads',
        playlistId: 'SongDownloads',
        thumbnailUrl: Playlist.thumbPlaceholderUrl,
        isCloudPlaylist: false),
  ];

  @override
  List<Playlist> get initPlst => builtins;

  @override
  // ignore: must_call_super
  void onInit() {
    libraryPlaylists = RxList([...builtins, ...extraPlaylists]);
    controller = AnimationController(
        vsync: this, duration: const Duration(seconds: 5));
    isContentFetched.value = true;
  }
}

class FakeLibraryAlbumsController extends LibraryAlbumsController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class FakeLibraryArtistsController extends LibraryArtistsController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class FakeSearchScreenController extends SearchScreenController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class FakePlaylistScreenController extends PlaylistScreenController {
  late final AnimationController _anim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _heightAnim;

  @override
  // ignore: must_call_super
  void onInit() {
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))..forward();
    _scaleAnim = Tween<double>(begin: 0, end: 1).animate(_anim);
    _heightAnim = Tween<double>(begin: 10, end: 75).animate(
        CurvedAnimation(parent: _anim, curve: Curves.easeOutBack));
  }

  @override
  AnimationController get animationController => _anim;
  @override
  Animation<double> get scaleAnimation => _scaleAnim;
  @override
  Animation<double> get heightAnimation => _heightAnim;
}

class FakeAlbumScreenController extends AlbumScreenController {
  late final AnimationController _anim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _heightAnim;

  @override
  // ignore: must_call_super
  void onInit() {
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))..forward();
    _scaleAnim = Tween<double>(begin: 0, end: 1).animate(_anim);
    _heightAnim = Tween<double>(begin: 10, end: 75).animate(
        CurvedAnimation(parent: _anim, curve: Curves.easeOutBack));
  }

  @override
  AnimationController get animationController => _anim;
  @override
  Animation<double> get scaleAnimation => _scaleAnim;
  @override
  Animation<double> get heightAnimation => _heightAnim;
}

class FakeArtistScreenController extends ArtistScreenController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class FakeSearchResultScreenController
    extends SearchResultScreenController {
  @override
  // ignore: must_call_super
  void onReady() {}
}

class GoldenMusicServices extends FakeMusicServices {
  bool hangHome = false;

  @override
  Future<dynamic> getHome({int limit = 4}) =>
      hangHome ? Completer<dynamic>().future : Future.value(<dynamic>[]);
}

class GoldenSettingsScreenController extends FakeSettingsScreenController {
  GoldenSettingsScreenController({String? supportDir})
      : _supportDir = supportDir ?? '/tmp/doudou_golden_support';

  final String _supportDir;

  @override
  String get supportDirPath => _supportDir;
}

MediaItem goldenSong(String id, String title,
        {String artist = 'Golden Artist', String album = 'Golden Album'}) =>
    MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: album,
      artUri: Uri.parse('https://img.example.com/$id.jpg'),
      duration: const Duration(minutes: 3, seconds: 24),
      extras: {'url': 'https://example.com/$id.mp3'},
    );

Future<GoldenDeps> installGoldenDeps({
  SettingsScreenController? settings,
  PlayerController? player,
  ThemeController? theme,
}) async {
  Get.testMode = true;
  if (!Hive.isBoxOpen('AppPrefs')) {
    await Hive.openBox('AppPrefs');
  }
  final audio = FakeAudioHandler();
  Get.put<AudioHandler>(audio);
  Get.put<MusicServices>(GoldenMusicServices());
  Get.put<PlaybackDiagnosticsService>(FakePlaybackDiagnosticsService());
  Get.put<SettingsScreenController>(settings ?? FakeSettingsScreenController());
  Get.put<ShellController>(ShellController());
  Get.put<Downloader>(Downloader());
  Get.put<LibrarySyncService>(FakeLibrarySyncService());
  Get.put<TvService>(TvService());
  Get.put<PipedServices>(PipedServices());
  Get.put<ServerSyncService>(ServerSyncService());
  Get.put<McpServerService>(McpServerService());
  Get.put<DiscordRpcService>(DiscordRpcService());
  Get.put<AppSettingsController>(AppSettingsController());
  Get.put<ThemeController>(theme ?? ThemeController());
  final playerController = player ?? GoldenPlayerController();
  Get.put<PlayerController>(playerController);
  return GoldenDeps(player: playerController, audio: audio);
}

void resetGoldenDeps() {
  Get.reset();
}
