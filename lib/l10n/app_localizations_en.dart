// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get home => 'Home';

  @override
  String get homeSubtitle => 'Recent listens, new additions and picks for you';

  @override
  String get songs => 'Songs';

  @override
  String get playlists => 'Playlists';

  @override
  String get more => 'More';

  @override
  String get albums => 'Albums';

  @override
  String get album => 'Album';

  @override
  String get singles => 'Singles';

  @override
  String get artists => 'Artists';

  @override
  String get albumsFromYourArtists => 'From your artists';

  @override
  String get settings => 'Settings';

  @override
  String get library => 'Library';

  @override
  String get libraryOverviewSubtitle => 'Overview / Your music collection.';

  @override
  String get yourLibrary => 'Your Library';

  @override
  String get manage => 'Manage';

  @override
  String tracksInYourCollection(int count) {
    return '$count tracks in your collection';
  }

  @override
  String shuffleLikedSongs(int count) {
    return 'Shuffle $count liked songs';
  }

  @override
  String get availableOffline => 'Available offline';

  @override
  String get libSongs => 'Library Songs';

  @override
  String get libPlaylists => 'Library Playlists';

  @override
  String get libAlbums => 'Library Albums';

  @override
  String get libArtists => 'Library Artists';

  @override
  String get communityplaylists => 'Community Playlists';

  @override
  String get featuredplaylists => 'Featured Playlists';

  @override
  String get items => 'items';

  @override
  String get networkError1 => 'Oops network error!';

  @override
  String get retry => 'Retry!';

  @override
  String get noOfflineSong => 'No offline songs!';

  @override
  String get recentlyPlayed => 'Recently Played';

  @override
  String get favorites => 'Favourites';

  @override
  String get cachedOrOffline => 'Cached/Offline';

  @override
  String get downloads => 'Downloads';

  @override
  String get emptyPlaylist => 'Empty playlist!';

  @override
  String get enqueueAll => 'Enqueue all';

  @override
  String get renamePlaylist => 'Rename Playlist';

  @override
  String get removePlaylist => 'Remove playlist';

  @override
  String get createNewPlaylist => 'Create new playlist';

  @override
  String get reArrangePlaylist => 'Rearrange playlist';

  @override
  String get reArrangeSongs => 'Rearrange songs';

  @override
  String get selectSongs => 'Select songs';

  @override
  String get selectAll => 'Select All';

  @override
  String get removeMultiple => 'Remove multiple songs';

  @override
  String get addMultipleSongs => 'Add songs to playlist';

  @override
  String get cancel => 'Cancel';

  @override
  String get create => 'Create';

  @override
  String get rename => 'Rename';

  @override
  String get createnAdd => 'Create & add';

  @override
  String get noBookmarks => 'No bookmarks!';

  @override
  String get addMusicToLibraryHint =>
      'Add music to your library to see it here, mate';

  @override
  String get shuffleAll => 'Shuffle all';

  @override
  String get shuffleFavorites => 'Shuffle favorites';

  @override
  String get shuffleDownloads => 'Shuffle downloads';

  @override
  String get homeContinueListening => 'Continue listening';

  @override
  String get homeContinueListeningSubtitle => 'Pick up where you left off';

  @override
  String get homeBecauseYouLikeArtists => 'Because you like these artists';

  @override
  String get homeBecauseYouLikeArtistsSubtitle =>
      'More tracks from artists you already favorite';

  @override
  String get homePlaylistsSubtitle => 'Playlists from your collection';

  @override
  String get recentlyAddedAlbums => 'Recently added albums';

  @override
  String get yourNewestAdditions => 'Your newest additions';

  @override
  String get yourArtists => 'Your artists';

  @override
  String get homeArtistsSubtitle => 'A rotating mix from your artists';

  @override
  String get homeFreshPicks => 'Fresh picks';

  @override
  String get homeEmptyLibraryMessage =>
      'Your library is empty. Add some music to get started.';

  @override
  String get homeSectionEmpty => 'Nothing here yet';

  @override
  String get servers => 'Servers';

  @override
  String get addServer => 'Add server';

  @override
  String get noServersConfigured => 'No servers configured yet';

  @override
  String get activeServer => 'Active server';

  @override
  String get youtubeMusic => 'YouTube Music';

  @override
  String get subsonic => 'Subsonic';

  @override
  String get jellyfin => 'Jellyfin';

  @override
  String get plex => 'Plex';

  @override
  String get plexToken => 'Plex token';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get editServer => 'Edit server';

  @override
  String get deleteServer => 'Delete server';

  @override
  String get deleteServerConfirm =>
      'Are you sure you want to delete this server?';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String get defaultLabel => 'Default';

  @override
  String get youtubeMusicNoLogin =>
      'YouTube Music does not require login details.';

  @override
  String get serverUrlRequired => 'Server URL is required';

  @override
  String get testConnection => 'Test connection';

  @override
  String get connectionSuccess => 'Connection successful';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String get playAll => 'Play All';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get artistLabel => 'ARTIST';

  @override
  String get fromWikipedia => 'From Wikipedia';

  @override
  String get songsCount => 'songs';

  @override
  String get addToLibrary => 'Add to library';

  @override
  String get noSongsInLibrary => 'No songs in library';

  @override
  String get favoritesEmpty => 'Favourites is empty';

  @override
  String get startRadio => 'Start radio';

  @override
  String get playNext => 'Play next';

  @override
  String get addToPlaylist => 'Add to playlist';

  @override
  String get noLibPlaylist => 'You don\'t have any lib playlist, mate!';

  @override
  String get enqueueSong => 'Enqueue this song';

  @override
  String get goToAlbum => 'Go to album';

  @override
  String get viewArtist => 'View Artist';

  @override
  String get openIn => 'Open in';

  @override
  String get shareSong => 'Share this song';

  @override
  String get removeFromPlaylist => 'Remove from playlist';

  @override
  String get removeFromQueue => 'Remove from queue';

  @override
  String get queueShufflingDeniedMsg =>
      'Queue can\'t be shuffled when shuffle mode is enabled';

  @override
  String get queuerearrangingDeniedMsg =>
      'Queue can\'t be rearranged when shuffle mode is enabled';

  @override
  String get songNotPlayable =>
      'Song is not playable due to server restriction!';

  @override
  String get upNext => 'Up Next';

  @override
  String get lyrics => 'Lyrics';

  @override
  String get fromAlbum => 'From: ';

  @override
  String get byArtist => 'By: ';

  @override
  String get playingFrom => 'Playing from ';

  @override
  String get playingfromAlbum => 'PLAYING FROM ALBUM';

  @override
  String get playingfromPlaylist => 'PLAYING FROM PLAYLIST';

  @override
  String get playingfromSelection => 'PLAYING FROM SELECTION';

  @override
  String get playingfromArtist => 'PLAYING FROM ARTIST';

  @override
  String get randomSelection => 'Random Selection';

  @override
  String get randomRadio => 'Random Radio';

  @override
  String get playnextMsg => 'Upcoming';

  @override
  String get shuffleQueue => 'Shuffle Queue';

  @override
  String get queueLoop => 'Queue loop';

  @override
  String get queueLoopNotDisMsg1 =>
      'Queue loop mode cannot be disabled when shuffle mode is enabled.';

  @override
  String get queueLoopNotDisMsg2 =>
      'Queue loop mode cannot be enabled in radio mode.';

  @override
  String get removeFromLib => 'Remove from Library Songs';

  @override
  String get sleepTimer => 'Sleep Timer';

  @override
  String get add5Minutes => 'Add 5 minutes';

  @override
  String get cancelTimer => 'Cancel timer';

  @override
  String get deleteDownloadData => 'Remove from downloads';

  @override
  String get minutes => 'minutes';

  @override
  String get endOfThisSong => 'End of this song';

  @override
  String get appInfo => 'App Info';

  @override
  String get download => 'Download';

  @override
  String get misc => 'Misc';

  @override
  String get autoDownFavSong => 'Auto download favorite songs';

  @override
  String get autoDownFavSongDes =>
      'Automatically download favorite songs when added to favorites';

  @override
  String get networkError => 'Network error! Check your network connection.';

  @override
  String get downloadError2 =>
      'Requested song is not downloadable due to server restriction. You may try again';

  @override
  String get downloadError3 =>
      'Downloading failed due to network/stream error! Please try again';

  @override
  String get musicPlayback => 'Music & Playback';

  @override
  String get content => 'Content';

  @override
  String get personalisation => 'Personalisation';

  @override
  String get themeMode => 'Theme Mode';

  @override
  String get dynamicTheme => 'Dynamic';

  @override
  String get dynamicColor => 'Dynamic Colour';

  @override
  String get systemDefault => 'System Default';

  @override
  String get dark => 'Dark';

  @override
  String get light => 'Light';

  @override
  String get oled => 'OLED';

  @override
  String get language => 'Language';

  @override
  String get playerUi => 'Player Ui';

  @override
  String get playerUiDes => 'Select player user interface';

  @override
  String get standard => 'Standard';

  @override
  String get gesture => 'Gesture';

  @override
  String get languageDes => 'Set App language';

  @override
  String get setDiscoverContent => 'Set discover content';

  @override
  String get quickpicks => 'Quick Picks';

  @override
  String get discover => 'Discover';

  @override
  String get trending => 'Trending';

  @override
  String get topmusicvideos => 'Top Music Videos';

  @override
  String get basedOnLast => 'Based on last interaction';

  @override
  String get restoreLastPlaybackSession => 'Restore last playback session';

  @override
  String get restoreLastPlaybackSessionDes =>
      'Automatically restore the last playback session on app start';

  @override
  String get autoOpenPlayer => 'Auto open player screen';

  @override
  String get autoOpenPlayerDes =>
      'Enable/disable auto opening of player full screen on selection of song for play';

  @override
  String get homeContentCount => 'Home content count';

  @override
  String get homeContentCountDes =>
      'Select the number of initial homescreen-content(approx). Lesser results faster loading';

  @override
  String get enableBottomNav => 'Use bottom navigation bar';

  @override
  String get enableBottomNavDes => 'Force bottom navigation on larger screens';

  @override
  String get sidebarMode => 'Sidebar behavior';

  @override
  String get sidebarModeDes =>
      'Control whether the sidebar is automatic, always collapsed, or always full width.';

  @override
  String get sidebarModeAuto => 'Auto';

  @override
  String get sidebarModeCollapsed => 'Collapsed';

  @override
  String get sidebarModeExpanded => 'Full view';

  @override
  String get nowPlayingLayout => 'Now playing layout';

  @override
  String get nowPlayingLayoutDes =>
      'Choose whether the now playing player appears as a side panel or a play bar on large screens.';

  @override
  String get nowPlayingLayoutSideView => 'Side view';

  @override
  String get nowPlayingLayoutPlayBar => 'Play bar';

  @override
  String get dynamicColorDes =>
      'Dynamic theme using a fixed colour (not now playing).';

  @override
  String get useCustomAccentColor => 'Use custom accent colour';

  @override
  String get useCustomAccentColorDes =>
      'Apply your selected accent colour across all theme modes.';

  @override
  String get customAccentColor => 'Custom accent colour';

  @override
  String get customAccentColorDes =>
      'Pick the accent colour used across the app.';

  @override
  String get lyricsDynamicColor => 'Lyrics change accent colour';

  @override
  String get lyricsDynamicColorDes =>
      'When a song has synced lyrics, colour words in the lyrics can change the app accent (Dynamic theme only).';

  @override
  String get syncedLyricsHighlightStyle => 'Synced lyrics highlight style';

  @override
  String get syncedLyricsHighlightStyleDes =>
      'Choose how the active synced lyric line is highlighted.';

  @override
  String get lyricsHighlightBlock => 'Block highlight';

  @override
  String get lyricsHighlightKaraoke => 'Karaoke fill';

  @override
  String get pickDynamicColor => 'Pick dynamic colour';

  @override
  String get advanced => 'Advanced…';

  @override
  String get change => 'Change';

  @override
  String get cacheSongs => 'Cache Songs';

  @override
  String get cacheSongsDes =>
      'Caching songs while playing for future/offline playback, it will take additional space on your device';

  @override
  String get skipSilence => 'Skip silence';

  @override
  String get skipSilenceDes => 'Silence will be skipped in music playback';

  @override
  String get loudnessNormalization => 'Loudness normalization';

  @override
  String get loudnessNormalizationDes =>
      'Sets same lavel of loudness for all songs (Experimental) (Will not work on songs downloaded on previous version(< v1.10.0))';

  @override
  String get streamingQuality => 'Streaming quality';

  @override
  String get streamingQualityDes => 'Quality of music stream';

  @override
  String get disableTransitionAnimation => 'Disable transition animation';

  @override
  String get disableTransitionAnimationDes =>
      'Enable this option to disable tab transition animation';

  @override
  String get animationSpeed => 'Animation speed';

  @override
  String get animationSpeedDes =>
      'Control the speed of app transitions or turn them off.';

  @override
  String get animationSpeedOff => 'Off';

  @override
  String get animationSpeedFast => 'Fast (default)';

  @override
  String get animationSpeedNormal => 'Normal';

  @override
  String get animationSpeedSlow => 'Slow';

  @override
  String get enableSlidableAction => 'Enable slidable actions';

  @override
  String get enableSlidableActionDes => 'Enable slidable actions on song tile';

  @override
  String get loading => 'Loading';

  @override
  String get imported => 'Imported';

  @override
  String get importedPlaylist => 'Imported playlist';

  @override
  String get listBookmarkRemoveAlert => 'Bookmark removed!';

  @override
  String get permissionDenied => 'Permission denied';

  @override
  String get unknownArtist => 'Unknown Artist';

  @override
  String get unknownAlbum => 'Unknown Album';

  @override
  String get yourMusicCollection => 'Your music collection';

  @override
  String get sortByName => 'Sort by name';

  @override
  String get sortByDate => 'Sort by date';

  @override
  String get sortByDuration => 'Sort by duration';

  @override
  String get sortAscendNDescend => 'Ascending & Descending';

  @override
  String get high => 'High';

  @override
  String get low => 'Low';

  @override
  String get backgroundPlay => 'Background music play';

  @override
  String get backgroundPlayDes =>
      'Enable/Disable music playing in background (App can be accessed from system tray when app is running in background)';

  @override
  String get downloadLocation => 'Download Location';

  @override
  String get cacheHomeScreenData => 'Cache home screen content data';

  @override
  String get cacheHomeScreenDataDes =>
      'Enable Caching home screen content data, Home screen will load instantly if this option is enabled';

  @override
  String get downloadingFormat => 'Downloading File Format';

  @override
  String get downloadingFormatDes =>
      'Select downloading file format. \"Opus\" will provide best quality';

  @override
  String get exportDowloadedFiles => 'Export downloaded files';

  @override
  String get exportDowloadedFilesDes =>
      'Click here to export downloaded file from inApp dir to external dir';

  @override
  String get exportedFileLocation => 'Downloaded file export location';

  @override
  String get export => 'Export';

  @override
  String get exporting => 'Exporting...';

  @override
  String get scanning => 'Scanning...';

  @override
  String get downFilesFound => 'downloaded files found';

  @override
  String get close => 'Close';

  @override
  String get exportMsg => 'Files successfully exported';

  @override
  String get equalizer => 'Equalizer';

  @override
  String get equalizerDes => 'Open system equalizer';

  @override
  String get clearImgCache => 'Clear images cache';

  @override
  String get clearImgCacheAlert => 'Images cache cleared successfully';

  @override
  String get clearImgCacheDes =>
      'Click here to clear cached thumbnails/images. (Not recommended unless want to refresh cached images data)';

  @override
  String get ignoreBatOpt => 'Ignore battery optimization';

  @override
  String get ignoreBatOptDes =>
      'If you are facing notification issues or playback stopped by system optimization, please enable this option';

  @override
  String get status => 'Status';

  @override
  String get enabled => 'Enabled';

  @override
  String get disabled => 'Disabled';

  @override
  String get resetToDefault => 'Restore default settings';

  @override
  String get resetToDefaultDes =>
      'Reset app settings to default (Restart required)';

  @override
  String get resetToDefaultMsg =>
      'Settings reset to default completed, Please restart app';

  @override
  String get github => 'GitHub';

  @override
  String get githubDes =>
      'View GitHub source code \nif you like this project, don\'t forget to give a ⭐';

  @override
  String get gitlab => 'GitLab';

  @override
  String get gitlabDes =>
      'View GitLab source code\nif you like this project, don\'t forget to give a ⭐';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get checkForUpdatesOnStartup => 'Check for updates on startup';

  @override
  String get openGitlab => 'Open GitLab';

  @override
  String get upToDate => 'You\'re right, mate – you\'re up to date';

  @override
  String get checkingForUpdates => 'Checking for updates…';

  @override
  String get by => 'by';

  @override
  String get urlSearchDes =>
      'Url detected click on it to open/play associated content';

  @override
  String get search => 'Search';

  @override
  String get searchDes => 'Songs, Playlist, Album or Artist';

  @override
  String get searchRes => 'Search results';

  @override
  String get for1 => 'for';

  @override
  String get videos => 'Videos';

  @override
  String get viewAll => 'View all';

  @override
  String get results => 'Results';

  @override
  String get nomatch => 'No Match found for';

  @override
  String get subscribers => 'subscribers';

  @override
  String get about => 'About';

  @override
  String get synced => 'Synced';

  @override
  String get plain => 'Plain';

  @override
  String get songInfo => 'Song Info';

  @override
  String get id => 'Id';

  @override
  String get title => 'Title';

  @override
  String get duration => 'Duration';

  @override
  String get audioCodec => 'Audio Codec';

  @override
  String get bitrate => 'Bitrate';

  @override
  String get loudnessDb => 'LoudnessDb';

  @override
  String get deleteDownloadedDataAlert =>
      'Successfully removed from downloads!';

  @override
  String get cancelTimerAlert => 'Sleep timer cancelled';

  @override
  String get sleepTimeSetAlert => 'Your sleep timer is set';

  @override
  String get radioNotAvailable => 'Radio not available for this artist!';

  @override
  String get songRemovedfromQueue => 'Removed from queue!';

  @override
  String get songRemovedfromQueueCurrSong =>
      'You can\'t remove currently playing song';

  @override
  String get songAddedToPlaylistAlert => 'Song added to playlist!';

  @override
  String get songAlreadyExists => 'Song already exists!';

  @override
  String get songAlreadyOfflineAlert => 'Song already offline in cache';

  @override
  String get songEnqueueAlert => 'Song enqueued!';

  @override
  String get songRemovedAlert => 'Removed from';

  @override
  String get errorOccuredAlert => 'Some error occured!';

  @override
  String get pipedplstSyncAlert => 'Piped playlist synced!';

  @override
  String get playlistCreatedAlert => 'Playlist created!';

  @override
  String get playlistCreatednsongAddedAlert => 'Playlist created & song added!';

  @override
  String get playlistRenameAlert => 'Renamed successfully!';

  @override
  String get playlistRemovedAlert => 'Playlist removed!';

  @override
  String get playlistBookmarkAddAlert => 'Playlist bookmarked!';

  @override
  String get playlistBookmarkRemoveAlert => 'Playlist bookmark removed!';

  @override
  String get albumBookmarkAddAlert => 'Album bookmarked!';

  @override
  String get albumBookmarkRemoveAlert => 'Album bookmark removed!';

  @override
  String get artistBookmarkAddAlert => 'Artist bookmarked!';

  @override
  String get artistBookmarkRemoveAlert => 'Artist bookmark removed!';

  @override
  String get lyricsNotAvailable => 'Lyrics not available!';

  @override
  String get syncedLyricsNotAvailable => 'Synced lyrics not available!';

  @override
  String get artistDesNotAvailable => 'Description not available!';

  @override
  String get newVersionAvailable => 'New version available!';

  @override
  String get version => 'Version';

  @override
  String get dontShowInfoAgain => 'Don\'t show this info again';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get notaSongVideo => 'Not a Song/Music-Video!';

  @override
  String get notaValidLink => 'Not a valid link!';

  @override
  String get operationFailed => 'Operation failed';

  @override
  String get goToDownloadPage => 'Click here to go to download page';

  @override
  String get local => 'Local';

  @override
  String get piped => 'Piped';

  @override
  String get link => 'Link';

  @override
  String get unLink => 'Unlink';

  @override
  String get hintApiUrl => 'API URL to Piped instance';

  @override
  String get customIns => 'Custom Instance';

  @override
  String get customInsSelectMsg => 'Please select Custom Instance';

  @override
  String get selectAuthInsMsg => 'Please select Authentication instance!';

  @override
  String get allFieldsReqMsg => 'All fields required';

  @override
  String get linkPipedDes => 'Link with piped for playlists';

  @override
  String get selectAuthIns => 'Select Auth Instance';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get linkAlert => 'Linked successfully!';

  @override
  String get unlinkAlert => 'Unlinked successfully!';

  @override
  String get playlistBlacklistAlert => 'Playlist blacklisted!';

  @override
  String get reset => 'Reset';

  @override
  String get blacklistPlstResetAlert => 'Reset successfully!';

  @override
  String get resetblacklistedplaylist => 'Reset blacklisted playlists';

  @override
  String get resetblacklistedplaylistDes =>
      'Reset all the piped blacklisted playlists';

  @override
  String get stopMusicOnTaskClear => 'Stop music on task clear';

  @override
  String get stopMusicOnTaskClearDes =>
      'Music playback will stop when App being swiped away from the task manager';

  @override
  String get backupAppData => 'Backup App data';

  @override
  String get androidBackupWarning =>
      'Not tested: Selecting the checkbox after downloading more than 60 files, process may consume a large amount of memory and could cause the phone or app to crash. Proceed at your own risk.';

  @override
  String get backupSettingsAndPlaylistsDes =>
      'Saves all settings, playlists and login data in a backup file';

  @override
  String get backup => 'Backup';

  @override
  String get letsStrart => 'Let\'s start..';

  @override
  String get processFiles => 'Processing files...';

  @override
  String get includeDownloadedFiles => 'Include downloded songs files';

  @override
  String get backupInProgress => 'Backup in progress...';

  @override
  String get restoreAppData => 'Restore App data';

  @override
  String get restoreSettingsAndPlaylistsDes =>
      'Restores all settings, login data and playlists from a backup file. Overwrites all current data';

  @override
  String get backupMsg => 'Backup successfully saved!';

  @override
  String get backFilesFound => 'databases found';

  @override
  String get restoreMsg =>
      'Successfully restored!\nChanges are applied on restart';

  @override
  String get restoring => 'Restoring...';

  @override
  String get restore => 'Restore';

  @override
  String get closeApp => 'Close App';

  @override
  String get restartApp => 'Restart App';

  @override
  String get exportPlaylist => 'Export Playlist';

  @override
  String get exportPlaylistCsv => 'Export Playlist as CSV';

  @override
  String get exportingPlaylist => 'Exporting playlist...';

  @override
  String get playlistExportedMsg => 'Playlist exported successfully to';

  @override
  String get exportError => 'Error exporting playlist';

  @override
  String get exportErrorPermission => 'Permission denied while exporting';

  @override
  String get exportErrorStorage => 'Not enough storage space';

  @override
  String get exportErrorFormat => 'Error formatting playlist data';

  @override
  String get importPlaylist => 'Import Playlist';

  @override
  String get importingPlaylist => 'Importing playlist...';

  @override
  String get importPlaylistDesc =>
      'Select a previously exported playlist JSON file to import';

  @override
  String get selectFile => 'Select File';

  @override
  String get playlistImportedMsg => 'Playlist imported successfully';

  @override
  String get importError => 'Error importing playlist';

  @override
  String get importErrorFileAccess => 'Could not access the selected file';

  @override
  String get importErrorFormat => 'Invalid file format';

  @override
  String get invalidPlaylistFile => 'Invalid playlist file structure';

  @override
  String get importErrorDatabase => 'Error saving to database';

  @override
  String get fileNotFound => 'File not found';

  @override
  String get importLargeFileNote =>
      'Note: Large playlists may take longer to import';

  @override
  String get exportPlaylistJson => 'Export playlist to JSON';

  @override
  String get exportPlaylistJsonSubtitle => 'This format can be imported';

  @override
  String get exportPlaylistCsvSubtitle => 'Can\'t be imported here';

  @override
  String get exportToYouTubeMusic => 'Export to Youtube music';

  @override
  String get exportToYouTubeMusicSubtitle =>
      'It will push your playlist (songs < 50) to current queue, don\'t forget to add to playlist/save after opening in YtMusic';

  @override
  String get linkCopied => 'Link copied to clipboard';

  @override
  String get keepScreenOnWhilePlaying => 'Keep screen on while playing';

  @override
  String get keepScreenOnWhilePlayingDes =>
      'If enabled, the device screen will stay awake while music is playing';

  @override
  String get autoRadio => 'Auto-start radio';

  @override
  String get autoRadioDes =>
      'Automatically start radio mode when playing a single song from YouTube Music';

  @override
  String get resyncLibraryNow => 'Resync Library Now';

  @override
  String get playbackDiagnosticsRelease => 'Playback diagnostics (release)';

  @override
  String get viewPlaybackDiagnostics => 'View playback diagnostics';

  @override
  String get viewPlaybackDiagnosticsSubtitle =>
      'Open logs and copy to clipboard';

  @override
  String get clearPlaybackDiagnostics => 'Clear playback diagnostics';

  @override
  String get clearPlaybackDiagnosticsSubtitle =>
      'Delete all stored diagnostic events';

  @override
  String get playbackDiagnostics => 'Playback diagnostics';

  @override
  String get toggleFormat => 'Toggle format';

  @override
  String get copyDiagnostics => 'Copy diagnostics';

  @override
  String get shrinkSidebar => 'shtink sidebar';

  @override
  String get playlistTypeLabel => 'PLAYLIST';

  @override
  String get playbackDiagnosticsCleared => 'Playback diagnostics cleared';

  @override
  String get hideNowPlaying => 'Hide Now Playing';

  @override
  String get showNowPlaying => 'Show Now Playing';

  @override
  String get autoLoginRequiredTitle => 'Log in to use Doudou';

  @override
  String get autoLoginRequiredMessage =>
      'Open Doudou on your phone and sign in to a server to start playing music here.';

  @override
  String get autoLoginRequiredAction => 'Open on phone';

  @override
  String get autoLoginRequiredDismiss => 'OK';

  @override
  String get protocol => 'Protocol';

  @override
  String get done => 'Done';

  @override
  String get syncing => 'Syncing...';

  @override
  String get sync => 'Sync';

  @override
  String get accounts => 'ACCOUNTS';

  @override
  String get user => 'USER';

  @override
  String get appearance => 'APPEARANCE';

  @override
  String get diagnosticsCopied => 'Diagnostics copied to clipboard';

  @override
  String get noDiagnosticsToCopy => 'No diagnostics to copy';

  @override
  String get refresh => 'Refresh';

  @override
  String eventsCount(int count, int max) {
    return 'Events: $count (showing up to $max)';
  }

  @override
  String get noDiagnosticsHint =>
      'No diagnostics yet.\nEnable diagnostics and reproduce the issue.';
}

