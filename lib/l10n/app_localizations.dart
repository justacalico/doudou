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
    Locale('ru'),
    Locale('zh'),
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'Doudou'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @generalSettings.
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get generalSettings;

  /// No description provided for @audioSettings.
  ///
  /// In en, this message translates to:
  /// **'Audio Settings'**
  String get audioSettings;

  /// No description provided for @appearanceSettings.
  ///
  /// In en, this message translates to:
  /// **'Appearance Settings'**
  String get appearanceSettings;

  /// No description provided for @serverSettings.
  ///
  /// In en, this message translates to:
  /// **'Server Settings'**
  String get serverSettings;

  /// No description provided for @logsAndDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Logs & Diagnostics'**
  String get logsAndDiagnostics;

  /// No description provided for @aboutDoudou.
  ///
  /// In en, this message translates to:
  /// **'About Doudou'**
  String get aboutDoudou;

  /// No description provided for @startup.
  ///
  /// In en, this message translates to:
  /// **'Startup'**
  String get startup;

  /// No description provided for @startWithSystem.
  ///
  /// In en, this message translates to:
  /// **'Start with system'**
  String get startWithSystem;

  /// No description provided for @startWithSystemDesc.
  ///
  /// In en, this message translates to:
  /// **'Launch Doudou when your computer starts'**
  String get startWithSystemDesc;

  /// No description provided for @startMinimized.
  ///
  /// In en, this message translates to:
  /// **'Start minimized'**
  String get startMinimized;

  /// No description provided for @startMinimizedDesc.
  ///
  /// In en, this message translates to:
  /// **'Launch in system tray instead of window'**
  String get startMinimizedDesc;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @autoRefreshLibrary.
  ///
  /// In en, this message translates to:
  /// **'Auto-refresh library'**
  String get autoRefreshLibrary;

  /// No description provided for @autoRefreshLibraryDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically check for new music'**
  String get autoRefreshLibraryDesc;

  /// No description provided for @defaultLibraryView.
  ///
  /// In en, this message translates to:
  /// **'Default library view'**
  String get defaultLibraryView;

  /// No description provided for @albums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albums;

  /// No description provided for @artists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get artists;

  /// No description provided for @songs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get songs;

  /// No description provided for @playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @downloadLocation.
  ///
  /// In en, this message translates to:
  /// **'Download location'**
  String get downloadLocation;

  /// No description provided for @downloadOverCellular.
  ///
  /// In en, this message translates to:
  /// **'Download over cellular'**
  String get downloadOverCellular;

  /// No description provided for @downloadOverCellularDesc.
  ///
  /// In en, this message translates to:
  /// **'Allow downloads on mobile data'**
  String get downloadOverCellularDesc;

  /// No description provided for @playback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get playback;

  /// No description provided for @audioQuality.
  ///
  /// In en, this message translates to:
  /// **'Audio quality'**
  String get audioQuality;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High (320 kbps)'**
  String get high;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium (192 kbps)'**
  String get medium;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'Low (128 kbps)'**
  String get low;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @volumeNormalization.
  ///
  /// In en, this message translates to:
  /// **'Volume normalization'**
  String get volumeNormalization;

  /// No description provided for @volumeNormalizationDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep consistent volume across tracks'**
  String get volumeNormalizationDesc;

  /// No description provided for @fadeOnPause.
  ///
  /// In en, this message translates to:
  /// **'Fade on pause/resume'**
  String get fadeOnPause;

  /// No description provided for @fadeOnPauseDesc.
  ///
  /// In en, this message translates to:
  /// **'Smooth volume transitions'**
  String get fadeOnPauseDesc;

  /// No description provided for @audioDevice.
  ///
  /// In en, this message translates to:
  /// **'Audio Device'**
  String get audioDevice;

  /// No description provided for @outputDevice.
  ///
  /// In en, this message translates to:
  /// **'Output device'**
  String get outputDevice;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @bufferSize.
  ///
  /// In en, this message translates to:
  /// **'Buffer size'**
  String get bufferSize;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @appTheme.
  ///
  /// In en, this message translates to:
  /// **'App theme'**
  String get appTheme;

  /// No description provided for @systemTheme.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemTheme;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get accentColor;

  /// No description provided for @chooseTheme.
  ///
  /// In en, this message translates to:
  /// **'Choose Theme'**
  String get chooseTheme;

  /// No description provided for @chooseAccentColor.
  ///
  /// In en, this message translates to:
  /// **'Choose Accent Color'**
  String get chooseAccentColor;

  /// No description provided for @layout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get layout;

  /// No description provided for @compactMode.
  ///
  /// In en, this message translates to:
  /// **'Compact mode'**
  String get compactMode;

  /// No description provided for @compactModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Reduce spacing and padding'**
  String get compactModeDesc;

  /// No description provided for @showAlbumArtInSidebar.
  ///
  /// In en, this message translates to:
  /// **'Show album art in sidebar'**
  String get showAlbumArtInSidebar;

  /// No description provided for @showAlbumArtInSidebarDesc.
  ///
  /// In en, this message translates to:
  /// **'Display current track artwork'**
  String get showAlbumArtInSidebarDesc;

  /// No description provided for @gridSize.
  ///
  /// In en, this message translates to:
  /// **'Grid size'**
  String get gridSize;

  /// No description provided for @small.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get small;

  /// No description provided for @large.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get large;

  /// No description provided for @window.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get window;

  /// No description provided for @closeToSystemTray.
  ///
  /// In en, this message translates to:
  /// **'Close to system tray'**
  String get closeToSystemTray;

  /// No description provided for @closeToSystemTrayDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep running when window is closed'**
  String get closeToSystemTrayDesc;

  /// No description provided for @showInTaskbar.
  ///
  /// In en, this message translates to:
  /// **'Show in taskbar'**
  String get showInTaskbar;

  /// No description provided for @showInTaskbarDesc.
  ///
  /// In en, this message translates to:
  /// **'Display app icon in taskbar'**
  String get showInTaskbarDesc;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSettings.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSettings;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get selectLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文 (Chinese Simplified)'**
  String get chinese;

  /// No description provided for @russian.
  ///
  /// In en, this message translates to:
  /// **'Русский (Russian)'**
  String get russian;

  /// No description provided for @connection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connection;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @serverUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrl;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @notLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get notLoggedIn;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnection;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out? You\'ll need to log in again to access your music.'**
  String get signOutConfirm;

  /// No description provided for @cache.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get cache;

  /// No description provided for @cacheSize.
  ///
  /// In en, this message translates to:
  /// **'Cache size'**
  String get cacheSize;

  /// No description provided for @calculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating...'**
  String get calculating;

  /// No description provided for @clearImageCache.
  ///
  /// In en, this message translates to:
  /// **'Clear image cache'**
  String get clearImageCache;

  /// No description provided for @clearImageCacheDesc.
  ///
  /// In en, this message translates to:
  /// **'Free up storage space'**
  String get clearImageCacheDesc;

  /// No description provided for @clearAllCache.
  ///
  /// In en, this message translates to:
  /// **'Clear all cache'**
  String get clearAllCache;

  /// No description provided for @clearAllCacheDesc.
  ///
  /// In en, this message translates to:
  /// **'Remove all cached data'**
  String get clearAllCacheDesc;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCache;

  /// No description provided for @clearCacheConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will remove {type} and may slow down the app temporarily. Continue?'**
  String clearCacheConfirm(String type);

  /// No description provided for @allCachedData.
  ///
  /// In en, this message translates to:
  /// **'all cached data'**
  String get allCachedData;

  /// No description provided for @cachedImages.
  ///
  /// In en, this message translates to:
  /// **'cached images'**
  String get cachedImages;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'{type} cleared successfully'**
  String cacheCleared(String type);

  /// No description provided for @allCache.
  ///
  /// In en, this message translates to:
  /// **'All cache'**
  String get allCache;

  /// No description provided for @imageCache.
  ///
  /// In en, this message translates to:
  /// **'Image cache'**
  String get imageCache;

  /// No description provided for @enableLogging.
  ///
  /// In en, this message translates to:
  /// **'Enable Logging'**
  String get enableLogging;

  /// No description provided for @enableLoggingDesc.
  ///
  /// In en, this message translates to:
  /// **'Record app activity for troubleshooting. Disabled by default to improve performance.'**
  String get enableLoggingDesc;

  /// No description provided for @recentLogs.
  ///
  /// In en, this message translates to:
  /// **'Recent Logs'**
  String get recentLogs;

  /// No description provided for @noLogsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No logs available'**
  String get noLogsAvailable;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @exportLogs.
  ///
  /// In en, this message translates to:
  /// **'Export Logs'**
  String get exportLogs;

  /// No description provided for @clearLogs.
  ///
  /// In en, this message translates to:
  /// **'Clear Logs'**
  String get clearLogs;

  /// No description provided for @clearLogsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all logs? This action cannot be undone.'**
  String get clearLogsConfirm;

  /// No description provided for @logsExportedTo.
  ///
  /// In en, this message translates to:
  /// **'Logs exported to: {path}'**
  String logsExportedTo(String path);

  /// No description provided for @failedToExportLogs.
  ///
  /// In en, this message translates to:
  /// **'Failed to export logs: {error}'**
  String failedToExportLogs(String error);

  /// No description provided for @logStatistics.
  ///
  /// In en, this message translates to:
  /// **'Log Statistics'**
  String get logStatistics;

  /// No description provided for @logFiles.
  ///
  /// In en, this message translates to:
  /// **'Log Files'**
  String get logFiles;

  /// No description provided for @totalSize.
  ///
  /// In en, this message translates to:
  /// **'Total Size'**
  String get totalSize;

  /// No description provided for @memoryLogs.
  ///
  /// In en, this message translates to:
  /// **'Memory Logs'**
  String get memoryLogs;

  /// No description provided for @appDescription.
  ///
  /// In en, this message translates to:
  /// **'A beautiful music player for anyone anywhere.'**
  String get appDescription;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// No description provided for @links.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get links;

  /// No description provided for @githubRepository.
  ///
  /// In en, this message translates to:
  /// **'GitHub Repository'**
  String get githubRepository;

  /// No description provided for @githubRepositoryDesc.
  ///
  /// In en, this message translates to:
  /// **'Source code and issues'**
  String get githubRepositoryDesc;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @privacyPolicyDesc.
  ///
  /// In en, this message translates to:
  /// **'How we handle your data'**
  String get privacyPolicyDesc;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @termsOfServiceDesc.
  ///
  /// In en, this message translates to:
  /// **'Usage terms and conditions'**
  String get termsOfServiceDesc;

  /// No description provided for @systemInformation.
  ///
  /// In en, this message translates to:
  /// **'System Information'**
  String get systemInformation;

  /// No description provided for @platform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get platform;

  /// No description provided for @buildDate.
  ///
  /// In en, this message translates to:
  /// **'Build Date'**
  String get buildDate;

  /// No description provided for @operatingSystem.
  ///
  /// In en, this message translates to:
  /// **'Operating System'**
  String get operatingSystem;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get nowPlaying;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @connectionSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Connection successful!'**
  String get connectionSuccessful;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Please check your settings.'**
  String get connectionFailed;

  /// No description provided for @purple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get purple;

  /// No description provided for @blue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get blue;

  /// No description provided for @green.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get green;

  /// No description provided for @orange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get orange;

  /// No description provided for @red.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get red;

  /// No description provided for @teal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get teal;

  /// No description provided for @customColor.
  ///
  /// In en, this message translates to:
  /// **'Custom Color'**
  String get customColor;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @quickColors.
  ///
  /// In en, this message translates to:
  /// **'Quick Colors:'**
  String get quickColors;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;
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
    'that was used.',
  );
}
