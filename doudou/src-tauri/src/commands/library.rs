use crate::models::{Album, AlbumDetail, Artist, SearchResults};
use crate::models::{Playlist, Song};

#[tauri::command]
pub async fn fetch_albums(
    session_id: String,
    _sort: Option<String>,
    _filter: Option<String>,
) -> Result<Vec<Album>, String> {
    let demo_album = Album {
        id: "demo-album-1".to_string(),
        name: "Porting Baseline".to_string(),
        artist_id: "demo-artist-1".to_string(),
        artist_name: "Doudou".to_string(),
        year: Some(2026),
        song_count: 1,
        duration: 180.0,
        genre: Some("Electronic".to_string()),
        cover_art_url: None,
        server_id: session_id,
    };
    Ok(vec![demo_album])
}

#[tauri::command]
pub async fn fetch_artists(session_id: String) -> Result<Vec<Artist>, String> {
    Ok(vec![Artist {
        id: "demo-artist-1".to_string(),
        name: "Doudou".to_string(),
        album_count: 1,
        cover_art_url: None,
        server_id: session_id,
    }])
}

#[tauri::command]
pub async fn fetch_album_details(
    session_id: String,
    album_id: String,
) -> Result<AlbumDetail, String> {
    let album = Album {
        id: album_id,
        name: "Porting Baseline".to_string(),
        artist_id: "demo-artist-1".to_string(),
        artist_name: "Doudou".to_string(),
        year: Some(2026),
        song_count: 1,
        duration: 180.0,
        genre: Some("Electronic".to_string()),
        cover_art_url: None,
        server_id: session_id.clone(),
    };
    let song = Song {
        id: "demo-song-1".to_string(),
        title: "Feature Parity (Work In Progress)".to_string(),
        album_id: album.id.clone(),
        album_name: album.name.clone(),
        artist_id: "demo-artist-1".to_string(),
        artist_name: "Doudou".to_string(),
        duration: 180.0,
        track_number: Some(1),
        disc_number: Some(1),
        year: Some(2026),
        genre: Some("Electronic".to_string()),
        cover_art_url: None,
        stream_url: None,
        is_favorite: false,
        is_downloaded: false,
        local_path: None,
        server_id: session_id,
    };
    Ok(AlbumDetail {
        album,
        songs: vec![song],
    })
}

#[tauri::command]
pub async fn fetch_playlists(session_id: String) -> Result<Vec<Playlist>, String> {
    Ok(vec![Playlist {
        id: "demo-playlist-1".to_string(),
        name: "Queue Snapshot".to_string(),
        song_count: 1,
        duration: 180.0,
        cover_art_url: None,
        is_public: false,
        server_id: session_id,
    }])
}

#[tauri::command]
pub async fn search_library(_session_id: String, _query: String) -> Result<SearchResults, String> {
    Ok(SearchResults {
        albums: vec![],
        artists: vec![],
        songs: vec![],
        playlists: vec![],
    })
}