/// The translations for English, as used in Australia (`en_AU`).
class AppLocalizationsEnAu extends AppLocalizationsEn {
  AppLocalizationsEnAu() : super('en_AU');

  @override
  String get home => 'Home';

  @override
  String get homeSubtitle => 'Recent listens, new additions and picks for you';

  @override
  String get songs => 'Songs';

  @override
  String get playlists => 'Playlists';

  @override
  String get more => 'More';

  @override
  String get albums => 'Albums';

  @override
  String get album => 'Album';

  @override
  String get singles => 'Singles';

  @override
  String get artists => 'Artists';

  @override
  String get albumsFromYourArtists => 'From your artists';

  @override
  String get settings => 'Settings';

  @override
  String get library => 'Library';

  @override
  String get libraryOverviewSubtitle => 'Overview / Your music collection.';

  @override
  String get yourLibrary => 'Your Library';

  @override
  String get manage => 'Manage';

  @override
  String tracksInYourCollection(int count) {
    return '$count tracks in your collection';
  }

  @override
  String shuffleLikedSongs(int count) {
    return 'Shuffle $count liked songs';
  }

  @override
  String get availableOffline => 'Available offline';

  @override
  String get libSongs => 'Library Songs';

  @override
  String get libPlaylists => 'Library Playlists';

