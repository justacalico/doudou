// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'Doudou';

  @override
  String get appTitle => 'Doudou - Jellyfin音乐播放器';

  @override
  String get appTagline => '您的个人音乐伴侣。\n从Jellyfin、Plex或Navidrome串流。';

  @override
  String get navHome => '首页';

  @override
  String get navLibrary => '媒体库';

  @override
  String get navSearch => '搜索';

  @override
  String get navDownloads => '下载';

  @override
  String get navSettings => '设置';

  @override
  String get navTracks => '曲目';

  @override
  String get navPlaylists => '播放列表';

  @override
  String get navAlbums => '专辑';

  @override
  String get navArtists => '艺术家';

  @override
  String get navFavorites => '收藏';

  @override
  String get play => '播放';

  @override
  String get pause => '暂停';

  @override
  String get playAll => '全部播放';

  @override
  String get shuffle => '随机播放';

  @override
  String get shuffleAll => '全部随机';

  @override
  String get shuffleFavorites => '随机播放收藏';

  @override
  String get addToFavorites => '添加到收藏';

  @override
  String get removeFromFavorites => '从收藏中移除';

  @override
  String volumePercent(int percent) {
    return '音量 $percent%';
  }

  @override
  String get playNext => '下一首播放';

  @override
  String get addToQueue => '添加到队列';

  @override
  String get addAllToQueue => '全部添加到队列';

  @override
  String get clearQueue => '清空队列';

  @override
  String get nowPlaying => '正在播放';

  @override
  String get playingFromQueue => '从队列播放';

  @override
  String get playingFrom => '播放自 ';

  @override
  String get queue => '播放队列';

  @override
  String get upNext => '即将播放';

  @override
  String get lyrics => '歌词';

  @override
  String get syncedLyrics => '同步歌词';

  @override
  String get live => '直播';

  @override
  String get sync => '同步';

  @override
  String get shuffled => '已随机';

  @override
  String get noSongsInQueue => '队列中没有歌曲';

  @override
  String get addSongsToQueue => '添加歌曲到队列以在此查看';

  @override
  String get volumeControl => '音量控制';

  @override
  String get download => '下载';

  @override
  String get downloadAll => '全部下载';

  @override
  String get downloadPlaylist => '下载播放列表';

  @override
  String get cancelDownload => '取消下载';

  @override
  String get deleteDownload => '删除下载';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get save => '保存';

  @override
  String get create => '创建';

  @override
  String get rename => '重命名';

  @override
  String get remove => '移除';

  @override
  String get close => '关闭';

  @override
  String get ok => '确定';

  @override
  String get retry => '重试';

  @override
  String get refresh => '刷新';

  @override
  String get clear => '清除';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get undo => '撤销';

  @override
  String get share => '分享';

  @override
  String get viewAll => '查看全部';

  @override
  String get showMore => '显示更多';

  @override
  String get back => '返回';

  @override
  String get signIn => '登录';

  @override
  String get signOut => '退出登录';

  @override
  String get tryDemo => '试用演示';

  @override
  String get useOfflineMode => '使用离线模式';

  @override
  String get goodMorning => '早上好';

  @override
  String get goodAfternoon => '下午好';

  @override
  String get goodEvening => '晚上好';

  @override
  String get whatWouldYouLikeToHear => '您想听什么？';

  @override
  String get listenNow => '立即收听';

  @override
  String get continueListening => '继续收听';

  @override
  String get recentlyAdded => '最近添加';

  @override
  String get recentlyAddedAlbums => '最近添加的专辑';

  @override
  String get yourNewestAdditions => '您的最新添加';

  @override
  String get madeForYou => '为您推荐';

  @override
  String get yourFavorites => '您的收藏';

  @override
  String get quickAccess => '快速访问';

  @override
  String get likedSongs => '喜欢的歌曲';

  @override
  String countSongs(int count) {
    return '$count首歌曲';
  }

  @override
  String countAlbums(int count) {
    return '$count张专辑';
  }

  @override
  String countArtists(int count) {
    return '$count位艺术家';
  }

  @override
  String countPlaylists(int count) {
    return '$count个播放列表';
  }

  @override
  String get jumpBackIntoFavorites => '回到您的收藏';

  @override
  String get yourArtists => '您的艺术家';

  @override
  String get browseByArtist => '按艺术家浏览';

  @override
  String get recentTracks => '最近播放';

  @override
  String get yourMusicCollection => '您的音乐收藏';

  @override
  String get browse => '浏览';

  @override
  String get browseYourLibrary => '浏览媒体库';

  @override
  String get browseMusic => '浏览音乐';

  @override
  String get popularInYourLibrary => '您媒体库中的热门';

  @override
  String get recentSearches => '最近搜索';

  @override
  String get yourRecentSearches => '您的最近搜索将显示在这里';

  @override
  String get quickSuggestions => '快速推荐';

  @override
  String get yourLibrary => '您的媒体库';

  @override
  String get musicCollection => '音乐收藏';

  @override
  String get albums => '专辑';

  @override
  String albumsCount(int count) {
    return '$count张专辑';
  }

  @override
  String get artists => '艺术家';

  @override
  String artistsCount(int count) {
    return '$count位艺术家';
  }

  @override
  String get songs => '歌曲';

  @override
  String songsCount(int count) {
    return '$count首歌曲';
  }

  @override
  String tracksCount(int count) {
    return '$count首曲目';
  }

  @override
  String get playlists => '播放列表';

  @override
  String playlistsCount(int count) {
    return '$count个播放列表';
  }

  @override
  String get collections => '合集';

  @override
  String get genres => '流派';

  @override
  String get comingSoon => '即将推出';

  @override
  String get collectionsComingSoon => '合集即将推出';

  @override
  String get genresComingSoon => '流派即将推出';

  @override
  String get allAlbums => '全部专辑';

  @override
  String get allArtists => '全部艺术家';

  @override
  String get search => '搜索';

  @override
  String get searchPlaceholder => '搜索歌曲、专辑、艺术家或播放列表...';

  @override
  String get searchAlbums => '搜索专辑...';

  @override
  String get searchArtists => '搜索艺术家...';

  @override
  String get searchPlaylists => '搜索播放列表...';

  @override
  String get discoverYourMusic => '发现您的音乐';

  @override
  String get searchDescription => '搜索您的整个音乐库\n找到您想要的';

  @override
  String noResultsFor(String query) {
    return '没有找到「$query」的结果';
  }

  @override
  String get tryDifferentSearch => '尝试不同的搜索词或检查拼写';

  @override
  String get topResult => '最佳结果';

  @override
  String get all => '全部';

  @override
  String get artist => '艺术家';

  @override
  String get album => '专辑';

  @override
  String get downloading => '下载中';

  @override
  String get failed => '失败';

  @override
  String get noDownloadedMusic => '没有已下载的音乐';

  @override
  String get downloadSongsToListenOffline => '下载歌曲以离线收听';

  @override
  String get downloadInProgress => '下载进行中';

  @override
  String get downloadedForOffline => '已下载供离线收听';

  @override
  String get downloadStarted => '下载已开始';

  @override
  String get downloadFailed => '下载失败';

  @override
  String get welcomeTo => '欢迎使用';

  @override
  String get doudou => 'Doudou';

  @override
  String get doudouWelcome => 'Doudou - 欢迎';

  @override
  String get chooseYourServer => '选择您的服务器';

  @override
  String get serverUrl => '服务器地址';

  @override
  String get pleaseEnterServerUrl => '请输入服务器地址';

  @override
  String get plexToken => 'Plex令牌';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get signingIn => '登录中...';

  @override
  String get jellyfinPlaceholder => 'http://your-jellyfin-server:8096';

  @override
  String get plexPlaceholder => 'http://your-plex-server:32400';

  @override
  String get navidromePlaceholder => 'http://your-navidrome-server:4533';

  @override
  String get defaultServerPlaceholder => 'http://your-server:port';

  @override
  String get createPlaylist => '创建播放列表';

  @override
  String get creatingPlaylist => '正在创建播放列表';

  @override
  String get renamePlaylist => '重命名播放列表';

  @override
  String get renamingPlaylist => '正在重命名播放列表';

  @override
  String get removePlaylist => '删除播放列表';

  @override
  String get removingPlaylist => '正在删除播放列表';

  @override
  String get loadingPlaylist => '正在加载播放列表';

  @override
  String get playlistName => '播放列表名称';

  @override
  String get descriptionOptional => '描述（可选）';

  @override
  String get noPlaylistsFound => '未找到播放列表';

  @override
  String get noPlaylistsAvailable => '没有可用的播放列表';

  @override
  String get emptyPlaylist => '空播放列表';

  @override
  String playlistEmpty(String name) {
    return '播放列表“$name”为空。';
  }

  @override
  String get noTracksInPlaylist => '此播放列表中没有曲目';

  @override
  String playlistCreatedSuccess(String name) {
    return '播放列表“$name”创建成功！';
  }

  @override
  String playlistRenamedSuccess(String name) {
    return '播放列表已成功重命名为“$name”！';
  }

  @override
  String playlistRemovedSuccess(String name) {
    return '播放列表“$name”已成功删除！';
  }

  @override
  String confirmRemovePlaylist(String name) {
    return '您确定要删除“$name”吗？此操作无法撤销。';
  }

  @override
  String confirmDownloadPlaylist(String name, int count, String songs) {
    return '下载“$name”（包含$count首$songs）？';
  }

  @override
  String get addToPlaylist => '添加到播放列表';

  @override
  String get addAlbumToPlaylist => '将专辑添加到播放列表';

  @override
  String get selectPlaylist => '选择播放列表：';

  @override
  String selectPlaylistToAdd(String track) {
    return '选择播放列表以添加“$track”：';
  }

  @override
  String addedToPlaylist(String type, String playlist, Object track) {
    return '“$track”已添加到“$playlist”。';
  }

  @override
  String addedTrackToPlaylist(String track) {
    return '“$track”已添加到播放列表';
  }

  @override
  String failedToAddToPlaylist(String track, String playlist) {
    return '无法将“$track”添加到“$playlist”。';
  }

  @override
  String get failedToAddTrackToPlaylist => '无法将曲目添加到播放列表';

  @override
  String get createNewPlaylist => '创建新播放列表';

  @override
  String get newPlaylist => '新播放列表';

  @override
  String get enterPlaylistName => '输入新播放列表的名称：';

  @override
  String createdPlaylistAndAdded(String playlist, String track) {
    return '已创建播放列表“$playlist”并添加了“$track”。';
  }

  @override
  String get partialSuccess => '部分成功';

  @override
  String createdPlaylistButFailed(String name) {
    return '播放列表“$name”已创建，但无法添加歌曲。您可以在播放列表界面手动添加。';
  }

  @override
  String failedToCreatePlaylist(String name) {
    return '无法创建播放列表“$name”。';
  }

  @override
  String get noAlbumsFound => '未找到专辑';

  @override
  String get noArtistsFound => '未找到艺术家';

  @override
  String get noTracksFound => '未找到曲目';

  @override
  String get noSongsFound => '未找到歌曲';

  @override
  String noContentFound(String name) {
    return '未找到$name的内容';
  }

  @override
  String get contentWillAppear => '此艺术家的音乐将在加载后显示在这里。';

  @override
  String get albumsWillAppear => '您的音乐专辑将在从Jellyfin服务器加载后显示在这里。';

  @override
  String get artistsWillAppear => '您的音乐艺术家将在从Jellyfin服务器加载后显示在这里。';

  @override
  String get libraryEmpty => '您的音乐库为空';

  @override
  String get unknownArtist => '未知艺术家';

  @override
  String get unknownAlbum => '未知专辑';

  @override
  String get popularTracks => '热门曲目';

  @override
  String get goToAlbum => '前往专辑';

  @override
  String get goToArtist => '前往艺术家';

  @override
  String get viewAlbums => '查看专辑';

  @override
  String get shareArtist => '分享艺术家';

  @override
  String get createRadioStation => '创建电台';

  @override
  String get radioStationCreated => '电台已创建';

  @override
  String startedRadioStation(String artist) {
    return '已启动$artist电台，无限播放';
  }

  @override
  String get addedToQueue => '已添加到队列';

  @override
  String addedTracksToQueue(int count, String artist) {
    return '已将$artist的$count首曲目添加到队列';
  }

  @override
  String downloadingTracks(int count, String artist) {
    return '正在下载$artist的$count首曲目';
  }

  @override
  String get removeFromList => '从列表中移除';

  @override
  String get title => '标题';

  @override
  String get duration => '时长';

  @override
  String get trackNumber => '#';

  @override
  String get settings => '设置';

  @override
  String get generalSettings => '通用设置';

  @override
  String get audioSettings => '音频设置';

  @override
  String get appearanceSettings => '外观设置';

  @override
  String get serverSettings => '服务器设置';

  @override
  String get logsAndDiagnostics => '日志与诊断';

  @override
  String get aboutDoudou => '关于Doudou';

  @override
  String get startup => '启动';

  @override
  String get startWithSystem => '开机启动';

  @override
  String get launchOnStartup => '计算机启动时启动Doudou';

  @override
  String get startMinimized => '最小化启动';

  @override
  String get launchInTray => '启动到系统托盘而不是窗口';

  @override
  String get library => '媒体库';

  @override
  String get autoRefreshLibrary => '自动刷新媒体库';

  @override
  String get autoCheckForMusic => '自动检查新音乐';

  @override
  String get defaultLibraryView => '默认媒体库视图';

  @override
  String get refreshLibrary => '刷新媒体库';

  @override
  String get refreshing => '刷新中...';

  @override
  String get libraryRefreshed => '媒体库已刷新';

  @override
  String get libraryRefreshedSuccess => '您的音乐库已成功更新为服务器的最新内容。';

  @override
  String get failedToRefreshLibrary => '刷新媒体库数据失败。请检查连接并重试。';

  @override
  String get downloads => '下载';

  @override
  String get downloadLocation => '下载位置';

  @override
  String get downloadOverCellular => '使用移动数据下载';

  @override
  String get allowDownloadsMobileData => '允许使用移动数据下载';

  @override
  String get downloadAllSongs => '下载所有歌曲';

  @override
  String get downloadEntireLibrary => '下载整个音乐库';

  @override
  String get downloadAllFavorites => '下载所有收藏';

  @override
  String get downloadAllLikedSongs => '下载所有喜欢的歌曲';

  @override
  String get playback => '播放';

  @override
  String get audioQuality => '音频质量';

  @override
  String get highQuality => '高质量（320 kbps）';

  @override
  String get normalizeVolume => '音量标准化';

  @override
  String get reduceVolumeDifferences => '减少曲目之间的音量差异';

  @override
  String get gaplessPlayback => '无缝播放';

  @override
  String get seamlessTransitions => '队列中曲目之间无缝过渡';

  @override
  String get volume => '音量';

  @override
  String get volumeNormalization => '音量标准化';

  @override
  String get keepConsistentVolume => '保持曲目之间音量一致';

  @override
  String get fadeOnPauseResume => '暂停/恢复时淡入淡出';

  @override
  String get smoothVolumeTransitions => '平滑音量过渡';

  @override
  String get audioDevice => '音频设备';

  @override
  String get outputDevice => '输出设备';

  @override
  String get systemDefault => '系统默认';

  @override
  String get bufferSize => '缓冲区大小';

  @override
  String get auto => '自动';

  @override
  String get theme => '主题';

  @override
  String get appTheme => '应用主题';

  @override
  String get chooseTheme => '选择主题';

  @override
  String get light => '浅色';

  @override
  String get dark => '深色';

  @override
  String get accentColor => '强调色';

  @override
  String get chooseAccentColor => '选择强调色';

  @override
  String get customColor => '自定义颜色';

  @override
  String get layout => '布局';

  @override
  String get compactMode => '紧凑模式';

  @override
  String get reduceSpacing => '减少间距和边距';

  @override
  String get showAlbumArtSidebar => '在侧边栏显示专辑封面';

  @override
  String get displayCurrentArtwork => '显示当前曲目封面';

  @override
  String get gridSize => '网格大小';

  @override
  String get medium => '中等';

  @override
  String get window => '窗口';

  @override
  String get closeToTray => '关闭到系统托盘';

  @override
  String get keepRunningWhenClosed => '关闭窗口时保持运行';

  @override
  String get showInTaskbar => '在任务栏显示';

  @override
  String get displayInTaskbar => '在任务栏显示应用图标';

  @override
  String get connection => '连接';

  @override
  String get testConnection => '测试连接';

  @override
  String get confirmSignOut => '您确定要退出登录吗？您需要重新登录才能访问您的音乐。';

  @override
  String get cache => '缓存';

  @override
  String get cacheSize => '缓存大小';

  @override
  String get calculating => '计算中...';

  @override
  String get clearImageCache => '清除图片缓存';

  @override
  String get clearAllCache => '清除所有缓存';

  @override
  String get freeUpStorage => '释放存储空间';

  @override
  String get removeAllCachedData => '删除所有缓存数据';

  @override
  String clearCacheConfirm(String type) {
    return '这将删除$type，可能会暂时减慢应用速度。继续？';
  }

  @override
  String get allCachedData => '所有缓存数据';

  @override
  String get cachedImages => '缓存的图片';

  @override
  String cacheCleared(String type) {
    return '$type已成功清除';
  }

  @override
  String get enableLogging => '启用日志记录';

  @override
  String get recordAppActivity => '记录应用活动以进行故障排除。默认禁用以提高性能。';

  @override
  String get viewApplicationLogs => '查看应用日志';

  @override
  String get viewExportLogs => '查看和导出调试日志';

  @override
  String get applicationLogs => '应用日志';

  @override
  String get logStatistics => '日志统计';

  @override
  String get clearLogs => '清除日志';

  @override
  String get confirmClearLogs => '您确定要清除所有日志吗？此操作无法撤销。';

  @override
  String logsExported(String path) {
    return '日志已导出到：$path';
  }

  @override
  String failedToExportLogs(String error) {
    return '导出日志失败：$error';
  }

  @override
  String get appVersion => '应用版本';

  @override
  String version(String version) {
    return '版本 $version';
  }

  @override
  String get licenses => '许可证';

  @override
  String get viewOpenSourceLicenses => '查看开源许可证';

  @override
  String get gitHubRepository => 'GitHub仓库';

  @override
  String get gitLabRepository => 'GitLab仓库';

  @override
  String get sourceCodeAndIssues => '源代码和问题';

  @override
  String get viewSourceAndContribute => '查看源代码并贡献';

  @override
  String get supportDevelopment => '支持开发';

  @override
  String get helpSupportProject => '帮助支持这个项目';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get howWeHandleData => '我们如何处理您的数据';

  @override
  String get termsOfService => '服务条款';

  @override
  String get usageTerms => '使用条款和条件';

  @override
  String get beautifulMusicPlayer => '一款适用于任何人、任何地方的精美音乐播放器。';

  @override
  String get links => '链接';

  @override
  String get systemInformation => '系统信息';

  @override
  String get platform => '平台';

  @override
  String get buildDate => '构建日期';

  @override
  String get operatingSystem => '操作系统';

  @override
  String get dynamicIslePlayer => '灵动岛播放器';

  @override
  String get useModernFloatingPlayer => '使用现代浮动岛式播放器';

  @override
  String get vrMode => 'VR模式';

  @override
  String get launchVRPlayer => '启动Google Cardboard VR播放器';

  @override
  String get cleanExpiredCache => '清理过期缓存';

  @override
  String get removeOldCachedData => '删除旧的缓存数据';

  @override
  String get userId => '用户ID';

  @override
  String get server => '服务器';

  @override
  String get connectedToJellyfin => '已连接到Jellyfin';

  @override
  String get connectionStatus => '连接状态';

  @override
  String get authenticated => '已认证';

  @override
  String get loading => '加载中...';

  @override
  String get loadingDesktopApp => '正在加载桌面应用...';

  @override
  String get loadingAlbums => '正在加载专辑...';

  @override
  String get loadingArtists => '正在加载艺术家...';

  @override
  String get loadingPlaylists => '正在加载播放列表...';

  @override
  String get loadingTracks => '正在加载曲目...';

  @override
  String get loadingLyrics => '正在加载歌词...';

  @override
  String get loadingYourMusicLibrary => '正在加载您的音乐库...';

  @override
  String get error => '错误';

  @override
  String errorOccurred(String error) {
    return '发生错误：$error';
  }

  @override
  String get errorLoadingTracks => '加载曲目出错';

  @override
  String failedToLoadPlaylistTracks(String error) {
    return '加载播放列表曲目失败：$error';
  }

  @override
  String failedToRenamePlaylist(String name) {
    return '无法将播放列表重命名为“$name”。请重试。';
  }

  @override
  String failedToRemovePlaylist(String name) {
    return '无法删除播放列表“$name”。请重试。';
  }

  @override
  String get failedToStartDownloads => '无法开始下载';

  @override
  String errorAddingAlbumToPlaylist(String error) {
    return '添加专辑到播放列表出错：$error';
  }

  @override
  String get navigationError => '导航错误';

  @override
  String get success => '成功';

  @override
  String get noAudioHandlerAvailable => '音频处理器不可用';

  @override
  String get noMusicPlaying => '没有正在播放的音乐';

  @override
  String get noTrackPlaying => '没有正在播放的曲目';

  @override
  String get selectSongToPlay => '选择一首歌曲播放';

  @override
  String get noDownloadedContent => '没有已下载的内容';

  @override
  String get needDownloadedMusic => '需要下载音乐才能使用离线模式。请先登录并下载音乐。';

  @override
  String get noFavorites => '没有收藏';

  @override
  String get noFavoritesYet => '您还没有收藏任何歌曲。添加收藏以使用随机播放。';

  @override
  String get offlineMode => '离线模式';

  @override
  String get offlineModeDownloadsOnly => '离线模式 - 仅下载内容';

  @override
  String get shareTrack => '分享曲目';

  @override
  String deleteConfirm(String name) {
    return '从设备中删除“$name”？';
  }

  @override
  String get lyricsPoweredBy => '歌词由LRCLib.net提供 • 桌面增强版';

  @override
  String get sortBy => '排序：';

  @override
  String get filter => '筛选：';

  @override
  String get name => '名称';

  @override
  String get albumName => '专辑名称';

  @override
  String get year => '年份';

  @override
  String get dateAdded => '添加日期';

  @override
  String get trackCount => '曲目数';

  @override
  String get albumCount => '专辑数';

  @override
  String get ascending => '升序';

  @override
  String get descending => '降序';

  @override
  String get favorites => '收藏';

  @override
  String get recentlyAddedFilter => '最近添加';

  @override
  String get tooltipBack => '返回';

  @override
  String get tooltipRefresh => '刷新';

  @override
  String get tooltipRefreshAlbums => '刷新专辑';

  @override
  String get tooltipRefreshArtists => '刷新艺术家';

  @override
  String get tooltipRefreshPlaylists => '刷新播放列表';

  @override
  String get tooltipRefreshLibrary => '刷新媒体库';

  @override
  String get tooltipPlayAllTracks => '播放所有曲目';

  @override
  String get tooltipShuffleAllTracks => '随机播放所有曲目';

  @override
  String get tooltipPlayTrack => '播放曲目';

  @override
  String get tooltipPlayAll => '全部播放';

  @override
  String get tooltipShuffle => '随机播放';

  @override
  String get tooltipAddToFavorites => '添加到收藏';

  @override
  String get tooltipReloadTracks => '重新加载曲目';

  @override
  String get tooltipShowNowPlaying => '显示正在播放';

  @override
  String get youAreListeningTo => '您正在收听';

  @override
  String get by => '由 ';

  @override
  String get from => '来自 ';

  @override
  String get songSingular => '歌曲';

  @override
  String get songPlural => '歌曲';

  @override
  String get trackSingular => '曲目';

  @override
  String get trackPlural => '曲目';

  @override
  String get albumSingular => '专辑';

  @override
  String get albumPlural => '专辑';

  @override
  String get artistSingular => '艺术家';

  @override
  String get artistPlural => '艺术家';

  @override
  String playlistTrackCount(int count) {
    return '播放列表 • $count首曲目';
  }

  @override
  String albumArtistInfo(String artist) {
    return '专辑 • $artist';
  }

  @override
  String get welcomeToDoudou => '欢迎使用Doudou';

  @override
  String get doudouTitle => 'Doudou - Jellyfin音乐播放器';

  @override
  String get doudouMusicPlayer => 'Doudou - 音乐播放器';

  @override
  String get language => '语言';

  @override
  String get selectLanguage => '选择语言';

  @override
  String get systemLanguage => '系统语言';

  @override
  String get libraryOverview => '概览';

  @override
  String get libraryRecent => '最近';

  @override
  String get libraryGenres => '流派';

  @override
  String get libraryYears => '年份';

  @override
  String get totalSongs => '歌曲总数';

  @override
  String get inYourLibrary => '在您的媒体库中';

  @override
  String get albumCollections => '专辑合集';

  @override
  String get uniqueArtists => '艺术家';

  @override
  String get yourPlaylists => '您的播放列表';

  @override
  String get recentlyPlayedSection => '最近播放';

  @override
  String get downloadedSection => '已下载';

  @override
  String get yourLikedTracks => '您喜欢的曲目';

  @override
  String get listenAgain => '再次收听';

  @override
  String get availableOffline => '可离线收听';

  @override
  String get noRecentActivity => '没有最近活动';

  @override
  String get recentPlaybackAppear => '最近播放的音乐将显示在这里';

  @override
  String get browseByGenre => '按流派浏览';

  @override
  String get noGenresFound => '未找到流派';

  @override
  String get genresAppearHere => '流派信息将在可用时显示在这里';

  @override
  String get browseByYear => '按年份浏览';

  @override
  String get noYearInfo => '没有年份信息';

  @override
  String get yearInfoAppear => '发行年份信息将在可用时显示在这里';

  @override
  String albumCountSingle(int count) {
    return '$count张专辑';
  }

  @override
  String albumCountMultiple(int count) {
    return '$count张专辑';
  }

  @override
  String playFavoritesCount(int count) {
    return '播放收藏（$count）';
  }

  @override
  String get noFavoriteTracks => '没有收藏的曲目';

  @override
  String get noFavoriteSongs => '没有收藏的歌曲';

  @override
  String get noDownloadedFavorites => '没有已下载的收藏';

  @override
  String get downloadedFavorites => '已下载的收藏';

  @override
  String get downloadFavoritesSuggestion => '下载收藏的歌曲以便离线收听。';

  @override
  String get favoriteSongsDescription => '您喜欢的歌曲将显示在这里。点击心形图标将歌曲添加到收藏。';

  @override
  String get libraryAppearsEmpty => '您的音乐库似乎是空的';

  @override
  String get playTrack => '播放曲目';

  @override
  String get albumInfoNotAvailable => '专辑信息不可用';

  @override
  String get albumNotFound => '未找到专辑';

  @override
  String get artistInfoNotAvailable => '艺术家信息不可用';

  @override
  String artistNotFound(String name) {
    return '未找到艺术家';
  }

  @override
  String get showAlbum => '显示专辑';

  @override
  String get showArtist => '显示艺术家';

  @override
  String get allPlaylists => '所有播放列表';

  @override
  String get refreshPlaylists => '刷新播放列表';

  @override
  String get editPlaylist => '编辑播放列表';

  @override
  String get deletePlaylist => '删除播放列表';

  @override
  String deletePlaylistConfirm(String name) {
    return '您确定要删除“$name”吗？此操作无法撤销。';
  }

  @override
  String playlistRenamed(String name) {
    return '播放列表已重命名为“$name”';
  }

  @override
  String playlistDeleted(String name) {
    return '播放列表“$name”已删除';
  }

  @override
  String get failedToDeletePlaylist => '删除播放列表失败';

  @override
  String get favoritesNotImplemented => '播放列表的收藏功能尚未实现';

  @override
  String noPlaylistsForQuery(String query) {
    return '未找到“$query”的播放列表';
  }

  @override
  String get createFirstPlaylist => '创建您的第一个播放列表以开始';

  @override
  String countSongsLabel(int count) {
    return '$count首歌曲';
  }

  @override
  String playlistCreated(String name) {
    return '播放列表“$name”创建成功';
  }

  @override
  String errorCreatingPlaylist(String name) {
    return '无法创建播放列表“$name”';
  }

  @override
  String errorRenamingPlaylist(String error) {
    return '重命名播放列表出错：$error';
  }

  @override
  String errorDeletingPlaylist(String error) {
    return '删除播放列表出错：$error';
  }

  @override
  String get refreshAlbums => '刷新专辑';

  @override
  String get noFavoriteAlbums => '没有收藏的专辑';

  @override
  String get addAlbumsToFavorites => '点击心形图标将专辑添加到收藏';

  @override
  String get playAlbum => '播放专辑';

  @override
  String addedAlbumToPlaylist(String albumName, int count) {
    return '专辑“$albumName”（$count首曲目）已添加到播放列表';
  }

  @override
  String addedPartialAlbumToPlaylist(
    int successCount,
    int totalCount,
    String albumName,
  ) {
    return '已将“$albumName”中$successCount/$totalCount首曲目添加到播放列表';
  }

  @override
  String errorAddingToPlaylist(String error) {
    return '添加到播放列表出错：$error';
  }

  @override
  String get refreshArtists => '刷新艺术家';

  @override
  String get albumCountSort => '专辑数';

  @override
  String get musicLibraryEmpty => '您的音乐库为空';

  @override
  String artistAlbumsAndSongs(int albumCount, int songCount) {
    return '$albumCount张专辑 • $songCount首歌曲';
  }

  @override
  String get gridView => '网格视图';

  @override
  String get listView => '列表视图';

  @override
  String get playlist => '播放列表';

  @override
  String get popularSongs => '热门歌曲';

  @override
  String get noAlbumsFoundForArtist => '未找到专辑';

  @override
  String get artistHasNoAlbumsYet => '此艺术家还没有专辑';

  @override
  String get artistHasNoSongsYet => '此艺术家还没有歌曲';

  @override
  String get followArtist => '关注艺术家';

  @override
  String get startRadio => '开始电台';

  @override
  String get addSongsToGetStarted => '添加歌曲以开始';

  @override
  String get albumTracksEmptyMessage => '此专辑为空或无法加载曲目。';

  @override
  String get addSongs => '添加歌曲';

  @override
  String get removeFromPlaylist => '从播放列表中移除';

  @override
  String get albumFavoritesNotImplemented => '专辑收藏功能尚未实现';

  @override
  String get reloadTracks => '重新加载曲目';

  @override
  String get addTracksToPlaylist => '添加曲目到播放列表';

  @override
  String deletePlaylistConfirmation(String name) {
    return '您确定要删除“$name”吗？此操作无法撤销。';
  }

  @override
  String removedFromPlaylist(String track) {
    return '已从播放列表中移除“$track”';
  }

  @override
  String get downloadAlbum => '下载专辑';

  @override
  String downloadAlbumConfirmation(int count, String name) {
    return '在浏览器中打开“$name”的全部$count首曲目进行下载？';
  }

  @override
  String get downloadAllTracks => '下载全部';

  @override
  String get noTracksToDownload => '没有可下载的曲目';

  @override
  String openedTracksInBrowser(int count, String name) {
    return '已在浏览器中打开“$name”的全部$count首曲目';
  }

  @override
  String openedTracksPartialSuccess(int success, int failed, String name) {
    return '已打开$success首曲目，$failed首失败，来自“$name”';
  }

  @override
  String createdPlaylistWithTracks(String name, String type) {
    return '已创建播放列表“$name”并添加了$type首曲目';
  }

  @override
  String get added => '已添加';

  @override
  String get today => '今天';

  @override
  String daysAgo(int count) {
    return '$count天前';
  }

  @override
  String weeksAgo(int count) {
    return '$count周前';
  }

  @override
  String get byArtist => '由 ';

  @override
  String get fromAlbum => '来自 ';

  @override
  String get playerInterface => '播放器界面';

  @override
  String get storageAndCache => '存储与缓存';

  @override
  String get about => '关于';

  @override
  String get cacheInfo => '缓存信息';

  @override
  String get cacheDescription => '缓存通过在本地存储常用数据来帮助应用更快地加载内容。';

  @override
  String get dataCache => '数据缓存';

  @override
  String get imageCache => '图片缓存';

  @override
  String get clearCacheOptions => '清除缓存';

  @override
  String get selectClearOption => '选择要清除的内容：';

  @override
  String get cacheCleanedTitle => '缓存已清理';

  @override
  String get expiredCacheRemoved => '过期的缓存条目已被删除。';

  @override
  String get openSourceLicenses => '开源许可证';

  @override
  String get licensesDescription =>
      '此应用使用以下开源库：\n\n• Flutter\n• just_audio\n• cached_network_image\n• provider\n• dio\n• shared_preferences';

  @override
  String get gitlabUrlCopied => 'GitLab地址已复制到剪贴板！';

  @override
  String get gitlabUrlDescription => '您现在可以将其粘贴到浏览器中访问仓库。';

  @override
  String get failedToCopyUrl => '无法复制地址到剪贴板。请访问：';

  @override
  String get supportMessage =>
      '感谢您使用Doudou！这是一款开源且免费使用的应用。如果您想支持开发，可以在GitLab上为项目点星或为代码库做贡献。';

  @override
  String get refreshFailed => '刷新失败';

  @override
  String cacheClearedTitle(String type) {
    return '$type缓存已清除';
  }

  @override
  String cacheClearedMessage(String type) {
    return '$type缓存已成功清除。';
  }

  @override
  String failedToClearCache(String type) {
    return '清除$type缓存失败';
  }

  @override
  String get failedToCleanExpiredCache => '清理过期缓存失败';

  @override
  String get data => '数据';

  @override
  String get image => '图片';

  @override
  String get accountInformation => '账户信息';

  @override
  String get notAvailable => '不可用';

  @override
  String get allSongsDownloaded => '所有歌曲已下载';

  @override
  String get allSongsAlreadyDownloaded => '您的所有歌曲都已下载。';

  @override
  String downloadAllSongsConfirm(int count) {
    return '下载媒体库中的全部$count首歌曲？';
  }

  @override
  String alreadyDownloadedCount(int count) {
    return '$count首已下载';
  }

  @override
  String songsWillBeDownloaded(int count) {
    return '将下载$count首歌曲。';
  }

  @override
  String get noFavoriteSongsYet => '您还没有收藏任何歌曲。点击歌曲上的心形图标将其添加到收藏。';

  @override
  String get allFavoritesDownloaded => '所有收藏已下载';

  @override
  String get allFavoritesAlreadyDownloaded => '您收藏的所有歌曲都已下载。';

  @override
  String downloadAllFavoritesConfirm(int count) {
    return '下载全部$count首收藏的歌曲？';
  }

  @override
  String get startingDownloads => '开始下载';

  @override
  String get preparingDownloads => '正在准备下载...';

  @override
  String get downloadsStarted => '下载已开始';

  @override
  String get downloadStatus => '下载状态';

  @override
  String startedDownloading(int count, String songs) {
    return '已开始下载$count首$songs';
  }

  @override
  String get song => '歌曲';

  @override
  String failedToStart(int count) {
    return '$count首无法开始';
  }

  @override
  String get downloadsContinueInBackground => '下载将在后台继续。请在下载标签页查看进度。';

  @override
  String allAlreadyDownloaded(String description) {
    return '所有$description都已下载';
  }

  @override
  String get topArtists => '热门艺术家';

  @override
  String get mostPlayed => '播放最多';

  @override
  String get latestAlbums => '最新专辑';

  @override
  String get customMixes => '自定义混音';
}
