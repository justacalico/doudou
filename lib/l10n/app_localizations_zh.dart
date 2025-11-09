// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '豆豆';

  @override
  String get settings => '设置';

  @override
  String get general => '常规';

  @override
  String get audio => '音频';

  @override
  String get appearance => '外观';

  @override
  String get server => '服务器';

  @override
  String get logs => '日志';

  @override
  String get about => '关于';

  @override
  String get generalSettings => '常规设置';

  @override
  String get audioSettings => '音频设置';

  @override
  String get appearanceSettings => '外观设置';

  @override
  String get serverSettings => '服务器设置';

  @override
  String get logsAndDiagnostics => '日志与诊断';

  @override
  String get aboutDoudou => '关于豆豆';

  @override
  String get startup => '启动';

  @override
  String get startWithSystem => '开机启动';

  @override
  String get startWithSystemDesc => '计算机启动时自动启动豆豆';

  @override
  String get startMinimized => '最小化启动';

  @override
  String get startMinimizedDesc => '启动到系统托盘而不是窗口';

  @override
  String get library => '资料库';

  @override
  String get autoRefreshLibrary => '自动刷新资料库';

  @override
  String get autoRefreshLibraryDesc => '自动检查新音乐';

  @override
  String get defaultLibraryView => '默认资料库视图';

  @override
  String get albums => '专辑';

  @override
  String get artists => '艺术家';

  @override
  String get songs => '歌曲';

  @override
  String get playlists => '播放列表';

  @override
  String get downloads => '下载';

  @override
  String get downloadLocation => '下载位置';

  @override
  String get downloadOverCellular => '使用蜂窝数据下载';

  @override
  String get downloadOverCellularDesc => '允许使用移动数据下载';

  @override
  String get playback => '播放';

  @override
  String get audioQuality => '音频质量';

  @override
  String get high => '高 (320 kbps)';

  @override
  String get medium => '中 (192 kbps)';

  @override
  String get low => '低 (128 kbps)';

  @override
  String get volume => '音量';

  @override
  String get volumeNormalization => '音量标准化';

  @override
  String get volumeNormalizationDesc => '保持曲目间音量一致';

  @override
  String get fadeOnPause => '暂停/恢复时淡出';

  @override
  String get fadeOnPauseDesc => '平滑的音量过渡';

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
  String get systemTheme => '系统默认';

  @override
  String get lightTheme => '浅色';

  @override
  String get darkTheme => '深色';

  @override
  String get accentColor => '强调色';

  @override
  String get chooseTheme => '选择主题';

  @override
  String get chooseAccentColor => '选择强调色';

  @override
  String get layout => '布局';

  @override
  String get compactMode => '紧凑模式';

  @override
  String get compactModeDesc => '减少间距和填充';

  @override
  String get showAlbumArtInSidebar => '在侧边栏显示专辑封面';

  @override
  String get showAlbumArtInSidebarDesc => '显示当前曲目封面';

  @override
  String get gridSize => '网格大小';

  @override
  String get small => '小';

  @override
  String get large => '大';

  @override
  String get window => '窗口';

  @override
  String get closeToSystemTray => '关闭到系统托盘';

  @override
  String get closeToSystemTrayDesc => '关闭窗口时保持运行';

  @override
  String get showInTaskbar => '在任务栏显示';

  @override
  String get showInTaskbarDesc => '在任务栏显示应用图标';

  @override
  String get language => '语言';

  @override
  String get languageSettings => '语言';

  @override
  String get selectLanguage => '选择语言';

  @override
  String get english => 'English (英语)';

  @override
  String get chinese => '简体中文';

  @override
  String get russian => 'Русский (俄语)';

  @override
  String get connection => '连接';

  @override
  String get connected => '已连接';

  @override
  String get disconnected => '未连接';

  @override
  String get serverUrl => '服务器地址';

  @override
  String get notSet => '未设置';

  @override
  String get username => '用户名';

  @override
  String get notLoggedIn => '未登录';

  @override
  String get testConnection => '测试连接';

  @override
  String get signOut => '退出登录';

  @override
  String get signOutConfirm => '确定要退出登录吗？您需要重新登录才能访问您的音乐。';

  @override
  String get cache => '缓存';

  @override
  String get cacheSize => '缓存大小';

  @override
  String get calculating => '计算中...';

  @override
  String get clearImageCache => '清除图片缓存';

  @override
  String get clearImageCacheDesc => '释放存储空间';

  @override
  String get clearAllCache => '清除全部缓存';

  @override
  String get clearAllCacheDesc => '删除所有缓存数据';

  @override
  String get clearCache => '清除缓存';

  @override
  String clearCacheConfirm(String type) {
    return '这将删除$type，可能会暂时降低应用速度。继续？';
  }

  @override
  String get allCachedData => '所有缓存数据';

  @override
  String get cachedImages => '缓存图片';

  @override
  String cacheCleared(String type) {
    return '$type已清除';
  }

  @override
  String get allCache => '全部缓存';

  @override
  String get imageCache => '图片缓存';

  @override
  String get enableLogging => '启用日志记录';

  @override
  String get enableLoggingDesc => '记录应用活动以便故障排除。默认禁用以提高性能。';

  @override
  String get recentLogs => '最近日志';

  @override
  String get noLogsAvailable => '没有可用日志';

  @override
  String get refresh => '刷新';

  @override
  String get exportLogs => '导出日志';

  @override
  String get clearLogs => '清除日志';

  @override
  String get clearLogsConfirm => '确定要清除所有日志吗？此操作无法撤销。';

  @override
  String logsExportedTo(String path) {
    return '日志已导出到：$path';
  }

  @override
  String failedToExportLogs(String error) {
    return '导出日志失败：$error';
  }

  @override
  String get logStatistics => '日志统计';

  @override
  String get logFiles => '日志文件';

  @override
  String get totalSize => '总大小';

  @override
  String get memoryLogs => '内存日志';

  @override
  String get appDescription => '适合所有人的精美音乐播放器。';

  @override
  String version(String version) {
    return '版本 $version';
  }

  @override
  String get links => '链接';

  @override
  String get githubRepository => 'GitHub 仓库';

  @override
  String get githubRepositoryDesc => '源代码和问题';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get privacyPolicyDesc => '我们如何处理您的数据';

  @override
  String get termsOfService => '服务条款';

  @override
  String get termsOfServiceDesc => '使用条款和条件';

  @override
  String get systemInformation => '系统信息';

  @override
  String get platform => '平台';

  @override
  String get buildDate => '构建日期';

  @override
  String get operatingSystem => '操作系统';

  @override
  String get home => '主页';

  @override
  String get search => '搜索';

  @override
  String get favorites => '收藏';

  @override
  String get nowPlaying => '正在播放';

  @override
  String get play => '播放';

  @override
  String get pause => '暂停';

  @override
  String get next => '下一首';

  @override
  String get previous => '上一首';

  @override
  String get shuffle => '随机播放';

  @override
  String get repeat => '重复播放';

  @override
  String get cancel => '取消';

  @override
  String get ok => '确定';

  @override
  String get apply => '应用';

  @override
  String get clear => '清除';

  @override
  String get close => '关闭';

  @override
  String get save => '保存';

  @override
  String get connectionSuccessful => '连接成功！';

  @override
  String get connectionFailed => '连接失败。请检查您的设置。';

  @override
  String get purple => '紫色';

  @override
  String get blue => '蓝色';

  @override
  String get green => '绿色';

  @override
  String get orange => '橙色';

  @override
  String get red => '红色';

  @override
  String get teal => '青色';

  @override
  String get customColor => '自定义颜色';

  @override
  String get custom => '自定义';

  @override
  String get quickColors => '快速颜色：';

  @override
  String get preview => '预览';
}