  @override
  String get libAlbums => 'Library Albums';

  @override
  String get libArtists => 'Library Artists';

  @override
  String get communityplaylists => 'Community Playlists';

  @override
  String get featuredplaylists => 'Featured Playlists';

  @override
  String get items => 'items';

  @override
  String get networkError1 => 'Oops network error!';

  @override
  String get retry => 'Retry!';

  @override
  String get noOfflineSong => 'No offline songs!';

  @override
  String get recentlyPlayed => 'Recently Played';

  @override
  String get favorites => 'Favourites';

  @override
  String get cachedOrOffline => 'Cached/Offline';

  @override
  String get downloads => 'Downloads';

  @override
  String get emptyPlaylist => 'Empty playlist!';

  @override
  String get enqueueAll => 'Enqueue all';

  @override
  String get renamePlaylist => 'Rename Playlist';

  @override
  String get removePlaylist => 'Remove playlist';

  @override
  String get createNewPlaylist => 'Create new playlist';

  @override
  String get reArrangePlaylist => 'Rearrange playlist';

  @override
  String get reArrangeSongs => 'Rearrange songs';

  @override
  String get selectSongs => 'Select songs';

  @override
  String get selectAll => 'Select All';

  @override
  String get removeMultiple => 'Remove multiple songs';

