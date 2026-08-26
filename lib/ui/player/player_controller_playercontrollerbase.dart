part of 'player_controller.dart';

mixin _PlayerControllerBase on GetSingleTickerProviderStateMixin {

  final _audioHandler = Get.find<AudioHandler>();
  final _musicServices = Get.find<MusicServices>();
  final _diag = Get.find<PlaybackDiagnosticsService>();
  final currentQueue = <MediaItem>[].obs;

  final playerPaneOpacity = (1.0).obs;
  final isPlayerpanelTopVisible = true.obs;
  final isPanelGTHOpened = false.obs;
  final playerPanelMinHeight = 0.0.obs;
  bool initFlagForPlayer = true;
  final isQueueReorderingInProcess = false.obs;
  PanelController playerPanelController = PanelController();
  PanelController queuePanelController = PanelController();
  AnimationController? gesturePlayerStateAnimationController;
  Animation<double>? gesturePlayerStateAnimation;
  bool isRadioModeOn = false;
  String? radioContinuationParam;
  dynamic radioInitiatorItem;
  bool _isAddingRadioContinuation = false;
  String? _lastContinuationParamUsed;
  Timer? sleepTimer;
  int timerDuration = 0;
  final timerDurationLeft = 0.obs;
  final isSleepTimerActive = false.obs;
  final isSleepEndOfSongActive = false.obs;
  final volume = 100.obs;
  int _lastNonZeroVolume = 100;

  final progressBarStatus = ProgressBarState(
          buffered: Duration.zero, current: Duration.zero, total: Duration.zero)
      .obs;

  final currentSongIndex = (0).obs;
  final isFirstSong = true;
  final isLastSong = true;
  final isQueueLoopModeEnabled = false.obs;
  final isLoopModeEnabled = false.obs;
  final isShuffleModeEnabled = false.obs;
  final currentSong = Rxn<MediaItem>();
  final isCurrentSongFav = false.obs;
  final playinfrom = PlaylingFrom(type: PlaylingFromType.SELECTION).obs;
  final showLyricsflag = false.obs;
  final isLyricsLoading = false.obs;
  final lyricsMode = 0.obs;
  bool isDesktopLyricsDialogOpen = false;
  // 0 for play, 1 for pause, 2 for blank
  final gesturePlayerVisibleState = 2.obs;
  final lyricUi =
      UINetease(highlight: true, defaultSize: 20, defaultExtSize: 12);
  RxMap<String, dynamic> lyrics =
      <String, dynamic>{"synced": "", "plainLyrics": ""}.obs;
  ScrollController scrollController = ScrollController();
  final GlobalKey<ScaffoldState> homeScaffoldkey = GlobalKey<ScaffoldState>();

  final buttonState = PlayButtonState.paused.obs;

  // track whether wakelock is currently enabled to avoid repeated calls
  bool _wakelockActive = false;
  bool _wakelockUnavailable = false;
  bool _wakelockUnavailableLogged = false;

  var _newSongFlag = true;
  final isCurrentSongBuffered = false.obs;

  List<SyncedLyricLine> _syncedLyricLines = [];
  Color? _lastLyricsColor;
  bool _isTemporaryLyricAccentActive = false;

  List<SyncedLyricLine> get syncedLyricLines =>
      List<SyncedLyricLine>.unmodifiable(_syncedLyricLines);

  late StreamSubscription<bool> keyboardSubscription;
  final _playerStreamSubscriptions = <StreamSubscription>[];

  ///pushSongToPlaylist method clear previous song queue, plays the tapped song and push related
  ///songs into Queue
  ///enqueueSong   append a song to current queue
  ///if current queue is empty, push the song into Queue and play that song
  ///enqueueSongList method add song List to current queue
  // ignore: prefer_typing_uninitialized_variables
  var recentItem;

  /// This function is used to add a mediaItem/Song to Recently played playlist
  static final RegExp _lrcLineRegex = RegExp(
      r'^\[(\d{1,2}):(\d{2})(?:\.(\d{2,3}))?\]\s*(.*)$',
      multiLine: true);

  /// Called from audio handler in case audio is not playable
  /// or returned streamInfo null due to network error
onInit();
  void onReady();
  void _init();
  void initGesturePlayerStateAnimationController();
  void _setInitLyricsMode();
  void panellistener(double x);
  void _listenForKeyboardActivity();
  void _listenForChangesInPlayerState();
  Future<void> _setWakelock(bool enable);
  void _listenForChangesInPosition();
  void _listenForChangesInBufferedPosition();
  void _listenForChangesInDuration();
  void _listenForPlaylistChange();
  Future<void> _restorePrevSession();
  void _listenForCustomEvents();
  void _playerPanelCheck({bool restoreSession = false});
  void dispose();
  Future<void> enqueueSong(MediaItem mediaItem);
  Future<void> enqueueSongList(List<MediaItem> mediaItems);
  void playNext(MediaItem song);
  void removeFromQueue(MediaItem song);
  void clearQueue();
  void shuffleQueue();
  Future<void> toggleShuffleMode();
  void onReorder(int oldIndex, int newIndex);
  void onReorderStart(int index);
  void onReorderEnd(int index);
  void play();
  void pause();
  void playPause();
  void prev();
  Future<void> next();
  void seek(Duration position);
  void seekByIndex(int index);
  Future<void> pushSongToQueue(MediaItem? mediaItem, {String? playlistid, bool radio = false});
  Future<void> playPlayListSong(List<MediaItem> mediaItems, int index, {PlaylingFrom? playfrom});
  Future<void> _playFromContext(String songId, String libraryId);
  Future<bool> _playFromLibraryBox(String songId, String libraryId);
  Future<void> _playFromAnyBox(String songId);
  void _playViaAndroidAuto(String songId, String libraryId);
  void _listenForPlaybackToStartRadio(MediaItem mediaItem);
  Future<void> _fetchAndAddRadioSongs(MediaItem mediaItem);
  Future<void> startRadio(MediaItem? mediaItem, {String? playlistid});
  Future<void> _addRadioContinuation(dynamic item);
  Future<void> setVolume(int value);
  Future<void> mute();
  void toggleSkipSilence(bool enable);
  void toggleLoudnessNormalization(bool enable);
  Future<void> toggleLoopMode();
  Future<void> toggleQueueLoopMode({bool showMessage = true});
  Future<void> _checkFav();
  Future<void> toggleFavourite();
  Future<void> _addToRP(MediaItem mediaItem);
  void _parseSyncedLyrics(String raw);
  int currentSyncedLyricLineIndex(Duration position);
  void _updateDynamicColorFromLyrics(Duration position);
  void _clearTemporaryLyricAccent();
  void _syncLyricsModeWithAvailability();
  Future<void> _loadLyricsForCurrentSong();
  Future<void> showLyrics();
  Future<void> ensureLyricsLoadedForSheet();
  void changeLyricsMode(int? val);
  void sleepEndOfSong();
  void startSleepTimer(int minutes);
  void addFiveMinutes();
  void cancelSleepTimer();
  Future<void> openEqualizer();
  void notifyPlayError(String message);
  String _formatPlayErrorMessage(String raw);

}

