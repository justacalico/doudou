import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('en', 'AU'),
    Locale('ru'),
    Locale('zh')
  ];

  /// No description provided for @home.
  ///
  /// In en_AU, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @homeSubtitle.
  ///
  /// In en_AU, this message translates to:
  /// **'Recent listens, new additions and picks for you'**
  String get homeSubtitle;

  /// No description provided for @songs.
  ///
  /// In en_AU, this message translates to:
  /// **'Songs'**
  String get songs;

  /// No description provided for @playlists.
  ///
  /// In en_AU, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @albums.
  ///
  /// In en_AU, this message translates to:
  /// **'Albums'**
  String get albums;

  /// No description provided for @album.
  ///
  /// In en_AU, this message translates to:
  /// **'Album'**
  String get album;

  /// No description provided for @singles.
  ///
  /// In en_AU, this message translates to:
  /// **'Singles'**
  String get singles;

  /// No description provided for @artists.
  ///
  /// In en_AU, this message translates to:
  /// **'Artists'**
  String get artists;

  /// No description provided for @albumsFromYourArtists.
  ///
  /// In en_AU, this message translates to:
  /// **'From your artists'**
  String get albumsFromYourArtists;

  /// No description provided for @settings.
  ///
  /// In en_AU, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @library.
  ///
  /// In en_AU, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @libraryOverviewSubtitle.
  ///
  /// In en_AU, this message translates to:
  /// **'Overview / Your music collection.'**
  String get libraryOverviewSubtitle;

  /// No description provided for @yourLibrary.
  ///
  /// In en_AU, this message translates to:
  /// **'Your Library'**
  String get yourLibrary;

  /// No description provided for @manage.
  ///
  /// In en_AU, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @tracksInYourCollection.
  ///
  /// In en_AU, this message translates to:
  /// **'{count} tracks in your collection'**
  String tracksInYourCollection(int count);

  /// No description provided for @shuffleLikedSongs.
  ///
  /// In en_AU, this message translates to:
  /// **'Shuffle {count} liked songs'**
  String shuffleLikedSongs(int count);

  /// No description provided for @availableOffline.
  ///
  /// In en_AU, this message translates to:
  /// **'Available offline'**
  String get availableOffline;

  /// No description provided for @libSongs.
  ///
  /// In en_AU, this message translates to:
  /// **'Library Songs'**
  String get libSongs;

  /// No description provided for @libPlaylists.
  ///
  /// In en_AU, this message translates to:
  /// **'Library Playlists'**
  String get libPlaylists;

  /// No description provided for @libAlbums.
  ///
  /// In en_AU, this message translates to:
  /// **'Library Albums'**
  String get libAlbums;

  /// No description provided for @libArtists.
  ///
  /// In en_AU, this message translates to:
  /// **'Library Artists'**
  String get libArtists;

  /// No description provided for @communityplaylists.
  ///
  /// In en_AU, this message translates to:
  /// **'Community Playlists'**
  String get communityplaylists;

  /// No description provided for @featuredplaylists.
  ///
  /// In en_AU, this message translates to:
  /// **'Featured Playlists'**
  String get featuredplaylists;

  /// No description provided for @items.
  ///
  /// In en_AU, this message translates to:
  /// **'items'**
  String get items;

  /// No description provided for @networkError1.
  ///
  /// In en_AU, this message translates to:
  /// **'Oops network error!'**
  String get networkError1;

  /// No description provided for @retry.
  ///
  /// In en_AU, this message translates to:
  /// **'Retry!'**
  String get retry;

  /// No description provided for @noOfflineSong.
  ///
  /// In en_AU, this message translates to:
  /// **'No offline songs!'**
  String get noOfflineSong;

  /// No description provided for @recentlyPlayed.
  ///
  /// In en_AU, this message translates to:
  /// **'Recently Played'**
  String get recentlyPlayed;

  /// No description provided for @favorites.
  ///
  /// In en_AU, this message translates to:
  /// **'Favourites'**
  String get favorites;

  /// No description provided for @cachedOrOffline.
  ///
  /// In en_AU, this message translates to:
  /// **'Cached/Offline'**
  String get cachedOrOffline;

  /// No description provided for @downloads.
  ///
  /// In en_AU, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @emptyPlaylist.
  ///
  /// In en_AU, this message translates to:
  /// **'Empty playlist!'**
  String get emptyPlaylist;

  /// No description provided for @enqueueAll.
  ///
  /// In en_AU, this message translates to:
  /// **'Enqueue all'**
  String get enqueueAll;

  /// No description provided for @renamePlaylist.
  ///
  /// In en_AU, this message translates to:
  /// **'Rename Playlist'**
  String get renamePlaylist;

  /// No description provided for @removePlaylist.
  ///
  /// In en_AU, this message translates to:
  /// **'Remove playlist'**
  String get removePlaylist;

  /// No description provided for @createNewPlaylist.
  ///
  /// In en_AU, this message translates to:
  /// **'Create new playlist'**
  String get createNewPlaylist;

  /// No description provided for @reArrangePlaylist.
  ///
  /// In en_AU, this message translates to:
  /// **'Rearrange playlist'**
  String get reArrangePlaylist;

  /// No description provided for @reArrangeSongs.
  ///
  /// In en_AU, this message translates to:
  /// **'Rearrange songs'**
  String get reArrangeSongs;

  /// No description provided for @selectSongs.
  ///
  /// In en_AU, this message translates to:
  /// **'Select songs'**
  String get selectSongs;

  /// No description provided for @selectAll.
  ///
  /// In en_AU, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @removeMultiple.
  ///
  /// In en_AU, this message translates to:
  /// **'Remove multiple songs'**
  String get removeMultiple;

  /// No description provided for @addMultipleSongs.
  ///
  /// In en_AU, this message translates to:
  /// **'Add songs to playlist'**
  String get addMultipleSongs;

  /// No description provided for @cancel.
  ///
  /// In en_AU, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @create.
  ///
  /// In en_AU, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @rename.
  ///
  /// In en_AU, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @createnAdd.
  ///
  /// In en_AU, this message translates to:
  /// **'Create & add'**
  String get createnAdd;

  /// No description provided for @noBookmarks.
  ///
  /// In en_AU, this message translates to:
  /// **'No bookmarks!'**
  String get noBookmarks;

  /// No description provided for @addMusicToLibraryHint.
  ///
  /// In en_AU, this message translates to:
  /// **'Add music to your library to see it here, mate'**
  String get addMusicToLibraryHint;

  /// No description provided for @shuffleAll.
  ///
  /// In en_AU, this message translates to:
  /// **'Shuffle all'**
  String get shuffleAll;

  /// No description provided for @shuffleFavorites.
  ///
  /// In en_AU, this message translates to:
  /// **'Shuffle favorites'**
  String get shuffleFavorites;

  /// No description provided for @shuffleDownloads.
  ///
  /// In en_AU, this message translates to:
  /// **'Shuffle downloads'**
  String get shuffleDownloads;

  /// No description provided for @homeContinueListening.
  ///
  /// In en_AU, this message translates to:
  /// **'Continue listening'**
  String get homeContinueListening;

  /// No description provided for @homeContinueListeningSubtitle.
  ///
  /// In en_AU, this message translates to:
  /// **'Pick up where you left off'**
  String get homeContinueListeningSubtitle;

  /// No description provided for @homeBecauseYouLikeArtists.
  ///
  /// In en_AU, this message translates to:
  /// **'Because you like these artists'**
  String get homeBecauseYouLikeArtists;

  /// No description provided for @homeBecauseYouLikeArtistsSubtitle.
  ///
  /// In en_AU, this message translates to:
  /// **'More tracks from artists you already favorite'**
  String get homeBecauseYouLikeArtistsSubtitle;

  /// No description provided for @homePlaylistsSubtitle.
  ///
  /// In en_AU, this message translates to:
  /// **'Playlists from your collection'**
  String get homePlaylistsSubtitle;

  /// No description provided for @recentlyAddedAlbums.
  ///
  /// In en_AU, this message translates to:
  /// **'Recently added albums'**
  String get recentlyAddedAlbums;

  /// No description provided for @yourNewestAdditions.
  ///
  /// In en_AU, this message translates to:
  /// **'Your newest additions'**
  String get yourNewestAdditions;

  /// No description provided for @yourArtists.
  ///
  /// In en_AU, this message translates to:
  /// **'Your artists'**
  String get yourArtists;

  /// No description provided for @homeArtistsSubtitle.
  ///
  /// In en_AU, this message translates to:
  /// **'A rotating mix from your artists'**
  String get homeArtistsSubtitle;

  /// No description provided for @homeFreshPicks.
  ///
  /// In en_AU, this message translates to:
  /// **'Fresh picks'**
  String get homeFreshPicks;

  /// No description provided for @homeEmptyLibraryMessage.
  ///
  /// In en_AU, this message translates to:
  /// **'Your library is empty. Add some music to get started.'**
  String get homeEmptyLibraryMessage;

  /// No description provided for @homeSectionEmpty.
  ///
  /// In en_AU, this message translates to:
  /// **'Nothing here yet'**
  String get homeSectionEmpty;

  /// No description provided for @servers.
  ///
  /// In en_AU, this message translates to:
  /// **'Servers'**
  String get servers;

  /// No description provided for @addServer.
  ///
  /// In en_AU, this message translates to:
  /// **'Add server'**
  String get addServer;

  /// No description provided for @noServersConfigured.
  ///
  /// In en_AU, this message translates to:
  /// **'No servers configured yet'**
  String get noServersConfigured;

  /// No description provided for @activeServer.
  ///
  /// In en_AU, this message translates to:
  /// **'Active server'**
  String get activeServer;

  /// No description provided for @youtubeMusic.
  ///
  /// In en_AU, this message translates to:
  /// **'YouTube Music'**
  String get youtubeMusic;

  /// No description provided for @subsonic.
  ///
  /// In en_AU, this message translates to:
  /// **'Subsonic'**
  String get subsonic;

  /// No description provided for @jellyfin.
  ///
  /// In en_AU, this message translates to:
  /// **'Jellyfin'**
  String get jellyfin;

  /// No description provided for @plex.
  ///
  /// In en_AU, this message translates to:
  /// **'Plex'**
  String get plex;

  /// No description provided for @plexToken.
  ///
  /// In en_AU, this message translates to:
  /// **'Plex token'**
  String get plexToken;

  /// No description provided for @serverUrl.
  ///
  /// In en_AU, this message translates to:
  /// **'Server URL'**
  String get serverUrl;

  /// No description provided for @editServer.
  ///
  /// In en_AU, this message translates to:
  /// **'Edit server'**
  String get editServer;

  /// No description provided for @save.
  ///
  /// In en_AU, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @add.
  ///
  /// In en_AU, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @defaultLabel.
  ///
  /// In en_AU, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// No description provided for @youtubeMusicNoLogin.
  ///
  /// In en_AU, this message translates to:
  /// **'YouTube Music does not require login details.'**
  String get youtubeMusicNoLogin;

  /// No description provided for @serverUrlRequired.
  ///
  /// In en_AU, this message translates to:
  /// **'Server URL is required'**
  String get serverUrlRequired;

  /// No description provided for @testConnection.
  ///
  /// In en_AU, this message translates to:
  /// **'Test connection'**
  String get testConnection;

  /// No description provided for @connectionSuccess.
  ///
  /// In en_AU, this message translates to:
  /// **'Connection successful'**
  String get connectionSuccess;

  /// No description provided for @connectionFailed.
  ///
  /// In en_AU, this message translates to:
  /// **'Connection failed'**
  String get connectionFailed;

  /// No description provided for @playAll.
  ///
  /// In en_AU, this message translates to:
  /// **'Play All'**
  String get playAll;

  /// No description provided for @shuffle.
  ///
  /// In en_AU, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @artistLabel.
  ///
  /// In en_AU, this message translates to:
  /// **'ARTIST'**
  String get artistLabel;

  /// No description provided for @fromWikipedia.
  ///
  /// In en_AU, this message translates to:
  /// **'From Wikipedia'**
  String get fromWikipedia;

  /// No description provided for @songsCount.
  ///
  /// In en_AU, this message translates to:
  /// **'songs'**
  String get songsCount;

  /// No description provided for @addToLibrary.
  ///
  /// In en_AU, this message translates to:
  /// **'Add to library'**
  String get addToLibrary;

  /// No description provided for @noSongsInLibrary.
  ///
  /// In en_AU, this message translates to:
  /// **'No songs in library'**
  String get noSongsInLibrary;

  /// No description provided for @favoritesEmpty.
  ///
  /// In en_AU, this message translates to:
  /// **'Favourites is empty'**
  String get favoritesEmpty;

  /// No description provided for @startRadio.
  ///
  /// In en_AU, this message translates to:
  /// **'Start radio'**
  String get startRadio;

  /// No description provided for @playNext.
  ///
  /// In en_AU, this message translates to:
  /// **'Play next'**
  String get playNext;

  /// No description provided for @addToPlaylist.
  ///
  /// In en_AU, this message translates to:
  /// **'Add to playlist'**
  String get addToPlaylist;

  /// No description provided for @noLibPlaylist.
  ///
  /// In en_AU, this message translates to:
  /// **'You don\'t have any lib playlist, mate!'**
  String get noLibPlaylist;

  /// No description provided for @enqueueSong.
  ///
  /// In en_AU, this message translates to:
  /// **'Enqueue this song'**
  String get enqueueSong;

  /// No description provided for @goToAlbum.
  ///
  /// In en_AU, this message translates to:
  /// **'Go to album'**
  String get goToAlbum;

  /// No description provided for @viewArtist.
  ///
  /// In en_AU, this message translates to:
  /// **'View Artist'**
  String get viewArtist;

  /// No description provided for @openIn.
  ///
  /// In en_AU, this message translates to:
  /// **'Open in'**
  String get openIn;

  /// No description provided for @shareSong.
  ///
  /// In en_AU, this message translates to:
  /// **'Share this song'**
  String get shareSong;

  /// No description provided for @removeFromPlaylist.
  ///
  /// In en_AU, this message translates to:
  /// **'Remove from playlist'**
  String get removeFromPlaylist;

  /// No description provided for @removeFromQueue.
  ///
  /// In en_AU, this message translates to:
  /// **'Remove from queue'**
  String get removeFromQueue;

  /// No description provided for @queueShufflingDeniedMsg.
  ///
  /// In en_AU, this message translates to:
  /// **'Queue can\'t be shuffled when shuffle mode is enabled'**
  String get queueShufflingDeniedMsg;

  /// No description provided for @queuerearrangingDeniedMsg.
  ///
  /// In en_AU, this message translates to:
  /// **'Queue can\'t be rearranged when shuffle mode is enabled'**
  String get queuerearrangingDeniedMsg;

  /// No description provided for @songNotPlayable.
  ///
  /// In en_AU, this message translates to:
  /// **'Song is not playable due to server restriction!'**
  String get songNotPlayable;

  /// No description provided for @upNext.
  ///
  /// In en_AU, this message translates to:
  /// **'Up Next'**
  String get upNext;

  /// No description provided for @lyrics.
  ///
  /// In en_AU, this message translates to:
  /// **'Lyrics'**
  String get lyrics;

  /// No description provided for @fromAlbum.
  ///
  /// In en_AU, this message translates to:
  /// **'From: '**
  String get fromAlbum;

  /// No description provided for @byArtist.
  ///
  /// In en_AU, this message translates to:
  /// **'By: '**
  String get byArtist;

  /// No description provided for @playingFrom.
  ///
  /// In en_AU, this message translates to:
  /// **'Playing from '**
  String get playingFrom;

  /// No description provided for @playingfromAlbum.
  ///
  /// In en_AU, this message translates to:
  /// **'PLAYING FROM ALBUM'**
  String get playingfromAlbum;

  /// No description provided for @playingfromPlaylist.
  ///
  /// In en_AU, this message translates to:
  /// **'PLAYING FROM PLAYLIST'**
  String get playingfromPlaylist;

  /// No description provided for @playingfromSelection.
  ///
  /// In en_AU, this message translates to:
  /// **'PLAYING FROM SELECTION'**
  String get playingfromSelection;

  /// No description provided for @playingfromArtist.
  ///
  /// In en_AU, this message translates to:
  /// **'PLAYING FROM ARTIST'**
  String get playingfromArtist;

  /// No description provided for @randomSelection.
  ///
  /// In en_AU, this message translates to:
  /// **'Random Selection'**
  String get randomSelection;

  /// No description provided for @randomRadio.
  ///
  /// In en_AU, this message translates to:
  /// **'Random Radio'**
  String get randomRadio;

  /// No description provided for @playnextMsg.
  ///
  /// In en_AU, this message translates to:
  /// **'Upcoming'**
  String get playnextMsg;

  /// No description provided for @shuffleQueue.
  ///
  /// In en_AU, this message translates to:
  /// **'Shuffle Queue'**
  String get shuffleQueue;

  /// No description provided for @queueLoop.
  ///
  /// In en_AU, this message translates to:
  /// **'Queue loop'**
  String get queueLoop;

  /// No description provided for @queueLoopNotDisMsg1.
  ///
  /// In en_AU, this message translates to:
  /// **'Queue loop mode cannot be disabled when shuffle mode is enabled.'**
  String get queueLoopNotDisMsg1;

  /// No description provided for @queueLoopNotDisMsg2.
  ///
  /// In en_AU, this message translates to:
  /// **'Queue loop mode cannot be enabled in radio mode.'**
  String get queueLoopNotDisMsg2;

  /// No description provided for @removeFromLib.
  ///
  /// In en_AU, this message translates to:
  /// **'Remove from Library Songs'**
  String get removeFromLib;

  /// No description provided for @sleepTimer.
  ///
  /// In en_AU, this message translates to:
  /// **'Sleep Timer'**
  String get sleepTimer;

  /// No description provided for @add5Minutes.
  ///
  /// In en_AU, this message translates to:
  /// **'Add 5 minutes'**
  String get add5Minutes;

  /// No description provided for @cancelTimer.
  ///
  /// In en_AU, this message translates to:
  /// **'Cancel timer'**
  String get cancelTimer;

  /// No description provided for @deleteDownloadData.
  ///
  /// In en_AU, this message translates to:
  /// **'Remove from downloads'**
  String get deleteDownloadData;

  /// No description provided for @minutes.
  ///
  /// In en_AU, this message translates to:
  /// **'minutes'**
  String get minutes;

  /// No description provided for @endOfThisSong.
  ///
  /// In en_AU, this message translates to:
  /// **'End of this song'**
  String get endOfThisSong;

  /// No description provided for @appInfo.
  ///
  /// In en_AU, this message translates to:
  /// **'App Info'**
  String get appInfo;

  /// No description provided for @download.
  ///
  /// In en_AU, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @misc.
  ///
  /// In en_AU, this message translates to:
  /// **'Misc'**
  String get misc;

  /// No description provided for @autoDownFavSong.
  ///
  /// In en_AU, this message translates to:
  /// **'Auto download favorite songs'**
  String get autoDownFavSong;

  /// No description provided for @autoDownFavSongDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Automatically download favorite songs when added to favorites'**
  String get autoDownFavSongDes;

  /// No description provided for @networkError.
  ///
  /// In en_AU, this message translates to:
  /// **'Network error! Check your network connection.'**
  String get networkError;

  /// No description provided for @downloadError2.
  ///
  /// In en_AU, this message translates to:
  /// **'Requested song is not downloadable due to server restriction. You may try again'**
  String get downloadError2;

  /// No description provided for @downloadError3.
  ///
  /// In en_AU, this message translates to:
  /// **'Downloading failed due to network/stream error! Please try again'**
  String get downloadError3;

  /// No description provided for @musicPlayback.
  ///
  /// In en_AU, this message translates to:
  /// **'Music & Playback'**
  String get musicPlayback;

  /// No description provided for @content.
  ///
  /// In en_AU, this message translates to:
  /// **'Content'**
  String get content;

  /// No description provided for @personalisation.
  ///
  /// In en_AU, this message translates to:
  /// **'Personalisation'**
  String get personalisation;

  /// No description provided for @themeMode.
  ///
  /// In en_AU, this message translates to:
  /// **'Theme Mode'**
  String get themeMode;

  /// No description provided for @dynamicTheme.
  ///
  /// In en_AU, this message translates to:
  /// **'Dynamic'**
  String get dynamicTheme;

  /// No description provided for @dynamicColor.
  ///
  /// In en_AU, this message translates to:
  /// **'Dynamic Colour'**
  String get dynamicColor;

  /// No description provided for @systemDefault.
  ///
  /// In en_AU, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @dark.
  ///
  /// In en_AU, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @light.
  ///
  /// In en_AU, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @oled.
  ///
  /// In en_AU, this message translates to:
  /// **'OLED'**
  String get oled;

  /// No description provided for @language.
  ///
  /// In en_AU, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @playerUi.
  ///
  /// In en_AU, this message translates to:
  /// **'Player Ui'**
  String get playerUi;

  /// No description provided for @playerUiDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Select player user interface'**
  String get playerUiDes;

  /// No description provided for @standard.
  ///
  /// In en_AU, this message translates to:
  /// **'Standard'**
  String get standard;

  /// No description provided for @gesture.
  ///
  /// In en_AU, this message translates to:
  /// **'Gesture'**
  String get gesture;

  /// No description provided for @languageDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Set App language'**
  String get languageDes;

  /// No description provided for @setDiscoverContent.
  ///
  /// In en_AU, this message translates to:
  /// **'Set discover content'**
  String get setDiscoverContent;

  /// No description provided for @quickpicks.
  ///
  /// In en_AU, this message translates to:
  /// **'Quick Picks'**
  String get quickpicks;

  /// No description provided for @discover.
  ///
  /// In en_AU, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @trending.
  ///
  /// In en_AU, this message translates to:
  /// **'Trending'**
  String get trending;

  /// No description provided for @topmusicvideos.
  ///
  /// In en_AU, this message translates to:
  /// **'Top Music Videos'**
  String get topmusicvideos;

  /// No description provided for @basedOnLast.
  ///
  /// In en_AU, this message translates to:
  /// **'Based on last interaction'**
  String get basedOnLast;

  /// No description provided for @restoreLastPlaybackSession.
  ///
  /// In en_AU, this message translates to:
  /// **'Restore last playback session'**
  String get restoreLastPlaybackSession;

  /// No description provided for @restoreLastPlaybackSessionDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Automatically restore the last playback session on app start'**
  String get restoreLastPlaybackSessionDes;

  /// No description provided for @autoOpenPlayer.
  ///
  /// In en_AU, this message translates to:
  /// **'Auto open player screen'**
  String get autoOpenPlayer;

  /// No description provided for @autoOpenPlayerDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Enable/disable auto opening of player full screen on selection of song for play'**
  String get autoOpenPlayerDes;

  /// No description provided for @homeContentCount.
  ///
  /// In en_AU, this message translates to:
  /// **'Home content count'**
  String get homeContentCount;

  /// No description provided for @homeContentCountDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Select the number of initial homescreen-content(approx). Lesser results faster loading'**
  String get homeContentCountDes;

  /// No description provided for @enableBottomNav.
  ///
  /// In en_AU, this message translates to:
  /// **'Use bottom navigation bar'**
  String get enableBottomNav;

  /// No description provided for @enableBottomNavDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Force bottom navigation on larger screens'**
  String get enableBottomNavDes;

  /// No description provided for @sidebarMode.
  ///
  /// In en_AU, this message translates to:
  /// **'Sidebar behavior'**
  String get sidebarMode;

  /// No description provided for @sidebarModeDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Control whether the sidebar is automatic, always collapsed, or always full width.'**
  String get sidebarModeDes;

  /// No description provided for @sidebarModeAuto.
  ///
  /// In en_AU, this message translates to:
  /// **'Auto'**
  String get sidebarModeAuto;

  /// No description provided for @sidebarModeCollapsed.
  ///
  /// In en_AU, this message translates to:
  /// **'Collapsed'**
  String get sidebarModeCollapsed;

  /// No description provided for @sidebarModeExpanded.
  ///
  /// In en_AU, this message translates to:
  /// **'Full view'**
  String get sidebarModeExpanded;

  /// No description provided for @dynamicColorDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Dynamic theme using a fixed colour (not now playing).'**
  String get dynamicColorDes;

  /// No description provided for @useCustomAccentColor.
  ///
  /// In en_AU, this message translates to:
  /// **'Use custom accent colour'**
  String get useCustomAccentColor;

  /// No description provided for @useCustomAccentColorDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Apply your selected accent colour across all theme modes.'**
  String get useCustomAccentColorDes;

  /// No description provided for @customAccentColor.
  ///
  /// In en_AU, this message translates to:
  /// **'Custom accent colour'**
  String get customAccentColor;

  /// No description provided for @customAccentColorDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Pick the accent colour used across the app.'**
  String get customAccentColorDes;

  /// No description provided for @lyricsDynamicColor.
  ///
  /// In en_AU, this message translates to:
  /// **'Lyrics change accent colour'**
  String get lyricsDynamicColor;

  /// No description provided for @lyricsDynamicColorDes.
  ///
  /// In en_AU, this message translates to:
  /// **'When a song has synced lyrics, colour words in the lyrics can change the app accent (Dynamic theme only).'**
  String get lyricsDynamicColorDes;

  /// No description provided for @syncedLyricsHighlightStyle.
  ///
  /// In en_AU, this message translates to:
  /// **'Synced lyrics highlight style'**
  String get syncedLyricsHighlightStyle;

  /// No description provided for @syncedLyricsHighlightStyleDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Choose how the active synced lyric line is highlighted.'**
  String get syncedLyricsHighlightStyleDes;

  /// No description provided for @lyricsHighlightBlock.
  ///
  /// In en_AU, this message translates to:
  /// **'Block highlight'**
  String get lyricsHighlightBlock;

  /// No description provided for @lyricsHighlightKaraoke.
  ///
  /// In en_AU, this message translates to:
  /// **'Karaoke fill'**
  String get lyricsHighlightKaraoke;

  /// No description provided for @pickDynamicColor.
  ///
  /// In en_AU, this message translates to:
  /// **'Pick dynamic colour'**
  String get pickDynamicColor;

  /// No description provided for @advanced.
  ///
  /// In en_AU, this message translates to:
  /// **'Advanced…'**
  String get advanced;

  /// No description provided for @change.
  ///
  /// In en_AU, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @cacheSongs.
  ///
  /// In en_AU, this message translates to:
  /// **'Cache Songs'**
  String get cacheSongs;

  /// No description provided for @cacheSongsDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Caching songs while playing for future/offline playback, it will take additional space on your device'**
  String get cacheSongsDes;

  /// No description provided for @skipSilence.
  ///
  /// In en_AU, this message translates to:
  /// **'Skip silence'**
  String get skipSilence;

  /// No description provided for @skipSilenceDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Silence will be skipped in music playback'**
  String get skipSilenceDes;

  /// No description provided for @loudnessNormalization.
  ///
  /// In en_AU, this message translates to:
  /// **'Loudness normalization'**
  String get loudnessNormalization;

  /// No description provided for @loudnessNormalizationDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Sets same lavel of loudness for all songs (Experimental) (Will not work on songs downloaded on previous version(< v1.10.0))'**
  String get loudnessNormalizationDes;

  /// No description provided for @streamingQuality.
  ///
  /// In en_AU, this message translates to:
  /// **'Streaming quality'**
  String get streamingQuality;

  /// No description provided for @streamingQualityDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Quality of music stream'**
  String get streamingQualityDes;

  /// No description provided for @disableTransitionAnimation.
  ///
  /// In en_AU, this message translates to:
  /// **'Disable transition animation'**
  String get disableTransitionAnimation;

  /// No description provided for @disableTransitionAnimationDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Enable this option to disable tab transition animation'**
  String get disableTransitionAnimationDes;

  /// No description provided for @animationSpeed.
  ///
  /// In en_AU, this message translates to:
  /// **'Animation speed'**
  String get animationSpeed;

  /// No description provided for @animationSpeedDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Control the speed of app transitions or turn them off.'**
  String get animationSpeedDes;

  /// No description provided for @animationSpeedOff.
  ///
  /// In en_AU, this message translates to:
  /// **'Off'**
  String get animationSpeedOff;

  /// No description provided for @animationSpeedFast.
  ///
  /// In en_AU, this message translates to:
  /// **'Fast (default)'**
  String get animationSpeedFast;

  /// No description provided for @animationSpeedNormal.
  ///
  /// In en_AU, this message translates to:
  /// **'Normal'**
  String get animationSpeedNormal;

  /// No description provided for @animationSpeedSlow.
  ///
  /// In en_AU, this message translates to:
  /// **'Slow'**
  String get animationSpeedSlow;

  /// No description provided for @enableSlidableAction.
  ///
  /// In en_AU, this message translates to:
  /// **'Enable slidable actions'**
  String get enableSlidableAction;

  /// No description provided for @enableSlidableActionDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Enable slidable actions on song tile'**
  String get enableSlidableActionDes;

  /// No description provided for @more.
  ///
  /// In en_AU, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @loading.
  ///
  /// In en_AU, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @imported.
  ///
  /// In en_AU, this message translates to:
  /// **'Imported'**
  String get imported;

  /// No description provided for @importedPlaylist.
  ///
  /// In en_AU, this message translates to:
  /// **'Imported playlist'**
  String get importedPlaylist;

  /// No description provided for @listBookmarkRemoveAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Bookmark removed!'**
  String get listBookmarkRemoveAlert;

  /// No description provided for @permissionDenied.
  ///
  /// In en_AU, this message translates to:
  /// **'Permission denied'**
  String get permissionDenied;

  /// No description provided for @unknownArtist.
  ///
  /// In en_AU, this message translates to:
  /// **'Unknown Artist'**
  String get unknownArtist;

  /// No description provided for @unknownAlbum.
  ///
  /// In en_AU, this message translates to:
  /// **'Unknown Album'**
  String get unknownAlbum;

  /// No description provided for @yourMusicCollection.
  ///
  /// In en_AU, this message translates to:
  /// **'Your music collection'**
  String get yourMusicCollection;

  /// No description provided for @sortByName.
  ///
  /// In en_AU, this message translates to:
  /// **'Sort by name'**
  String get sortByName;

  /// No description provided for @sortByDate.
  ///
  /// In en_AU, this message translates to:
  /// **'Sort by date'**
  String get sortByDate;

  /// No description provided for @sortByDuration.
  ///
  /// In en_AU, this message translates to:
  /// **'Sort by duration'**
  String get sortByDuration;

  /// No description provided for @sortAscendNDescend.
  ///
  /// In en_AU, this message translates to:
  /// **'Ascending & Descending'**
  String get sortAscendNDescend;

  /// No description provided for @high.
  ///
  /// In en_AU, this message translates to:
  /// **'High'**
  String get high;

  /// No description provided for @low.
  ///
  /// In en_AU, this message translates to:
  /// **'Low'**
  String get low;

  /// No description provided for @backgroundPlay.
  ///
  /// In en_AU, this message translates to:
  /// **'Background music play'**
  String get backgroundPlay;

  /// No description provided for @backgroundPlayDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Enable/Disable music playing in background (App can be accessed from system tray when app is running in background)'**
  String get backgroundPlayDes;

  /// No description provided for @downloadLocation.
  ///
  /// In en_AU, this message translates to:
  /// **'Download Location'**
  String get downloadLocation;

  /// No description provided for @cacheHomeScreenData.
  ///
  /// In en_AU, this message translates to:
  /// **'Cache home screen content data'**
  String get cacheHomeScreenData;

  /// No description provided for @cacheHomeScreenDataDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Enable Caching home screen content data, Home screen will load instantly if this option is enabled'**
  String get cacheHomeScreenDataDes;

  /// No description provided for @downloadingFormat.
  ///
  /// In en_AU, this message translates to:
  /// **'Downloading File Format'**
  String get downloadingFormat;

  /// No description provided for @downloadingFormatDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Select downloading file format. \"Opus\" will provide best quality'**
  String get downloadingFormatDes;

  /// No description provided for @exportDowloadedFiles.
  ///
  /// In en_AU, this message translates to:
  /// **'Export downloaded files'**
  String get exportDowloadedFiles;

  /// No description provided for @exportDowloadedFilesDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Click here to export downloaded file from inApp dir to external dir'**
  String get exportDowloadedFilesDes;

  /// No description provided for @exportedFileLocation.
  ///
  /// In en_AU, this message translates to:
  /// **'Downloaded file export location'**
  String get exportedFileLocation;

  /// No description provided for @export.
  ///
  /// In en_AU, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @exporting.
  ///
  /// In en_AU, this message translates to:
  /// **'Exporting...'**
  String get exporting;

  /// No description provided for @scanning.
  ///
  /// In en_AU, this message translates to:
  /// **'Scanning...'**
  String get scanning;

  /// No description provided for @downFilesFound.
  ///
  /// In en_AU, this message translates to:
  /// **'downloaded files found'**
  String get downFilesFound;

  /// No description provided for @close.
  ///
  /// In en_AU, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @exportMsg.
  ///
  /// In en_AU, this message translates to:
  /// **'Files successfully exported'**
  String get exportMsg;

  /// No description provided for @equalizer.
  ///
  /// In en_AU, this message translates to:
  /// **'Equalizer'**
  String get equalizer;

  /// No description provided for @equalizerDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Open system equalizer'**
  String get equalizerDes;

  /// No description provided for @clearImgCache.
  ///
  /// In en_AU, this message translates to:
  /// **'Clear images cache'**
  String get clearImgCache;

  /// No description provided for @clearImgCacheAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Images cache cleared successfully'**
  String get clearImgCacheAlert;

  /// No description provided for @clearImgCacheDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Click here to clear cached thumbnails/images. (Not recommended unless want to refresh cached images data)'**
  String get clearImgCacheDes;

  /// No description provided for @ignoreBatOpt.
  ///
  /// In en_AU, this message translates to:
  /// **'Ignore battery optimization'**
  String get ignoreBatOpt;

  /// No description provided for @ignoreBatOptDes.
  ///
  /// In en_AU, this message translates to:
  /// **'If you are facing notification issues or playback stopped by system optimization, please enable this option'**
  String get ignoreBatOptDes;

  /// No description provided for @status.
  ///
  /// In en_AU, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @enabled.
  ///
  /// In en_AU, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In en_AU, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @resetToDefault.
  ///
  /// In en_AU, this message translates to:
  /// **'Restore default settings'**
  String get resetToDefault;

  /// No description provided for @resetToDefaultDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Reset app settings to default (Restart required)'**
  String get resetToDefaultDes;

  /// No description provided for @resetToDefaultMsg.
  ///
  /// In en_AU, this message translates to:
  /// **'Settings reset to default completed, Please restart app'**
  String get resetToDefaultMsg;

  /// No description provided for @github.
  ///
  /// In en_AU, this message translates to:
  /// **'GitHub'**
  String get github;

  /// No description provided for @githubDes.
  ///
  /// In en_AU, this message translates to:
  /// **'View GitHub source code \\nif you like this project, don\'t forget to give a ⭐'**
  String get githubDes;

  /// No description provided for @gitlab.
  ///
  /// In en_AU, this message translates to:
  /// **'GitLab'**
  String get gitlab;

  /// No description provided for @gitlabDes.
  ///
  /// In en_AU, this message translates to:
  /// **'View GitLab source code\\nif you like this project, don\'t forget to give a ⭐'**
  String get gitlabDes;

  /// No description provided for @checkForUpdates.
  ///
  /// In en_AU, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @checkForUpdatesOnStartup.
  ///
  /// In en_AU, this message translates to:
  /// **'Check for updates on startup'**
  String get checkForUpdatesOnStartup;

  /// No description provided for @openGitlab.
  ///
  /// In en_AU, this message translates to:
  /// **'Open GitLab'**
  String get openGitlab;

  /// No description provided for @upToDate.
  ///
  /// In en_AU, this message translates to:
  /// **'You\'re right, mate – you\'re up to date'**
  String get upToDate;

  /// No description provided for @checkingForUpdates.
  ///
  /// In en_AU, this message translates to:
  /// **'Checking for updates…'**
  String get checkingForUpdates;

  /// No description provided for @by.
  ///
  /// In en_AU, this message translates to:
  /// **'by'**
  String get by;

  /// No description provided for @urlSearchDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Url detected click on it to open/play associated content'**
  String get urlSearchDes;

  /// No description provided for @search.
  ///
  /// In en_AU, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Songs, Playlist, Album or Artist'**
  String get searchDes;

  /// No description provided for @searchRes.
  ///
  /// In en_AU, this message translates to:
  /// **'Search results'**
  String get searchRes;

  /// No description provided for @for1.
  ///
  /// In en_AU, this message translates to:
  /// **'for'**
  String get for1;

  /// No description provided for @videos.
  ///
  /// In en_AU, this message translates to:
  /// **'Videos'**
  String get videos;

  /// No description provided for @viewAll.
  ///
  /// In en_AU, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @results.
  ///
  /// In en_AU, this message translates to:
  /// **'Results'**
  String get results;

  /// No description provided for @nomatch.
  ///
  /// In en_AU, this message translates to:
  /// **'No Match found for'**
  String get nomatch;

  /// No description provided for @subscribers.
  ///
  /// In en_AU, this message translates to:
  /// **'subscribers'**
  String get subscribers;

  /// No description provided for @about.
  ///
  /// In en_AU, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @synced.
  ///
  /// In en_AU, this message translates to:
  /// **'Synced'**
  String get synced;

  /// No description provided for @plain.
  ///
  /// In en_AU, this message translates to:
  /// **'Plain'**
  String get plain;

  /// No description provided for @songInfo.
  ///
  /// In en_AU, this message translates to:
  /// **'Song Info'**
  String get songInfo;

  /// No description provided for @id.
  ///
  /// In en_AU, this message translates to:
  /// **'Id'**
  String get id;

  /// No description provided for @title.
  ///
  /// In en_AU, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @duration.
  ///
  /// In en_AU, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @audioCodec.
  ///
  /// In en_AU, this message translates to:
  /// **'Audio Codec'**
  String get audioCodec;

  /// No description provided for @bitrate.
  ///
  /// In en_AU, this message translates to:
  /// **'Bitrate'**
  String get bitrate;

  /// No description provided for @loudnessDb.
  ///
  /// In en_AU, this message translates to:
  /// **'LoudnessDb'**
  String get loudnessDb;

  /// No description provided for @deleteDownloadedDataAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Successfully removed from downloads!'**
  String get deleteDownloadedDataAlert;

  /// No description provided for @cancelTimerAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Sleep timer cancelled'**
  String get cancelTimerAlert;

  /// No description provided for @sleepTimeSetAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Your sleep timer is set'**
  String get sleepTimeSetAlert;

  /// No description provided for @radioNotAvailable.
  ///
  /// In en_AU, this message translates to:
  /// **'Radio not available for this artist!'**
  String get radioNotAvailable;

  /// No description provided for @songRemovedfromQueue.
  ///
  /// In en_AU, this message translates to:
  /// **'Removed from queue!'**
  String get songRemovedfromQueue;

  /// No description provided for @songRemovedfromQueueCurrSong.
  ///
  /// In en_AU, this message translates to:
  /// **'You can\'t remove currently playing song'**
  String get songRemovedfromQueueCurrSong;

  /// No description provided for @songAddedToPlaylistAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Song added to playlist!'**
  String get songAddedToPlaylistAlert;

  /// No description provided for @songAlreadyExists.
  ///
  /// In en_AU, this message translates to:
  /// **'Song already exists!'**
  String get songAlreadyExists;

  /// No description provided for @songAlreadyOfflineAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Song already offline in cache'**
  String get songAlreadyOfflineAlert;

  /// No description provided for @songEnqueueAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Song enqueued!'**
  String get songEnqueueAlert;

  /// No description provided for @songRemovedAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Removed from'**
  String get songRemovedAlert;

  /// No description provided for @errorOccuredAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Some error occured!'**
  String get errorOccuredAlert;

  /// No description provided for @pipedplstSyncAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Piped playlist synced!'**
  String get pipedplstSyncAlert;

  /// No description provided for @playlistCreatedAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Playlist created!'**
  String get playlistCreatedAlert;

  /// No description provided for @playlistCreatednsongAddedAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Playlist created & song added!'**
  String get playlistCreatednsongAddedAlert;

  /// No description provided for @playlistRenameAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Renamed successfully!'**
  String get playlistRenameAlert;

  /// No description provided for @playlistRemovedAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Playlist removed!'**
  String get playlistRemovedAlert;

  /// No description provided for @playlistBookmarkAddAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Playlist bookmarked!'**
  String get playlistBookmarkAddAlert;

  /// No description provided for @playlistBookmarkRemoveAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Playlist bookmark removed!'**
  String get playlistBookmarkRemoveAlert;

  /// No description provided for @albumBookmarkAddAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Album bookmarked!'**
  String get albumBookmarkAddAlert;

  /// No description provided for @albumBookmarkRemoveAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Album bookmark removed!'**
  String get albumBookmarkRemoveAlert;

  /// No description provided for @artistBookmarkAddAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Artist bookmarked!'**
  String get artistBookmarkAddAlert;

  /// No description provided for @artistBookmarkRemoveAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Artist bookmark removed!'**
  String get artistBookmarkRemoveAlert;

  /// No description provided for @lyricsNotAvailable.
  ///
  /// In en_AU, this message translates to:
  /// **'Lyrics not available!'**
  String get lyricsNotAvailable;

  /// No description provided for @syncedLyricsNotAvailable.
  ///
  /// In en_AU, this message translates to:
  /// **'Synced lyrics not available!'**
  String get syncedLyricsNotAvailable;

  /// No description provided for @artistDesNotAvailable.
  ///
  /// In en_AU, this message translates to:
  /// **'Description not available!'**
  String get artistDesNotAvailable;

  /// No description provided for @newVersionAvailable.
  ///
  /// In en_AU, this message translates to:
  /// **'New version available!'**
  String get newVersionAvailable;

  /// No description provided for @version.
  ///
  /// In en_AU, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @dontShowInfoAgain.
  ///
  /// In en_AU, this message translates to:
  /// **'Don\'t show this info again'**
  String get dontShowInfoAgain;

  /// No description provided for @dismiss.
  ///
  /// In en_AU, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @notaSongVideo.
  ///
  /// In en_AU, this message translates to:
  /// **'Not a Song/Music-Video!'**
  String get notaSongVideo;

  /// No description provided for @notaValidLink.
  ///
  /// In en_AU, this message translates to:
  /// **'Not a valid link!'**
  String get notaValidLink;

  /// No description provided for @operationFailed.
  ///
  /// In en_AU, this message translates to:
  /// **'Operation failed'**
  String get operationFailed;

  /// No description provided for @goToDownloadPage.
  ///
  /// In en_AU, this message translates to:
  /// **'Click here to go to download page'**
  String get goToDownloadPage;

  /// No description provided for @local.
  ///
  /// In en_AU, this message translates to:
  /// **'Local'**
  String get local;

  /// No description provided for @piped.
  ///
  /// In en_AU, this message translates to:
  /// **'Piped'**
  String get piped;

  /// No description provided for @link.
  ///
  /// In en_AU, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @unLink.
  ///
  /// In en_AU, this message translates to:
  /// **'Unlink'**
  String get unLink;

  /// No description provided for @hintApiUrl.
  ///
  /// In en_AU, this message translates to:
  /// **'API URL to Piped instance'**
  String get hintApiUrl;

  /// No description provided for @customIns.
  ///
  /// In en_AU, this message translates to:
  /// **'Custom Instance'**
  String get customIns;

  /// No description provided for @customInsSelectMsg.
  ///
  /// In en_AU, this message translates to:
  /// **'Please select Custom Instance'**
  String get customInsSelectMsg;

  /// No description provided for @selectAuthInsMsg.
  ///
  /// In en_AU, this message translates to:
  /// **'Please select Authentication instance!'**
  String get selectAuthInsMsg;

  /// No description provided for @allFieldsReqMsg.
  ///
  /// In en_AU, this message translates to:
  /// **'All fields required'**
  String get allFieldsReqMsg;

  /// No description provided for @linkPipedDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Link with piped for playlists'**
  String get linkPipedDes;

  /// No description provided for @selectAuthIns.
  ///
  /// In en_AU, this message translates to:
  /// **'Select Auth Instance'**
  String get selectAuthIns;

  /// No description provided for @username.
  ///
  /// In en_AU, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en_AU, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @linkAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Linked successfully!'**
  String get linkAlert;

  /// No description provided for @unlinkAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Unlinked successfully!'**
  String get unlinkAlert;

  /// No description provided for @playlistBlacklistAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Playlist blacklisted!'**
  String get playlistBlacklistAlert;

  /// No description provided for @reset.
  ///
  /// In en_AU, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @blacklistPlstResetAlert.
  ///
  /// In en_AU, this message translates to:
  /// **'Reset successfully!'**
  String get blacklistPlstResetAlert;

  /// No description provided for @resetblacklistedplaylist.
  ///
  /// In en_AU, this message translates to:
  /// **'Reset blacklisted playlists'**
  String get resetblacklistedplaylist;

  /// No description provided for @resetblacklistedplaylistDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Reset all the piped blacklisted playlists'**
  String get resetblacklistedplaylistDes;

  /// No description provided for @stopMusicOnTaskClear.
  ///
  /// In en_AU, this message translates to:
  /// **'Stop music on task clear'**
  String get stopMusicOnTaskClear;

  /// No description provided for @stopMusicOnTaskClearDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Music playback will stop when App being swiped away from the task manager'**
  String get stopMusicOnTaskClearDes;

  /// No description provided for @backupAppData.
  ///
  /// In en_AU, this message translates to:
  /// **'Backup App data'**
  String get backupAppData;

  /// No description provided for @androidBackupWarning.
  ///
  /// In en_AU, this message translates to:
  /// **'Not tested: Selecting the checkbox after downloading more than 60 files, process may consume a large amount of memory and could cause the phone or app to crash. Proceed at your own risk.'**
  String get androidBackupWarning;

  /// No description provided for @backupSettingsAndPlaylistsDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Saves all settings, playlists and login data in a backup file'**
  String get backupSettingsAndPlaylistsDes;

  /// No description provided for @backup.
  ///
  /// In en_AU, this message translates to:
  /// **'Backup'**
  String get backup;

  /// No description provided for @letsStrart.
  ///
  /// In en_AU, this message translates to:
  /// **'Let\'s start..'**
  String get letsStrart;

  /// No description provided for @processFiles.
  ///
  /// In en_AU, this message translates to:
  /// **'Processing files...'**
  String get processFiles;

  /// No description provided for @includeDownloadedFiles.
  ///
  /// In en_AU, this message translates to:
  /// **'Include downloded songs files'**
  String get includeDownloadedFiles;

  /// No description provided for @backupInProgress.
  ///
  /// In en_AU, this message translates to:
  /// **'Backup in progress...'**
  String get backupInProgress;

  /// No description provided for @restoreAppData.
  ///
  /// In en_AU, this message translates to:
  /// **'Restore App data'**
  String get restoreAppData;

  /// No description provided for @restoreSettingsAndPlaylistsDes.
  ///
  /// In en_AU, this message translates to:
  /// **'Restores all settings, login data and playlists from a backup file. Overwrites all current data'**
  String get restoreSettingsAndPlaylistsDes;

  /// No description provided for @backupMsg.
  ///
  /// In en_AU, this message translates to:
  /// **'Backup successfully saved!'**
  String get backupMsg;

  /// No description provided for @backFilesFound.
  ///
  /// In en_AU, this message translates to:
  /// **'databases found'**
  String get backFilesFound;

  /// No description provided for @restoreMsg.
  ///
  /// In en_AU, this message translates to:
  /// **'Successfully restored!\\nChanges are applied on restart'**
  String get restoreMsg;

  /// No description provided for @restoring.
  ///
  /// In en_AU, this message translates to:
  /// **'Restoring...'**
  String get restoring;

  /// No description provided for @restore.
  ///
  /// In en_AU, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @closeApp.
  ///
  /// In en_AU, this message translates to:
  /// **'Close App'**
  String get closeApp;

  /// No description provided for @restartApp.
  ///
  /// In en_AU, this message translates to:
  /// **'Restart App'**
  String get restartApp;

  /// No description provided for @exportPlaylist.
  ///
  /// In en_AU, this message translates to:
  /// **'Export Playlist'**
  String get exportPlaylist;

  /// No description provided for @exportPlaylistCsv.
  ///
  /// In en_AU, this message translates to:
  /// **'Export Playlist as CSV'**
  String get exportPlaylistCsv;

  /// No description provided for @exportingPlaylist.
  ///
  /// In en_AU, this message translates to:
  /// **'Exporting playlist...'**
  String get exportingPlaylist;

  /// No description provided for @playlistExportedMsg.
  ///
  /// In en_AU, this message translates to:
  /// **'Playlist exported successfully to'**
  String get playlistExportedMsg;

  /// No description provided for @exportError.
  ///
  /// In en_AU, this message translates to:
  /// **'Error exporting playlist'**
  String get exportError;

  /// No description provided for @exportErrorPermission.
  ///
  /// In en_AU, this message translates to:
  /// **'Permission denied while exporting'**
  String get exportErrorPermission;

  /// No description provided for @exportErrorStorage.
  ///
  /// In en_AU, this message translates to:
  /// **'Not enough storage space'**
  String get exportErrorStorage;

  /// No description provided for @exportErrorFormat.
  ///
  /// In en_AU, this message translates to:
  /// **'Error formatting playlist data'**
  String get exportErrorFormat;

  /// No description provided for @importPlaylist.
  ///
  /// In en_AU, this message translates to:
  /// **'Import Playlist'**
  String get importPlaylist;

  /// No description provided for @importingPlaylist.
  ///
  /// In en_AU, this message translates to:
  /// **'Importing playlist...'**
  String get importingPlaylist;

  /// No description provided for @importPlaylistDesc.
  ///
  /// In en_AU, this message translates to:
  /// **'Select a previously exported playlist JSON file to import'**
  String get importPlaylistDesc;

  /// No description provided for @selectFile.
  ///
  /// In en_AU, this message translates to:
  /// **'Select File'**
  String get selectFile;

  /// No description provided for @playlistImportedMsg.
  ///
  /// In en_AU, this message translates to:
  /// **'Playlist imported successfully'**
  String get playlistImportedMsg;

  /// No description provided for @importError.
  ///
  /// In en_AU, this message translates to:
  /// **'Error importing playlist'**
  String get importError;

  /// No description provided for @importErrorFileAccess.
  ///
  /// In en_AU, this message translates to:
  /// **'Could not access the selected file'**
  String get importErrorFileAccess;

  /// No description provided for @importErrorFormat.
  ///
  /// In en_AU, this message translates to:
  /// **'Invalid file format'**
  String get importErrorFormat;

  /// No description provided for @invalidPlaylistFile.
  ///
  /// In en_AU, this message translates to:
  /// **'Invalid playlist file structure'**
  String get invalidPlaylistFile;

  /// No description provided for @importErrorDatabase.
  ///
  /// In en_AU, this message translates to:
  /// **'Error saving to database'**
  String get importErrorDatabase;

  /// No description provided for @fileNotFound.
  ///
  /// In en_AU, this message translates to:
  /// **'File not found'**
  String get fileNotFound;

  /// No description provided for @importLargeFileNote.
  ///
  /// In en_AU, this message translates to:
  /// **'Note: Large playlists may take longer to import'**
  String get importLargeFileNote;

  /// No description provided for @exportPlaylistJson.
  ///
  /// In en_AU, this message translates to:
  /// **'Export playlist to JSON'**
  String get exportPlaylistJson;

  /// No description provided for @exportPlaylistJsonSubtitle.
  ///
  /// In en_AU, this message translates to:
  /// **'This format can be imported'**
  String get exportPlaylistJsonSubtitle;

  /// No description provided for @exportPlaylistCsvSubtitle.
  ///
  /// In en_AU, this message translates to:
  /// **'Can\'t be imported here'**
  String get exportPlaylistCsvSubtitle;

  /// No description provided for @exportToYouTubeMusic.
  ///
  /// In en_AU, this message translates to:
  /// **'Export to Youtube music'**
  String get exportToYouTubeMusic;

  /// No description provided for @exportToYouTubeMusicSubtitle.
  ///
  /// In en_AU, this message translates to:
  /// **'It will push your playlist (songs < 50) to current queue, don\'t forget to add to playlist/save after opening in YtMusic'**
  String get exportToYouTubeMusicSubtitle;

  /// No description provided for @linkCopied.
  ///
  /// In en_AU, this message translates to:
  /// **'Link copied to clipboard'**
  String get linkCopied;

  /// No description provided for @keepScreenOnWhilePlaying.
  ///
  /// In en_AU, this message translates to:
  /// **'Keep screen on while playing'**
  String get keepScreenOnWhilePlaying;

  /// No description provided for @keepScreenOnWhilePlayingDes.
  ///
  /// In en_AU, this message translates to:
  /// **'If enabled, the device screen will stay awake while music is playing'**
  String get keepScreenOnWhilePlayingDes;

  /// No description provided for @resyncLibraryNow.
  ///
  /// In en_AU, this message translates to:
  /// **'Resync Library Now'**
  String get resyncLibraryNow;

  /// No description provided for @playbackDiagnosticsRelease.
  ///
  /// In en_AU, this message translates to:
  /// **'Playback diagnostics (release)'**
  String get playbackDiagnosticsRelease;

  /// No description provided for @viewPlaybackDiagnostics.
  ///
  /// In en_AU, this message translates to:
  /// **'View playback diagnostics'**
  String get viewPlaybackDiagnostics;

  /// No description provided for @viewPlaybackDiagnosticsSubtitle.
  ///
  /// In en_AU, this message translates to:
  /// **'Open logs and copy to clipboard'**
  String get viewPlaybackDiagnosticsSubtitle;

  /// No description provided for @clearPlaybackDiagnostics.
  ///
  /// In en_AU, this message translates to:
  /// **'Clear playback diagnostics'**
  String get clearPlaybackDiagnostics;

  /// No description provided for @clearPlaybackDiagnosticsSubtitle.
  ///
  /// In en_AU, this message translates to:
  /// **'Delete all stored diagnostic events'**
  String get clearPlaybackDiagnosticsSubtitle;

  /// No description provided for @playbackDiagnostics.
  ///
  /// In en_AU, this message translates to:
  /// **'Playback diagnostics'**
  String get playbackDiagnostics;

  /// No description provided for @toggleFormat.
  ///
  /// In en_AU, this message translates to:
  /// **'Toggle format'**
  String get toggleFormat;

  /// No description provided for @copyDiagnostics.
  ///
  /// In en_AU, this message translates to:
  /// **'Copy diagnostics'**
  String get copyDiagnostics;

  /// No description provided for @shrinkSidebar.
  ///
  /// In en_AU, this message translates to:
  /// **'shtink sidebar'**
  String get shrinkSidebar;

  /// No description provided for @playlistTypeLabel.
  ///
  /// In en_AU, this message translates to:
  /// **'PLAYLIST'**
  String get playlistTypeLabel;

  /// No description provided for @playbackDiagnosticsCleared.
  ///
  /// In en_AU, this message translates to:
  /// **'Playback diagnostics cleared'**
  String get playbackDiagnosticsCleared;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'en':
      {
        switch (locale.countryCode) {
          case 'AU':
            return AppLocalizationsEnAu();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
