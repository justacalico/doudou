use std::collections::HashMap;
use std::path::PathBuf;

use crate::models::{Download, QueueItem, RepeatMode, Settings, Song};

#[derive(Debug, Clone)]
pub struct ProviderSession {
    pub id: String,
    pub provider: String,
    pub server_url: String,
    pub username: String,
    pub token: String,
    pub salt: Option<String>,
}

#[derive(Debug, Clone)]
pub struct PlaybackEngineState {
    pub queue_original: Vec<QueueItem>,
    pub queue_before_shuffle: Option<Vec<QueueItem>>,
    pub current_index: i32,
    pub is_playing: bool,
    pub current_time: f64,
    pub duration: f64,
    pub volume: f64,
    pub shuffle: bool,
    pub repeat_mode: RepeatMode,
    pub is_background: bool,
    pub current_song: Option<Song>,
}

impl Default for PlaybackEngineState {
    fn default() -> Self {
        Self {
            queue_original: vec![],
            queue_before_shuffle: None,
            current_index: -1,
            is_playing: false,
            current_time: 0.0,
            duration: 0.0,
            volume: 1.0,
            shuffle: false,
            repeat_mode: RepeatMode::Off,
            is_background: false,
            current_song: None,
        }
    }
}

#[derive(Debug)]
pub struct AppState {
    pub sessions: parking_lot::RwLock<HashMap<String, ProviderSession>>,
    pub playback: parking_lot::RwLock<PlaybackEngineState>,
    pub downloads: parking_lot::RwLock<HashMap<String, Download>>,
    pub settings: parking_lot::RwLock<Settings>,
    pub local_index: parking_lot::RwLock<HashMap<String, Song>>,
    pub app_data_dir: parking_lot::RwLock<Option<PathBuf>>,
}

impl Default for AppState {
    fn default() -> Self {
        Self {
            sessions: parking_lot::RwLock::new(HashMap::new()),
            playback: parking_lot::RwLock::new(PlaybackEngineState::default()),
            downloads: parking_lot::RwLock::new(HashMap::new()),
            settings: parking_lot::RwLock::new(Settings {
                theme: "dark".to_string(),
                accent_color: "#4f8bff".to_string(),
                crossfade_seconds: 0,
                gapless_enabled: true,
                normalize_audio: false,
                scrobbling_enabled: false,
                download_path: None,
            }),
            local_index: parking_lot::RwLock::new(HashMap::new()),
            app_data_dir: parking_lot::RwLock::new(None),
        }
    }
}