  @override
  String get addMultipleSongs => 'Add songs to playlist';

  @override
  String get cancel => 'Cancel';

  @override
  String get create => 'Create';

  @override
  String get rename => 'Rename';

  @override
  String get createnAdd => 'Create & add';

  @override
  String get noBookmarks => 'No bookmarks!';

  @override
  String get addMusicToLibraryHint =>
      'Add music to your library to see it here, mate';

  @override
  String get shuffleAll => 'Shuffle all';

  @override
  String get shuffleFavorites => 'Shuffle favorites';

  @override
  String get shuffleDownloads => 'Shuffle downloads';

  @override
  String get homeContinueListening => 'Continue listening';

  @override
  String get homeContinueListeningSubtitle => 'Pick up where you left off';

  @override
  String get homeBecauseYouLikeArtists => 'Because you like these artists';

  @override
  String get homeBecauseYouLikeArtistsSubtitle =>
      'More tracks from artists you already favorite';

  @override
  String get homePlaylistsSubtitle => 'Playlists from your collection';

  @override
  String get recentlyAddedAlbums => 'Recently added albums';

  @override
  String get yourNewestAdditions => 'Your newest additions';

  @override
  String get yourArtists => 'Your artists';

  @override
  String get homeArtistsSubtitle => 'A rotating mix from your artists';

