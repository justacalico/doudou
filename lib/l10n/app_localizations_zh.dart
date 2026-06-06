// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get home => '首页';

  @override
  String get homeSubtitle => '最近播放、新添加与为你推荐';

  @override
  String get songs => '歌曲';

  @override
  String get playlists => '播放列表';

  @override
  String get albums => '专辑';

  @override
  String get album => '专辑';

  @override
  String get singles => '单曲';

  @override
  String get artists => '音乐人';

  @override
  String get albumsFromYourArtists => '来自你的音乐人';

  @override
  String get settings => '设置';

  @override
  String get library => '音乐库';

  @override
  String get libraryOverviewSubtitle => '概览 / 你的音乐库。';

  @override
  String get yourLibrary => '你的曲库';

  @override
  String get manage => '管理';

  @override
  String tracksInYourCollection(int count) {
    return '曲库中共 $count 首';
  }

  @override
  String shuffleLikedSongs(int count) {
    return '随机播放 $count 首收藏的歌曲';
  }

  @override
  String get availableOffline => '可离线使用';

  @override
  String get libSongs => '曲库';

  @override
  String get libPlaylists => '播放列表库';

  @override
  String get libAlbums => '专辑库';

  @override
  String get libArtists => '音乐人库';

  @override
  String get communityplaylists => '社区播放列表';

  @override
  String get featuredplaylists => '特色播放列表';

  @override
  String get items => '项目';

  @override
  String get networkError1 => '哎呀，发生了网络错误！';

  @override
  String get retry => '重试！';

  @override
  String get noOfflineSong => '没有已离线保存的歌曲！';

  @override
  String get recentlyPlayed => '最近播放';

  @override
  String get favorites => '收藏夹';

  @override
  String get cachedOrOffline => '已缓存/离线保存';

  @override
  String get downloads => '下载';

  @override
  String get emptyPlaylist => '播放列表是空的！';

  @override
  String get enqueueAll => '全部加入队列';

  @override
  String get renamePlaylist => '重命名播放列表';

  @override
  String get removePlaylist => '移除播放列表';

  @override
  String get createNewPlaylist => '新建播放列表';

  @override
  String get reArrangePlaylist => '重新排序列表';

  @override
  String get reArrangeSongs => '重排曲目';

  @override
  String get selectSongs => '选择曲目';

  @override
  String get selectAll => '全选';

  @override
  String get removeMultiple => '移除多首歌曲';

  @override
  String get addMultipleSongs => '添加到播放列表';

  @override
  String get cancel => '取消';

  @override
  String get create => '新建';

  @override
  String get rename => '重命名';

  @override
  String get createnAdd => '创建并新增';

  @override
  String get noBookmarks => '没有收藏！';

  @override
  String get addMusicToLibraryHint => '添加音乐到曲库即可在此查看';

  @override
  String get shuffleAll => '全部随机播放';

  @override
  String get shuffleFavorites => '随机播放收藏';

  @override
  String get shuffleDownloads => '随机播放下载';

  @override
  String get homeContinueListening => '继续收听';

  @override
  String get homeContinueListeningSubtitle => '从上次离开处继续';

  @override
  String get homeBecauseYouLikeArtists => '因为你喜欢这些音乐人';

  @override
  String get homeBecauseYouLikeArtistsSubtitle => '来自你已收藏音乐人的更多曲目';

  @override
  String get homePlaylistsSubtitle => '你曲库中的播放列表';

  @override
  String get recentlyAddedAlbums => '最近添加的专辑';

  @override
  String get yourNewestAdditions => '你的最新添加';

  @override
  String get yourArtists => '你的音乐人';

  @override
  String get homeArtistsSubtitle => '来自你的音乐人的轮播';

  @override
  String get homeFreshPicks => '新推荐';

  @override
  String get homeEmptyLibraryMessage => '你的曲库是空的。添加一些音乐开始吧。';

  @override
  String get homeSectionEmpty => '暂无内容';

  @override
  String get servers => '服务器';

  @override
  String get addServer => '添加服务器';

  @override
  String get noServersConfigured => '尚未配置服务器';

  @override
  String get activeServer => '当前服务器';

  @override
  String get youtubeMusic => 'YouTube Music';

  @override
  String get subsonic => 'Subsonic';

  @override
  String get jellyfin => 'Jellyfin';

  @override
  String get plex => 'Plex';

  @override
  String get plexToken => 'Plex 令牌';

  @override
  String get serverUrl => '服务器 URL';

  @override
  String get editServer => '编辑服务器';

  @override
  String get deleteServer => 'Delete server';

  @override
  String get deleteServerConfirm =>
      'Are you sure you want to delete this server?';

  @override
  String get delete => 'Delete';

  @override
  String get save => '保存';

  @override
  String get add => '添加';

  @override
  String get defaultLabel => '默认';

  @override
  String get youtubeMusicNoLogin => 'YouTube Music 无需登录信息。';

  @override
  String get serverUrlRequired => '服务器 URL 为必填项';

  @override
  String get testConnection => '测试连接';

  @override
  String get connectionSuccess => '连接成功';

  @override
  String get connectionFailed => '连接失败';

  @override
  String get playAll => '全部播放';

  @override
  String get shuffle => '随机播放';

  @override
  String get artistLabel => '音乐人';

  @override
  String get fromWikipedia => '来自维基百科';

  @override
  String get songsCount => '首';

  @override
  String get addToLibrary => '添加到曲库';

  @override
  String get noSongsInLibrary => '曲库中无歌曲';

  @override
  String get favoritesEmpty => '收藏夹为空';

  @override
  String get startRadio => '启动电台';

  @override
  String get playNext => '播放下一曲';

  @override
  String get addToPlaylist => '添加到播放列表';

  @override
  String get noLibPlaylist => '没有任何已入库的播放列表！';

  @override
  String get enqueueSong => '将此曲加入队列';

  @override
  String get goToAlbum => '去往专辑';

  @override
  String get viewArtist => '查看音乐人';

  @override
  String get openIn => '打开于';

  @override
  String get shareSong => '分享这首歌';

  @override
  String get removeFromPlaylist => '从播放列表移除';

  @override
  String get removeFromQueue => '从队列移除';

  @override
  String get queueShufflingDeniedMsg => '随机播放启用时无法随机重排队列';

  @override
  String get queuerearrangingDeniedMsg => '随机播放启用时无法手动重排队列';

  @override
  String get songNotPlayable => '由于服务器限制，歌曲无法播放！';

  @override
  String get upNext => '接下来';

  @override
  String get lyrics => '歌词';

  @override
  String get fromAlbum => '来自：';

  @override
  String get byArtist => '演唱：';

  @override
  String get playingFrom => '正在播放自 ';

  @override
  String get playingfromAlbum => '从专辑播放';

  @override
  String get playingfromPlaylist => '从歌单播放';

  @override
  String get playingfromSelection => '从选项播放';

  @override
  String get playingfromArtist => '从音乐人播放';

  @override
  String get randomSelection => '随机选择';

  @override
  String get randomRadio => '随机电台';

  @override
  String get playnextMsg => '下一首';

  @override
  String get shuffleQueue => '随机队列';

  @override
  String get queueLoop => '队列循环';

  @override
  String get queueLoopNotDisMsg1 => '启用随机播放模式时，无法禁用队列循环模式。';

  @override
  String get queueLoopNotDisMsg2 => '广播模式下无法启用队列循环模式。';

  @override
  String get removeFromLib => '从曲库移除';

  @override
  String get sleepTimer => '睡眠定时器';

  @override
  String get add5Minutes => '增加 5 分钟';

  @override
  String get cancelTimer => '取消定时器';

  @override
  String get deleteDownloadData => '从下载中移除';

  @override
  String get minutes => '分钟';

  @override
  String get endOfThisSong => '这首歌的末尾';

  @override
  String get appInfo => '应用信息';

  @override
  String get download => '下载';

  @override
  String get misc => '其他';

  @override
  String get autoDownFavSong => '自动下载收藏的歌曲';

  @override
  String get autoDownFavSongDes => '当添加到收藏夹时自动下载收藏的歌曲';

  @override
  String get networkError => '网络错误！请检查您的网络连接。';

  @override
  String get downloadError2 => '服务器限制，无法下载所请求的歌曲。请重试';

  @override
  String get downloadError3 => '由于网络/串流错误，下载失败！请重试';

  @override
  String get musicPlayback => '音乐与播放';

  @override
  String get content => '内容';

  @override
  String get personalisation => '个性化';

  @override
  String get themeMode => '主题模式';

  @override
  String get dynamicTheme => '动态';

  @override
  String get dynamicColor => '动态色彩';

  @override
  String get systemDefault => '系统默认';

  @override
  String get dark => '暗色';

  @override
  String get light => '亮色';

  @override
  String get oled => 'OLED';

  @override
  String get language => '语言';

  @override
  String get playerUi => '用户播放界面';

  @override
  String get playerUiDes => '选择播放器用户界面';

  @override
  String get standard => '标准';

  @override
  String get gesture => '手势';

  @override
  String get languageDes => '设置应用语言';

  @override
  String get setDiscoverContent => '设置发现页内容';

  @override
  String get quickpicks => '歌曲快选';

  @override
  String get discover => '发现';

  @override
  String get trending => '趋势';

  @override
  String get topmusicvideos => '热门 MV';

  @override
  String get basedOnLast => '基于上次的交互';

  @override
  String get restoreLastPlaybackSession => '恢复上次播放';

  @override
  String get restoreLastPlaybackSessionDes => '应用程序启动时自动恢复上次播放';

  @override
  String get autoOpenPlayer => '自动打开播放页面';

  @override
  String get autoOpenPlayerDes => '启用/禁用选择歌曲播放时自动全屏播放器';

  @override
  String get homeContentCount => '首页内容数量';

  @override
  String get homeContentCountDes => '选择首页初始化时加载的大致内容数量。更少的内容可加快载入速度';

  @override
  String get enableBottomNav => '底部导航栏';

  @override
  String get enableBottomNavDes => '切换到底部导航栏';

  @override
  String get sidebarMode => '侧边栏行为';

  @override
  String get sidebarModeDes => '侧边栏自动、始终收起或始终展开';

  @override
  String get sidebarModeAuto => '自动';

  @override
  String get sidebarModeCollapsed => '收起';

  @override
  String get sidebarModeExpanded => '完整显示';

  @override
  String get dynamicColorDes => '使用固定颜色的动态主题（非正在播放）';

  @override
  String get useCustomAccentColor => '使用自定义强调色';

  @override
  String get useCustomAccentColorDes => '在所有主题下应用所选强调色';

  @override
  String get customAccentColor => '自定义强调色';

  @override
  String get customAccentColorDes => '选择应用内使用的强调色';

  @override
  String get lyricsDynamicColor => '歌词改变强调色';

  @override
  String get lyricsDynamicColorDes => '当歌曲有滚动歌词时，歌词中的颜色词可改变应用强调色（仅动态主题）';

  @override
  String get syncedLyricsHighlightStyle => '滚动歌词高亮样式';

  @override
  String get syncedLyricsHighlightStyleDes => '选择当前歌词行的突出方式';

  @override
  String get lyricsHighlightBlock => '块高亮';

  @override
  String get lyricsHighlightKaraoke => '卡拉OK填充';

  @override
  String get pickDynamicColor => '选择动态颜色';

  @override
  String get advanced => '高级…';

  @override
  String get change => '更改';

  @override
  String get cacheSongs => '缓存歌曲';

  @override
  String get cacheSongsDes => '播放时缓存歌曲以便未来或离线时欣赏，会占用设备的额外空间';

  @override
  String get skipSilence => '跳过无声部分';

  @override
  String get skipSilenceDes => '音乐中的无声部分会被跳过';

  @override
  String get loudnessNormalization => '标准音量';

  @override
  String get loudnessNormalizationDes =>
      '为所有歌曲设置相同的音量（实验性）（不适用于以前版本（<v1.10.0）下载的歌曲）';

  @override
  String get streamingQuality => '串流音质';

  @override
  String get streamingQualityDes => '音乐串流的质量';

  @override
  String get disableTransitionAnimation => '禁用过渡动画';

  @override
  String get disableTransitionAnimationDes => '启用此选项可禁用选项卡过渡动画';

  @override
  String get animationSpeed => '动画速度';

  @override
  String get animationSpeedDes => '控制应用过渡速度或关闭';

  @override
  String get animationSpeedOff => '关';

  @override
  String get animationSpeedFast => '快（默认）';

  @override
  String get animationSpeedNormal => '普通';

  @override
  String get animationSpeedSlow => '慢';

  @override
  String get enableSlidableAction => '启用可滑动操作';

  @override
  String get enableSlidableActionDes => '在歌曲板块上启用可滑动操作';

  @override
  String get more => '更多';

  @override
  String get loading => '加载中';

  @override
  String get imported => '已导入';

  @override
  String get importedPlaylist => '已导入的播放列表';

  @override
  String get listBookmarkRemoveAlert => '已取消收藏！';

  @override
  String get permissionDenied => '权限被拒绝';

  @override
  String get unknownArtist => '未知音乐人';

  @override
  String get unknownAlbum => '未知专辑';

  @override
  String get yourMusicCollection => '你的音乐收藏';

  @override
  String get sortByName => '按名称';

  @override
  String get sortByDate => '按日期';

  @override
  String get sortByDuration => '按时长';

  @override
  String get sortAscendNDescend => '升序与降序';

  @override
  String get high => '高音质';

  @override
  String get low => '低音质';

  @override
  String get backgroundPlay => '后台音乐播放';

  @override
  String get backgroundPlayDes => '启用/禁用后台音乐播放（应用在后台运行时可从系统托盘访问）';

  @override
  String get downloadLocation => '下载位置';

  @override
  String get cacheHomeScreenData => '缓存主页内容数据';

  @override
  String get cacheHomeScreenDataDes => '启用缓存主页内容数据，如果启用此选项，主页将立即加载';

  @override
  String get downloadingFormat => '下载文件格式';

  @override
  String get downloadingFormatDes => '选择下载所用的文件格式。“Opus”会提供最佳音质';

  @override
  String get exportDowloadedFiles => '输出已下载的文件';

  @override
  String get exportDowloadedFilesDes => '单击此处将下载的文件从 inApp 目录导出到外部目录';

  @override
  String get exportedFileLocation => '下载文件的导出位置';

  @override
  String get export => '输出';

  @override
  String get exporting => '输出中...';

  @override
  String get scanning => '扫描中...';

  @override
  String get downFilesFound => '找到已下载的文件';

  @override
  String get close => '关闭';

  @override
  String get exportMsg => '文件已成功輸出';

  @override
  String get equalizer => '均衡器';

  @override
  String get equalizerDes => '打开系统均衡器';

  @override
  String get clearImgCache => '清理图像缓存';

  @override
  String get clearImgCacheAlert => '图像缓存清理成功';

  @override
  String get clearImgCacheDes => '点击此处清理已缓存的缩略图和图像。（除非为了刷新缓存图像数据，否则不推荐此操作）';

  @override
  String get ignoreBatOpt => '忽略电池优化';

  @override
  String get ignoreBatOptDes => '如果遇到通知问题或后台播放被系统停止，请启用此选项';

  @override
  String get status => '状态';

  @override
  String get enabled => '已启用';

  @override
  String get disabled => '已禁用';

  @override
  String get resetToDefault => '恢复默认设置';

  @override
  String get resetToDefaultDes => '重置为默认设置（需要重启应用程序）';

  @override
  String get resetToDefaultMsg => '已重置为默认设置，请重启应用程序';

  @override
  String get github => 'GitHub';

  @override
  String get githubDes => '查看 GitHub 源码 \\n如果你喜欢本项目，别忘了给一颗 ⭐';

  @override
  String get gitlab => 'GitLab';

  @override
  String get gitlabDes => '查看 GitLab 源码 \\n如果你喜欢本项目，别忘了给一颗 ⭐';

  @override
  String get checkForUpdates => '检查更新';

  @override
  String get checkForUpdatesOnStartup => '启动时检查更新';

  @override
  String get openGitlab => '打开 GitLab';

  @override
  String get upToDate => '已是最新';

  @override
  String get checkingForUpdates => '正在检查更新…';

  @override
  String get by => '由';

  @override
  String get urlSearchDes => '检测到 URL 后单击即可打开/播放相关内容';

  @override
  String get search => '搜索';

  @override
  String get searchDes => '歌曲、播放列表、专辑或音乐人';

  @override
  String get searchRes => '搜索结果';

  @override
  String get for1 => '为';

  @override
  String get videos => '视频';

  @override
  String get viewAll => '查看全部';

  @override
  String get results => '结果';

  @override
  String get nomatch => '没有发现以下字词的匹配信息';

  @override
  String get subscribers => '订阅者';

  @override
  String get about => '关于';

  @override
  String get synced => '已同步';

  @override
  String get plain => '普通';

  @override
  String get songInfo => '歌曲信息';

  @override
  String get id => '标识';

  @override
  String get title => '标题';

  @override
  String get duration => '发行日期';

  @override
  String get audioCodec => '音频编码';

  @override
  String get bitrate => '比特率';

  @override
  String get loudnessDb => '音量分贝';

  @override
  String get deleteDownloadedDataAlert => '成功从下载中移除！';

  @override
  String get cancelTimerAlert => '睡眠定时器已取消';

  @override
  String get sleepTimeSetAlert => '你的睡眠定时器已设定';

  @override
  String get radioNotAvailable => '这位音乐人的电台不可用！';

  @override
  String get songRemovedfromQueue => '已从队列移除！';

  @override
  String get songRemovedfromQueueCurrSong => '不能移除当前正在播放的歌曲';

  @override
  String get songAddedToPlaylistAlert => '歌曲已添加到列表！';

  @override
  String get songAlreadyExists => '这首歌已经存在！';

  @override
  String get songAlreadyOfflineAlert => '已离线保存歌曲至缓存中';

  @override
  String get songEnqueueAlert => '已添加歌曲到队列！';

  @override
  String get songRemovedAlert => '已从中移除';

  @override
  String get errorOccuredAlert => '出错了！';

  @override
  String get pipedplstSyncAlert => 'Piped 播放列表已同步！';

  @override
  String get playlistCreatedAlert => '已创建播放列表！';

  @override
  String get playlistCreatednsongAddedAlert => '已创建播放列表并添加了歌曲！';

  @override
  String get playlistRenameAlert => '重命名成功！';

  @override
  String get playlistRemovedAlert => '已移除播放列表！';

  @override
  String get playlistBookmarkAddAlert => '已收藏播放列表！';

  @override
  String get playlistBookmarkRemoveAlert => '已取消收藏播放列表！';

  @override
  String get albumBookmarkAddAlert => '已收藏专辑！';

  @override
  String get albumBookmarkRemoveAlert => '已取消收藏专辑！';

  @override
  String get artistBookmarkAddAlert => '已收藏音乐人！';

  @override
  String get artistBookmarkRemoveAlert => '已取消收藏音乐人！';

  @override
  String get lyricsNotAvailable => '歌词不可用！';

  @override
  String get syncedLyricsNotAvailable => '滚动歌词不可用！';

  @override
  String get artistDesNotAvailable => '描述不可用！';

  @override
  String get newVersionAvailable => '新版本可用！';

  @override
  String get version => '版本';

  @override
  String get dontShowInfoAgain => '不要再次显示此信息';

  @override
  String get dismiss => '忽略';

  @override
  String get notaSongVideo => '不是歌曲或 MV！';

  @override
  String get notaValidLink => '不是有效链接！';

  @override
  String get operationFailed => '操作失败';

  @override
  String get goToDownloadPage => '点击此处转到下载页面';

  @override
  String get local => '本地';

  @override
  String get piped => 'Piped 代理';

  @override
  String get link => '链接';

  @override
  String get unLink => '取消链接';

  @override
  String get hintApiUrl => 'Piped 实例的 API 地址';

  @override
  String get customIns => '自定义实例';

  @override
  String get customInsSelectMsg => '请选择一个自定义实例';

  @override
  String get selectAuthInsMsg => '请选择用于身份验证的实例！';

  @override
  String get allFieldsReqMsg => '所有的区域均要填写';

  @override
  String get linkPipedDes => '与 Piped 链接以取得播放列表';

  @override
  String get selectAuthIns => '选择认证实例';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get linkAlert => '已成功链接！';

  @override
  String get unlinkAlert => '已成功取消链接！';

  @override
  String get playlistBlacklistAlert => '已将列表加入黑名单！';

  @override
  String get reset => '重设';

  @override
  String get blacklistPlstResetAlert => '重设成功！';

  @override
  String get resetblacklistedplaylist => '重设已拉黑的播放列表';

  @override
  String get resetblacklistedplaylistDes => '重设所有拉黑的 Piped 播放列表';

  @override
  String get stopMusicOnTaskClear => '清除后台任务时停止音乐';

  @override
  String get stopMusicOnTaskClearDes => '音乐后台播放将会在应用被任务管理页划走时停止';

  @override
  String get backupAppData => '备份应用数据';

  @override
  String get androidBackupWarning =>
      '未测试：下载超过 60 个文件后选中复选框，过程可能会消耗大量内存，并可能导致手机或应用程序崩溃。继续操作风险自负。';

  @override
  String get backupSettingsAndPlaylistsDes => '将所有设置、播放列表和登录数据保存在备份文件中';

  @override
  String get backup => '备份';

  @override
  String get letsStrart => '让我们开始吧...';

  @override
  String get processFiles => '正在处理文件…';

  @override
  String get includeDownloadedFiles => '包含下载的歌曲文件';

  @override
  String get backupInProgress => '备份正在进行中...';

  @override
  String get restoreAppData => '恢复应用数据';

  @override
  String get restoreSettingsAndPlaylistsDes => '从备份文件恢复所有设置、登录数据和播放列表。覆盖所有当前数据';

  @override
  String get backupMsg => '备份已成功保存！';

  @override
  String get backFilesFound => '查找数据库';

  @override
  String get restoreMsg => '已成功恢复！\\n更改将在重启时应用';

  @override
  String get restoring => '正在恢复...';

  @override
  String get restore => '恢复';

  @override
  String get closeApp => '关闭应用';

  @override
  String get restartApp => '重启应用';

  @override
  String get exportPlaylist => '导出播放列表';

  @override
  String get exportPlaylistCsv => '以CSV格式导出播放列表';

  @override
  String get exportingPlaylist => '播放列表正在导出……';

  @override
  String get playlistExportedMsg => '成功导出播放列表到';

  @override
  String get exportError => '导出播放列表出错';

  @override
  String get exportErrorPermission => '导出时权限被拒绝';

  @override
  String get exportErrorStorage => '存储空间不足';

  @override
  String get exportErrorFormat => '格式化播放列表数据出错';

  @override
  String get importPlaylist => '导入播放列表';

  @override
  String get importingPlaylist => '导入播放列表中……';

  @override
  String get importPlaylistDesc => '选择一个已导出的播放列表JSON文件进行导入';

  @override
  String get selectFile => '选择文件';

  @override
  String get playlistImportedMsg => '播放列表导入成功';

  @override
  String get importError => '播放列表导入出错';

  @override
  String get importErrorFileAccess => '无法访问已选文件';

  @override
  String get importErrorFormat => '文件格式无效';

  @override
  String get invalidPlaylistFile => '播放列表的文件结构无效';

  @override
  String get importErrorDatabase => '保存到数据库时出错';

  @override
  String get fileNotFound => '文件不存在';

  @override
  String get importLargeFileNote => '注意：如果当前导入的播放列表包含内容较多，可能需要更长的时间';

  @override
  String get exportPlaylistJson => '以JSON格式导出播放列表';

  @override
  String get exportPlaylistJsonSubtitle => '此格式可被导入';

  @override
  String get exportPlaylistCsvSubtitle => '无法在此处导入';

  @override
  String get exportToYouTubeMusic => '导出至Youtube Music';

  @override
  String get exportToYouTubeMusicSubtitle =>
      '这将推送你的播放列表（小于50首）到当前播放队列，请不要忘记在打开YtMusic后将曲目添加到歌单或保存';

  @override
  String get linkCopied => '链接已复制到剪切板';

  @override
  String get keepScreenOnWhilePlaying => '播放时保持屏幕常亮';

  @override
  String get keepScreenOnWhilePlayingDes => '启用后，播放音乐时设备屏幕将保持点亮';

  @override
  String get autoRadio => '自动启动电台';

  @override
  String get autoRadioDes => '播放 YouTube Music 中的单首歌曲时自动启动电台模式';

  @override
  String get resyncLibraryNow => '立即重新同步曲库';

  @override
  String get playbackDiagnosticsRelease => '播放诊断（正式版）';

  @override
  String get viewPlaybackDiagnostics => '查看播放诊断';

  @override
  String get viewPlaybackDiagnosticsSubtitle => '打开日志并复制到剪贴板';

  @override
  String get clearPlaybackDiagnostics => '清除播放诊断';

  @override
  String get clearPlaybackDiagnosticsSubtitle => '删除所有已存储的诊断事件';

  @override
  String get playbackDiagnostics => '播放诊断';

  @override
  String get toggleFormat => '切换格式';

  @override
  String get copyDiagnostics => '复制诊断';

  @override
  String get shrinkSidebar => '收起侧边栏';

  @override
  String get playlistTypeLabel => '播放列表';

  @override
  String get playbackDiagnosticsCleared => '播放诊断已清除';
}
