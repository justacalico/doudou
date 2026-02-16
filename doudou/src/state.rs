//! Shared state types (mirror backend responses for deserialization).

use serde::Deserialize;

#[derive(Deserialize)]
pub struct LibraryData {
    pub albums: Vec<Album>,
    pub artists: Vec<Artist>,
    pub tracks: Vec<Track>,
    pub playlists: Vec<Playlist>,
    pub libraries: Vec<Library>,
}

#[derive(Deserialize)]
pub struct Album {
    pub id: String,
    pub name: String,
    pub artist_name: Option<String>,
    pub image_url: Option<String>,
    pub year: Option<i32>,
    pub date_created: Option<String>,
    pub is_favorite: bool,
}

#[derive(Deserialize)]
pub struct Artist {
    pub id: String,
    pub name: String,
    pub image_url: Option<String>,
}

#[derive(Deserialize)]
pub struct Track {
    pub id: String,
    pub name: String,
    pub album_name: Option<String>,
    pub artist_name: Option<String>,
    pub album_id: Option<String>,
    pub duration: Option<u64>,
    pub track_number: Option<u32>,
    pub image_url: Option<String>,
    pub is_favorite: bool,
}

#[derive(Deserialize)]
pub struct Playlist {
    pub id: String,
    pub name: String,
    pub image_url: Option<String>,
    pub track_count: u32,
}

#[derive(Deserialize)]
pub struct Library {
    pub id: String,
    pub name: String,
    pub collection_type: String,
    pub image_url: Option<String>,
}
