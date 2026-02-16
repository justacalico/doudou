//! Shared data models for Doudou (mirrors Flutter jellyfin_models).

use serde::{Deserialize, Serialize};

/// Server connection config (Jellyfin-style; Plex/Subsonic can map to this).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JellyfinServer {
    pub server_url: String,
    pub api_key: Option<String>,
    pub user_id: Option<String>,
    pub access_token: Option<String>,
    pub username: Option<String>,
    pub password: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Album {
    pub id: String,
    pub name: String,
    pub artist_name: Option<String>,
    pub image_url: Option<String>,
    pub year: Option<i32>,
    pub date_created: Option<String>,
    pub is_favorite: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Track {
    pub id: String,
    pub name: String,
    pub album_name: Option<String>,
    pub artist_name: Option<String>,
    pub album_id: Option<String>,
    pub playlist_item_id: Option<String>,
    /// Duration in milliseconds.
    pub duration: Option<u64>,
    pub track_number: Option<u32>,
    pub image_url: Option<String>,
    pub is_favorite: bool,
    pub play_count: Option<u32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Artist {
    pub id: String,
    pub name: String,
    pub image_url: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Playlist {
    pub id: String,
    pub name: String,
    pub image_url: Option<String>,
    pub track_count: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Library {
    pub id: String,
    pub name: String,
    pub collection_type: String,
    pub image_url: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ServerType {
    Jellyfin,
    Plex,
    Subsonic,
    Local,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchResults {
    pub albums: Vec<Album>,
    pub artists: Vec<Artist>,
    pub tracks: Vec<Track>,
    pub playlists: Vec<Playlist>,
}

impl Default for SearchResults {
    fn default() -> Self {
        Self {
            albums: Vec::new(),
            artists: Vec::new(),
            tracks: Vec::new(),
            playlists: Vec::new(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerInfo {
    pub name: String,
    pub version: String,
    pub id: String,
    pub server_type: ServerType,
}
