// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Doudou';

  @override
  String get settings => 'Settings';

  @override
  String get general => 'General';

  @override
  String get audio => 'Audio';

  @override
  String get appearance => 'Appearance';

  @override
  String get server => 'Server';

  @override
  String get logs => 'Logs';

  @override
  String get about => 'About';

  @override
  String get generalSettings => 'General Settings';

  @override
  String get audioSettings => 'Audio Settings';

  @override
  String get appearanceSettings => 'Appearance Settings';

  @override
  String get serverSettings => 'Server Settings';

  @override
  String get logsAndDiagnostics => 'Logs & Diagnostics';

  @override
  String get aboutDoudou => 'About Doudou';

  @override
  String get startup => 'Startup';

  @override
  String get startWithSystem => 'Start with system';

  @override
  String get startWithSystemDesc => 'Launch Doudou when your computer starts';

  @override
  String get startMinimized => 'Start minimized';

  @override
  String get startMinimizedDesc => 'Launch in system tray instead of window';

  @override
  String get library => 'Library';

  @override
  String get autoRefreshLibrary => 'Auto-refresh library';

  @override
  String get autoRefreshLibraryDesc => 'Automatically check for new music';

  @override
  String get defaultLibraryView => 'Default library view';

  @override
  String get albums => 'Albums';

  @override
  String get artists => 'Artists';

  @override
  String get songs => 'Songs';

  @override
  String get playlists => 'Playlists';

  @override
  String get downloads => 'Downloads';

  @override
  String get downloadLocation => 'Download location';

  @override
  String get downloadOverCellular => 'Download over cellular';

  @override
  String get downloadOverCellularDesc => 'Allow downloads on mobile data';

  @override
  String get playback => 'Playback';

  @override
  String get audioQuality => 'Audio quality';

  @override
  String get high => 'High (320 kbps)';

  @override
  String get medium => 'Medium (192 kbps)';

  @override
  String get low => 'Low (128 kbps)';

  @override
  String get volume => 'Volume';

  @override
  String get volumeNormalization => 'Volume normalization';

  @override
  String get volumeNormalizationDesc => 'Keep consistent volume across tracks';

  @override
  String get fadeOnPause => 'Fade on pause/resume';

  @override
  String get fadeOnPauseDesc => 'Smooth volume transitions';

  @override
  String get audioDevice => 'Audio Device';

  @override
  String get outputDevice => 'Output device';

  @override
  String get systemDefault => 'System default';

  @override
  String get bufferSize => 'Buffer size';

  @override
  String get auto => 'Auto';

  @override
  String get theme => 'Theme';

  @override
  String get appTheme => 'App theme';

  @override
  String get systemTheme => 'System default';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get accentColor => 'Accent color';

  @override
  String get chooseTheme => 'Choose Theme';

  @override
  String get chooseAccentColor => 'Choose Accent Color';

  @override
  String get layout => 'Layout';

  @override
  String get compactMode => 'Compact mode';

  @override
  String get compactModeDesc => 'Reduce spacing and padding';

  @override
  String get showAlbumArtInSidebar => 'Show album art in sidebar';

  @override
  String get showAlbumArtInSidebarDesc => 'Display current track artwork';

  @override
  String get gridSize => 'Grid size';

  @override
  String get small => 'Small';

  @override
  String get large => 'Large';

  @override
  String get window => 'Window';

  @override
  String get closeToSystemTray => 'Close to system tray';

  @override
  String get closeToSystemTrayDesc => 'Keep running when window is closed';

  @override
  String get showInTaskbar => 'Show in taskbar';

  @override
  String get showInTaskbarDesc => 'Display app icon in taskbar';

  @override
  String get language => 'Language';

  @override
  String get languageSettings => 'Language';

  @override
  String get selectLanguage => 'Select language';

  @override
  String get english => 'English';

  @override
  String get chinese => '简体中文 (Chinese Simplified)';

  @override
  String get russian => 'Русский (Russian)';

  @override
  String get connection => 'Connection';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get notSet => 'Not set';

  @override
  String get username => 'Username';

  @override
  String get notLoggedIn => 'Not logged in';

  @override
  String get testConnection => 'Test Connection';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signOutConfirm =>
      'Are you sure you want to sign out? You\'ll need to log in again to access your music.';

  @override
  String get cache => 'Cache';

  @override
  String get cacheSize => 'Cache size';

  @override
  String get calculating => 'Calculating...';

  @override
  String get clearImageCache => 'Clear image cache';

  @override
  String get clearImageCacheDesc => 'Free up storage space';

  @override
  String get clearAllCache => 'Clear all cache';

  @override
  String get clearAllCacheDesc => 'Remove all cached data';

  @override
  String get clearCache => 'Clear Cache';

  @override
  String clearCacheConfirm(String type) {
    return 'This will remove $type and may slow down the app temporarily. Continue?';
  }

  @override
  String get allCachedData => 'all cached data';

  @override
  String get cachedImages => 'cached images';

  @override
  String cacheCleared(String type) {
    return '$type cleared successfully';
  }

  @override
  String get allCache => 'All cache';

  @override
  String get imageCache => 'Image cache';

  @override
  String get enableLogging => 'Enable Logging';

  @override
  String get enableLoggingDesc =>
      'Record app activity for troubleshooting. Disabled by default to improve performance.';

  @override
  String get recentLogs => 'Recent Logs';

  @override
  String get noLogsAvailable => 'No logs available';

  @override
  String get refresh => 'Refresh';

  @override
  String get exportLogs => 'Export Logs';

  @override
  String get clearLogs => 'Clear Logs';

  @override
  String get clearLogsConfirm =>
      'Are you sure you want to clear all logs? This action cannot be undone.';

  @override
  String logsExportedTo(String path) {
    return 'Logs exported to: $path';
  }

  @override
  String failedToExportLogs(String error) {
    return 'Failed to export logs: $error';
  }

  @override
  String get logStatistics => 'Log Statistics';

  @override
  String get logFiles => 'Log Files';

  @override
  String get totalSize => 'Total Size';

  @override
  String get memoryLogs => 'Memory Logs';

  @override
  String get appDescription => 'A beautiful music player for anyone anywhere.';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get links => 'Links';

  @override
  String get githubRepository => 'GitHub Repository';

  @override
  String get githubRepositoryDesc => 'Source code and issues';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get privacyPolicyDesc => 'How we handle your data';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get termsOfServiceDesc => 'Usage terms and conditions';

  @override
  String get systemInformation => 'System Information';

  @override
  String get platform => 'Platform';

  @override
  String get buildDate => 'Build Date';

  @override
  String get operatingSystem => 'Operating System';

  @override
  String get home => 'Home';

  @override
  String get search => 'Search';

  @override
  String get favorites => 'Favorites';

  @override
  String get nowPlaying => 'Now Playing';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get next => 'Next';

  @override
  String get previous => 'Previous';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get repeat => 'Repeat';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get apply => 'Apply';

  @override
  String get clear => 'Clear';

  @override
  String get close => 'Close';

  @override
  String get save => 'Save';

  @override
  String get connectionSuccessful => 'Connection successful!';

  @override
  String get connectionFailed =>
      'Connection failed. Please check your settings.';

  @override
  String get purple => 'Purple';

  @override
  String get blue => 'Blue';

  @override
  String get green => 'Green';

  @override
  String get orange => 'Orange';

  @override
  String get red => 'Red';

  @override
  String get teal => 'Teal';

  @override
  String get customColor => 'Custom Color';

  @override
  String get custom => 'Custom';

  @override
  String get quickColors => 'Quick Colors:';

  @override
  String get preview => 'Preview';
}
