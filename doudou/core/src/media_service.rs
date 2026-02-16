//! Media service trait (mirrors Flutter BaseMediaService).
//! Implementations live in src-tauri; this crate only defines the interface.

use crate::models::*;

/// Base interface for all media server services.
/// Implementations (Jellyfin, Plex, Subsonic, local) live in the Tauri backend.
#[allow(clippy::module_name_repetitions)]
pub trait MediaService: Send + Sync {
    fn server_type(&self) -> ServerType;

    /// Get image URL for an item (id may be item id or full URL).
    fn get_image_url(
        &self,
        item_id: &str,
        image_type: &str,
        width: Option<u32>,
        height: Option<u32>,
    ) -> String;

    /// Get stream URL for a track (called by backend when playing).
    fn get_stream_url(&self, track_id: &str, bitrate: Option<u32>) -> String;
}

/// DTOs for Tauri commands: request/response types that cross the boundary.
/// All I/O and async work happens in src-tauri; these are just data.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct LoginRequest {
    pub server_url: String,
    pub identifier: String,
    pub credential: String,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct LibraryResponse {
    pub albums: Vec<Album>,
    pub artists: Vec<Artist>,
    pub tracks: Vec<Track>,
    pub playlists: Vec<Playlist>,
    pub libraries: Vec<Library>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct PlaybackStateResponse {
    pub current_track: Option<Track>,
    pub is_playing: bool,
    pub position_ms: u64,
    pub duration_ms: u64,
}