  @override
  String get homeFreshPicks => 'Fresh picks';

  @override
  String get homeEmptyLibraryMessage =>
      'Your library is empty. Add some music to get started.';

  @override
  String get homeSectionEmpty => 'Nothing here yet';

  @override
  String get servers => 'Servers';

  @override
  String get addServer => 'Add server';

  @override
  String get noServersConfigured => 'No servers configured yet';

  @override
  String get activeServer => 'Active server';

  @override
  String get youtubeMusic => 'YouTube Music';

  @override
  String get subsonic => 'Subsonic';

  @override
  String get jellyfin => 'Jellyfin';

  @override
  String get plex => 'Plex';

  @override
  String get plexToken => 'Plex token';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get editServer => 'Edit server';

  @override
  String get deleteServer => 'Delete server';

  @override
  String get deleteServerConfirm =>
      'Are you sure you want to delete this server?';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String get defaultLabel => 'Default';

  @override
  String get youtubeMusicNoLogin =>
      'YouTube Music does not require login details.';

  @override
  String get serverUrlRequired => 'Server URL is required';

  @override
  String get testConnection => 'Test connection';

  @override
  String get connectionSuccess => 'Connection successful';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String get playAll => 'Play All';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get artistLabel => 'ARTIST';

  @override
  String get fromWikipedia => 'From Wikipedia';

  @override
  String get songsCount => 'songs';

  @override
  String get addToLibrary => 'Add to library';

  @override
  String get noSongsInLibrary => 'No songs in library';

  @override
  String get favoritesEmpty => 'Favourites is empty';

  @override
  String get startRadio => 'Start radio';

  @override
  String get playNext => 'Play next';

  @override
  String get addToPlaylist => 'Add to playlist';

  @override
  String get noLibPlaylist => 'You don\'t have any lib playlist, mate!';

  @override
  String get enqueueSong => 'Enqueue this song';

  @override
  String get goToAlbum => 'Go to album';

  @override
  String get viewArtist => 'View Artist';

  @override
  String get openIn => 'Open in';

  @override
  String get shareSong => 'Share this song';

  @override
  String get removeFromPlaylist => 'Remove from playlist';

  @override
  String get removeFromQueue => 'Remove from queue';

  @override
  String get queueShufflingDeniedMsg =>
      'Queue can\'t be shuffled when shuffle mode is enabled';

  @override
  String get queuerearrangingDeniedMsg =>
      'Queue can\'t be rearranged when shuffle mode is enabled';

  @override
  String get songNotPlayable =>
      'Song is not playable due to server restriction!';

  @override
  String get upNext => 'Up Next';

  @override
  String get lyrics => 'Lyrics';

  @override
  String get fromAlbum => 'From: ';

  @override
  String get byArtist => 'By: ';

  @override
  String get playingFrom => 'Playing from ';

  @override
  String get playingfromAlbum => 'PLAYING FROM ALBUM';

  @override
  String get playingfromPlaylist => 'PLAYING FROM PLAYLIST';

  @override
  String get playingfromSelection => 'PLAYING FROM SELECTION';

  @override
  String get playingfromArtist => 'PLAYING FROM ARTIST';

  @override
  String get randomSelection => 'Random Selection';

