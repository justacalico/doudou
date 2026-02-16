//! Minimal i18n (en, zh, ru). Keys mirror Flutter app_localizations.

pub fn t(locale: &str, key: &str) -> &'static str {
    let locale = match locale {
        "zh" => "zh",
        "ru" => "ru",
        _ => "en",
    };
    match locale {
        "zh" => ZH.get(key).copied().unwrap_or_else(|| EN.get(key).copied().unwrap_or("")),
        "ru" => RU.get(key).copied().unwrap_or_else(|| EN.get(key).copied().unwrap_or("")),
        _ => EN.get(key).copied().unwrap_or(""),
    }
}

macro_rules! map {
    ($($k:expr => $v:expr),* $(,)?) => {
        [
            $(($k, $v)),*
        ].into_iter().collect()
    };
}

lazy_static::lazy_static! {
    static ref EN: std::collections::HashMap<&'static str, &'static str> = map! {
        "appTitle" => "Doudou - Music Player",
        "navHome" => "Home",
        "navSettings" => "Settings",
        "navLibrary" => "Library",
        "navPlaylists" => "Playlists",
        "navSearch" => "Search",
        "navDownloads" => "Downloads",
        "signIn" => "Sign in",
        "connectJellyfin" => "Connect to your Jellyfin server",
        "loading" => "Loading...",
        "play" => "Play",
        "pause" => "Pause",
        "noTrackPlaying" => "No track playing",
        "recentlyAdded" => "Recently added",
        "settings" => "Settings",
    };
    static ref ZH: std::collections::HashMap<&'static str, &'static str> = map! {
        "appTitle" => "Doudou - 音乐播放器",
        "navHome" => "首页",
        "navSettings" => "设置",
        "navLibrary" => "媒体库",
        "navPlaylists" => "播放列表",
        "navSearch" => "搜索",
        "navDownloads" => "下载",
        "signIn" => "登录",
        "connectJellyfin" => "连接到 Jellyfin 服务器",
        "loading" => "加载中...",
        "play" => "播放",
        "pause" => "暂停",
        "noTrackPlaying" => "未播放",
        "recentlyAdded" => "最近添加",
        "settings" => "设置",
    };
    static ref RU: std::collections::HashMap<&'static str, &'static str> = map! {
        "appTitle" => "Doudou - Музыкальный плеер",
        "navHome" => "Главная",
        "navSettings" => "Настройки",
        "navLibrary" => "Библиотека",
        "navPlaylists" => "Плейлисты",
        "navSearch" => "Поиск",
        "navDownloads" => "Загрузки",
        "signIn" => "Войти",
        "connectJellyfin" => "Подключиться к Jellyfin",
        "loading" => "Загрузка...",
        "play" => "Играть",
        "pause" => "Пауза",
        "noTrackPlaying" => "Нет трека",
        "recentlyAdded" => "Недавно добавленные",
        "settings" => "Настройки",
    };
}
