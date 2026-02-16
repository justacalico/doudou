use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Session {
    pub id: String,
    pub server_id: String,
    pub provider: String,
    pub token: String,
    pub user_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Song {
    pub id: String,
    pub title: String,
    pub album_id: String,
    pub album_name: String,
    pub artist_id: String,
    pub artist_name: String,
    pub duration: f64,
    pub track_number: Option<u32>,
    pub disc_number: Option<u32>,
    pub year: Option<u32>,
    pub genre: Option<String>,
    pub cover_art_url: Option<String>,
    pub stream_url: Option<String>,
    pub is_favorite: bool,
    pub is_downloaded: bool,
    pub local_path: Option<String>,
    pub server_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Album {
    pub id: String,
    pub name: String,
    pub artist_id: String,
    pub artist_name: String,
    pub year: Option<u32>,
    pub song_count: u32,
    pub duration: f64,
    pub genre: Option<String>,
    pub cover_art_url: Option<String>,
    pub server_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Artist {
    pub id: String,
    pub name: String,
    pub album_count: u32,
    pub cover_art_url: Option<String>,
    pub server_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Playlist {
    pub id: String,
    pub name: String,
    pub song_count: u32,
    pub duration: f64,
    pub cover_art_url: Option<String>,
    pub is_public: bool,
    pub server_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchResults {
    pub albums: Vec<Album>,
    pub artists: Vec<Artist>,
    pub songs: Vec<Song>,
    pub playlists: Vec<Playlist>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AlbumDetail {
    pub album: Album,
    pub songs: Vec<Song>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QueueItem {
    pub song: Song,
    pub queue_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Queue {
    pub items: Vec<QueueItem>,
    pub current_index: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Download {
    pub id: String,
    pub item_id: String,
    pub item_type: String,
    pub server_id: String,
    pub progress: f64,
    pub status: String,
    pub local_path: Option<String>,
    pub created_at: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Metadata {
    pub title: Option<String>,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub duration_seconds: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Settings {
    pub theme: String,
    pub accent_color: String,
    pub crossfade_seconds: u32,
    pub gapless_enabled: bool,
    pub normalize_audio: bool,
    pub scrobbling_enabled: bool,
    pub download_path: Option<String>,
}