  @override
  String get randomRadio => 'Random Radio';

  @override
  String get playnextMsg => 'Upcoming';

  @override
  String get shuffleQueue => 'Shuffle Queue';

  @override
  String get queueLoop => 'Queue loop';

  @override
  String get queueLoopNotDisMsg1 =>
      'Queue loop mode cannot be disabled when shuffle mode is enabled.';

  @override
  String get queueLoopNotDisMsg2 =>
      'Queue loop mode cannot be enabled in radio mode.';

  @override
  String get removeFromLib => 'Remove from Library Songs';

  @override
  String get sleepTimer => 'Sleep Timer';

  @override
  String get add5Minutes => 'Add 5 minutes';

  @override
  String get cancelTimer => 'Cancel timer';

  @override
  String get deleteDownloadData => 'Remove from downloads';

  @override
  String get minutes => 'minutes';

  @override
  String get endOfThisSong => 'End of this song';

  @override
  String get appInfo => 'App Info';

  @override
  String get download => 'Download';

  @override
  String get misc => 'Misc';

  @override
  String get autoDownFavSong => 'Auto download favorite songs';

  @override
  String get autoDownFavSongDes =>
      'Automatically download favorite songs when added to favorites';

  @override
  String get networkError => 'Network error! Check your network connection.';

  @override
  String get downloadError2 =>
      'Requested song is not downloadable due to server restriction. You may try again';

  @override
  String get downloadError3 =>
      'Downloading failed due to network/stream error! Please try again';

  @override
  String get musicPlayback => 'Music & Playback';

  @override
  String get content => 'Content';

  @override
  String get personalisation => 'Personalisation';

  @override
  String get themeMode => 'Theme Mode';

  @override
  String get dynamicTheme => 'Dynamic';

  @override
  String get dynamicColor => 'Dynamic Colour';

  @override
  String get systemDefault => 'System Default';

  @override
  String get dark => 'Dark';

  @override
  String get light => 'Light';

  @override
  String get oled => 'OLED';

  @override
  String get language => 'Language';

  @override
  String get playerUi => 'Player Ui';

  @override
  String get playerUiDes => 'Select player user interface';

  @override
  String get standard => 'Standard';

  @override
  String get gesture => 'Gesture';

  @override
  String get languageDes => 'Set App language';

  @override
  String get setDiscoverContent => 'Set discover content';

  @override
  String get quickpicks => 'Quick Picks';

  @override
  String get discover => 'Discover';

  @override
  String get trending => 'Trending';

  @override
  String get topmusicvideos => 'Top Music Videos';

  @override
  String get basedOnLast => 'Based on last interaction';

  @override
  String get restoreLastPlaybackSession => 'Restore last playback session';

  @override
  String get restoreLastPlaybackSessionDes =>
      'Automatically restore the last playback session on app start';

  @override
  String get autoOpenPlayer => 'Auto open player screen';

  @override
  String get autoOpenPlayerDes =>
      'Enable/disable auto opening of player full screen on selection of song for play';

  @override
  String get homeContentCount => 'Home content count';

  @override
  String get homeContentCountDes =>
      'Select the number of initial homescreen-content(approx). Lesser results faster loading';

  @override
  String get enableBottomNav => 'Use bottom navigation bar';

  @override
  String get enableBottomNavDes => 'Force bottom navigation on larger screens';

  @override
  String get sidebarMode => 'Sidebar behavior';

  @override
  String get sidebarModeDes =>
      'Control whether the sidebar is automatic, always collapsed, or always full width.';

  @override
  String get sidebarModeAuto => 'Auto';

  @override
  String get sidebarModeCollapsed => 'Collapsed';

  @override
  String get sidebarModeExpanded => 'Full view';

  @override
  String get nowPlayingLayout => 'Now playing layout';

  @override
  String get nowPlayingLayoutDes =>
      'Choose whether the now playing player appears as a side panel or a play bar on large screens.';

  @override
  String get nowPlayingLayoutSideView => 'Side view';

  @override
  String get nowPlayingLayoutPlayBar => 'Play bar';

  @override
  String get dynamicColorDes =>
      'Dynamic theme using a fixed colour (not now playing).';

  @override
  String get useCustomAccentColor => 'Use custom accent colour';

  @override
  String get useCustomAccentColorDes =>
      'Apply your selected accent colour across all theme modes.';

  @override
  String get customAccentColor => 'Custom accent colour';

  @override
  String get customAccentColorDes =>
      'Pick the accent colour used across the app.';

  @override
  String get lyricsDynamicColor => 'Lyrics change accent colour';

  @override
  String get lyricsDynamicColorDes =>
      'When a song has synced lyrics, colour words in the lyrics can change the app accent (Dynamic theme only).';

  @override
  String get syncedLyricsHighlightStyle => 'Synced lyrics highlight style';

  @override
  String get syncedLyricsHighlightStyleDes =>
      'Choose how the active synced lyric line is highlighted.';

  @override
  String get lyricsHighlightBlock => 'Block highlight';

  @override
  String get lyricsHighlightKaraoke => 'Karaoke fill';

  @override
  String get pickDynamicColor => 'Pick dynamic colour';

  @override
  String get advanced => 'Advanced…';

  @override
  String get change => 'Change';

  @override
  String get cacheSongs => 'Cache Songs';

  @override
  String get cacheSongsDes =>
      'Caching songs while playing for future/offline playback, it will take additional space on your device';

  @override
  String get skipSilence => 'Skip silence';

  @override
  String get skipSilenceDes => 'Silence will be skipped in music playback';

  @override
  String get loudnessNormalization => 'Loudness normalization';

  @override
  String get loudnessNormalizationDes =>
      'Sets same lavel of loudness for all songs (Experimental) (Will not work on songs downloaded on previous version(< v1.10.0))';

  @override
  String get streamingQuality => 'Streaming quality';

  @override
  String get streamingQualityDes => 'Quality of music stream';

  @override
  String get disableTransitionAnimation => 'Disable transition animation';

  @override
  String get disableTransitionAnimationDes =>
      'Enable this option to disable tab transition animation';

  @override
  String get animationSpeed => 'Animation speed';

  @override
  String get animationSpeedDes =>
      'Control the speed of app transitions or turn them off.';

  @override
  String get animationSpeedOff => 'Off';

  @override
  String get animationSpeedFast => 'Fast (default)';

  @override
  String get animationSpeedNormal => 'Normal';

  @override
  String get animationSpeedSlow => 'Slow';

  @override
  String get enableSlidableAction => 'Enable slidable actions';

  @override
  String get enableSlidableActionDes => 'Enable slidable actions on song tile';

  @override
  String get loading => 'Loading';

  @override
  String get imported => 'Imported';

  @override
  String get importedPlaylist => 'Imported playlist';

  @override
  String get listBookmarkRemoveAlert => 'Bookmark removed!';

  @override
  String get permissionDenied => 'Permission denied';

  @override
  String get unknownArtist => 'Unknown Artist';

  @override
  String get unknownAlbum => 'Unknown Album';

  @override
  String get yourMusicCollection => 'Your music collection';

  @override
  String get sortByName => 'Sort by name';

  @override
  String get sortByDate => 'Sort by date';

  @override
  String get sortByDuration => 'Sort by duration';

  @override
  String get sortAscendNDescend => 'Ascending & Descending';

  @override
  String get high => 'High';

  @override
  String get low => 'Low';

  @override
  String get backgroundPlay => 'Background music play';

  @override
  String get backgroundPlayDes =>
      'Enable/Disable music playing in background (App can be accessed from system tray when app is running in background)';

  @override
  String get downloadLocation => 'Download Location';

  @override
  String get cacheHomeScreenData => 'Cache home screen content data';

  @override
  String get cacheHomeScreenDataDes =>
      'Enable Caching home screen content data, Home screen will load instantly if this option is enabled';

  @override
  String get downloadingFormat => 'Downloading File Format';

  @override
  String get downloadingFormatDes =>
      'Select downloading file format. \"Opus\" will provide best quality';

  @override
  String get exportDowloadedFiles => 'Export downloaded files';

  @override
  String get exportDowloadedFilesDes =>
      'Click here to export downloaded file from inApp dir to external dir';

  @override
  String get exportedFileLocation => 'Downloaded file export location';

  @override
  String get export => 'Export';

  @override
  String get exporting => 'Exporting...';

  @override
  String get scanning => 'Scanning...';

  @override
  String get downFilesFound => 'downloaded files found';

  @override
  String get close => 'Close';

  @override
  String get exportMsg => 'Files successfully exported';

  @override
  String get equalizer => 'Equalizer';

  @override
  String get equalizerDes => 'Open system equalizer';

  @override
  String get clearImgCache => 'Clear images cache';

  @override
  String get clearImgCacheAlert => 'Images cache cleared successfully';

  @override
  String get clearImgCacheDes =>
      'Click here to clear cached thumbnails/images. (Not recommended unless want to refresh cached images data)';

  @override
  String get ignoreBatOpt => 'Ignore battery optimization';

  @override
  String get ignoreBatOptDes =>
      'If you are facing notification issues or playback stopped by system optimization, please enable this option';

  @override
  String get status => 'Status';

  @override
  String get enabled => 'Enabled';

  @override
  String get disabled => 'Disabled';

  @override
  String get resetToDefault => 'Restore default settings';

  @override
  String get resetToDefaultDes =>
      'Reset app settings to default (Restart required)';

  @override
  String get resetToDefaultMsg =>
      'Settings reset to default completed, Please restart app';

  @override
  String get github => 'GitHub';

  @override
  String get githubDes =>
      'View GitHub source code \nif you like this project, don\'t forget to give a ⭐';

  @override
  String get gitlab => 'GitLab';

  @override
  String get gitlabDes =>
      'View GitLab source code\nif you like this project, don\'t forget to give a ⭐';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get checkForUpdatesOnStartup => 'Check for updates on startup';

  @override
  String get openGitlab => 'Open GitLab';

  @override
  String get upToDate => 'You\'re right, mate – you\'re up to date';

  @override
  String get checkingForUpdates => 'Checking for updates…';

  @override
  String get by => 'by';

  @override
  String get urlSearchDes =>
      'Url detected click on it to open/play associated content';

  @override
  String get search => 'Search';

  @override
  String get searchDes => 'Songs, Playlist, Album or Artist';

  @override
  String get searchRes => 'Search results';

  @override
  String get for1 => 'for';

  @override
  String get videos => 'Videos';

  @override
  String get viewAll => 'View all';

  @override
  String get results => 'Results';

  @override
  String get nomatch => 'No Match found for';

  @override
  String get subscribers => 'subscribers';

  @override
  String get about => 'About';

  @override
  String get synced => 'Synced';

  @override
  String get plain => 'Plain';

  @override
  String get songInfo => 'Song Info';

  @override
  String get id => 'Id';

  @override
  String get title => 'Title';

  @override
  String get duration => 'Duration';

  @override
  String get audioCodec => 'Audio Codec';

  @override
  String get bitrate => 'Bitrate';

  @override
  String get loudnessDb => 'LoudnessDb';

  @override
  String get deleteDownloadedDataAlert =>
      'Successfully removed from downloads!';

  @override
  String get cancelTimerAlert => 'Sleep timer cancelled';

  @override
  String get sleepTimeSetAlert => 'Your sleep timer is set';

  @override
  String get radioNotAvailable => 'Radio not available for this artist!';

  @override
  String get songRemovedfromQueue => 'Removed from queue!';

  @override
  String get songRemovedfromQueueCurrSong =>
      'You can\'t remove currently playing song';

  @override
  String get songAddedToPlaylistAlert => 'Song added to playlist!';

  @override
  String get songAlreadyExists => 'Song already exists!';

  @override
  String get songAlreadyOfflineAlert => 'Song already offline in cache';

  @override
  String get songEnqueueAlert => 'Song enqueued!';

  @override
  String get songRemovedAlert => 'Removed from';

  @override
  String get errorOccuredAlert => 'Some error occured!';

  @override
  String get pipedplstSyncAlert => 'Piped playlist synced!';

  @override
  String get playlistCreatedAlert => 'Playlist created!';

  @override
  String get playlistCreatednsongAddedAlert => 'Playlist created & song added!';

  @override
  String get playlistRenameAlert => 'Renamed successfully!';

  @override
  String get playlistRemovedAlert => 'Playlist removed!';

  @override
  String get playlistBookmarkAddAlert => 'Playlist bookmarked!';

  @override
  String get playlistBookmarkRemoveAlert => 'Playlist bookmark removed!';

  @override
  String get albumBookmarkAddAlert => 'Album bookmarked!';

  @override
  String get albumBookmarkRemoveAlert => 'Album bookmark removed!';

  @override
  String get artistBookmarkAddAlert => 'Artist bookmarked!';

  @override
  String get artistBookmarkRemoveAlert => 'Artist bookmark removed!';

  @override
  String get lyricsNotAvailable => 'Lyrics not available!';

  @override
  String get syncedLyricsNotAvailable => 'Synced lyrics not available!';

  @override
  String get artistDesNotAvailable => 'Description not available!';

  @override
  String get newVersionAvailable => 'New version available!';

  @override
  String get version => 'Version';

  @override
  String get dontShowInfoAgain => 'Don\'t show this info again';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get notaSongVideo => 'Not a Song/Music-Video!';

  @override
  String get notaValidLink => 'Not a valid link!';

  @override
  String get operationFailed => 'Operation failed';

  @override
  String get goToDownloadPage => 'Click here to go to download page';

  @override
  String get local => 'Local';

  @override
  String get piped => 'Piped';

  @override
  String get link => 'Link';

  @override
  String get unLink => 'Unlink';

  @override
  String get hintApiUrl => 'API URL to Piped instance';

  @override
  String get customIns => 'Custom Instance';

  @override
  String get customInsSelectMsg => 'Please select Custom Instance';

  @override
  String get selectAuthInsMsg => 'Please select Authentication instance!';

  @override
  String get allFieldsReqMsg => 'All fields required';

  @override
  String get linkPipedDes => 'Link with piped for playlists';

  @override
  String get selectAuthIns => 'Select Auth Instance';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get linkAlert => 'Linked successfully!';

  @override
  String get unlinkAlert => 'Unlinked successfully!';

  @override
  String get playlistBlacklistAlert => 'Playlist blacklisted!';

  @override
  String get reset => 'Reset';

  @override
  String get blacklistPlstResetAlert => 'Reset successfully!';

  @override
  String get resetblacklistedplaylist => 'Reset blacklisted playlists';

  @override
  String get resetblacklistedplaylistDes =>
      'Reset all the piped blacklisted playlists';

  @override
  String get stopMusicOnTaskClear => 'Stop music on task clear';

  @override
  String get stopMusicOnTaskClearDes =>
      'Music playback will stop when App being swiped away from the task manager';

  @override
  String get backupAppData => 'Backup App data';

  @override
  String get androidBackupWarning =>
      'Not tested: Selecting the checkbox after downloading more than 60 files, process may consume a large amount of memory and could cause the phone or app to crash. Proceed at your own risk.';

  @override
  String get backupSettingsAndPlaylistsDes =>
      'Saves all settings, playlists and login data in a backup file';

  @override
  String get backup => 'Backup';

  @override
  String get letsStrart => 'Let\'s start..';

  @override
  String get processFiles => 'Processing files...';

  @override
  String get includeDownloadedFiles => 'Include downloded songs files';

  @override
  String get backupInProgress => 'Backup in progress...';

  @override
  String get restoreAppData => 'Restore App data';

  @override
  String get restoreSettingsAndPlaylistsDes =>
      'Restores all settings, login data and playlists from a backup file. Overwrites all current data';

  @override
  String get backupMsg => 'Backup successfully saved!';

  @override
  String get backFilesFound => 'databases found';

  @override
  String get restoreMsg =>
      'Successfully restored!\nChanges are applied on restart';

  @override
  String get restoring => 'Restoring...';

  @override
  String get restore => 'Restore';

  @override
  String get closeApp => 'Close App';

  @override
  String get restartApp => 'Restart App';

  @override
  String get exportPlaylist => 'Export Playlist';

  @override
  String get exportPlaylistCsv => 'Export Playlist as CSV';

  @override
  String get exportingPlaylist => 'Exporting playlist...';

  @override
  String get playlistExportedMsg => 'Playlist exported successfully to';

  @override
  String get exportError => 'Error exporting playlist';

  @override
  String get exportErrorPermission => 'Permission denied while exporting';

  @override
  String get exportErrorStorage => 'Not enough storage space';

  @override
  String get exportErrorFormat => 'Error formatting playlist data';

  @override
  String get importPlaylist => 'Import Playlist';

  @override
  String get importingPlaylist => 'Importing playlist...';

  @override
  String get importPlaylistDesc =>
      'Select a previously exported playlist JSON file to import';

  @override
  String get selectFile => 'Select File';

  @override
  String get playlistImportedMsg => 'Playlist imported successfully';

  @override
  String get importError => 'Error importing playlist';

  @override
  String get importErrorFileAccess => 'Could not access the selected file';

  @override
  String get importErrorFormat => 'Invalid file format';

  @override
  String get invalidPlaylistFile => 'Invalid playlist file structure';

  @override
  String get importErrorDatabase => 'Error saving to database';

  @override
  String get fileNotFound => 'File not found';

  @override
  String get importLargeFileNote =>
      'Note: Large playlists may take longer to import';

  @override
  String get exportPlaylistJson => 'Export playlist to JSON';

  @override
  String get exportPlaylistJsonSubtitle => 'This format can be imported';

  @override
  String get exportPlaylistCsvSubtitle => 'Can\'t be imported here';

  @override
  String get exportToYouTubeMusic => 'Export to Youtube music';

  @override
  String get exportToYouTubeMusicSubtitle =>
      'It will push your playlist (songs < 50) to current queue, don\'t forget to add to playlist/save after opening in YtMusic';

  @override
  String get linkCopied => 'Link copied to clipboard';

  @override
  String get keepScreenOnWhilePlaying => 'Keep screen on while playing';

  @override
  String get keepScreenOnWhilePlayingDes =>
      'If enabled, the device screen will stay awake while music is playing';

  @override
  String get autoRadio => 'Auto-start radio';

  @override
  String get autoRadioDes =>
      'Automatically start radio mode when playing a single song from YouTube Music';

  @override
  String get resyncLibraryNow => 'Resync Library Now';

  @override
  String get playbackDiagnosticsRelease => 'Playback diagnostics (release)';

  @override
  String get viewPlaybackDiagnostics => 'View playback diagnostics';

  @override
  String get viewPlaybackDiagnosticsSubtitle =>
      'Open logs and copy to clipboard';

  @override
  String get clearPlaybackDiagnostics => 'Clear playback diagnostics';

  @override
  String get clearPlaybackDiagnosticsSubtitle =>
      'Delete all stored diagnostic events';

  @override
  String get playbackDiagnostics => 'Playback diagnostics';

  @override
  String get toggleFormat => 'Toggle format';

  @override
  String get copyDiagnostics => 'Copy diagnostics';

  @override
  String get shrinkSidebar => 'shtink sidebar';

  @override
  String get playlistTypeLabel => 'PLAYLIST';

  @override
  String get playbackDiagnosticsCleared => 'Playback diagnostics cleared';

  @override
  String get hideNowPlaying => 'Hide Now Playing';

  @override
  String get showNowPlaying => 'Show Now Playing';

  @override
  String get autoLoginRequiredTitle => 'Log in to use Doudou';

  @override
  String get autoLoginRequiredMessage =>
      'Open Doudou on your phone and sign in to a server to start playing music here.';

  @override
  String get autoLoginRequiredAction => 'Open on phone';

  @override
  String get autoLoginRequiredDismiss => 'OK';

  @override
  String get protocol => 'Protocol';

  @override
  String get done => 'Done';

  @override
  String get syncing => 'Syncing...';

  @override
  String get sync => 'Sync';

  @override
  String get accounts => 'ACCOUNTS';

  @override
  String get user => 'USER';

  @override
  String get appearance => 'APPEARANCE';

  @override
  String get diagnosticsCopied => 'Diagnostics copied to clipboard';

  @override
  String get noDiagnosticsToCopy => 'No diagnostics to copy';

  @override
  String get refresh => 'Refresh';

  @override
  String eventsCount(int count, int max) {
    return 'Events: $count (showing up to $max)';
  }

  @override
  String get noDiagnosticsHint =>
      'No diagnostics yet.\nEnable diagnostics and reproduce the issue.';
}
