use tauri::State;

use crate::models::{Album, AlbumDetail, Artist, Library, Playlist, SearchResults, Song};
use crate::providers::jellyfin::JellyfinProvider;
use crate::providers::local::LocalProvider;
use crate::providers::plex::PlexProvider;
use crate::providers::subsonic::SubsonicProvider;
use crate::providers::ProviderKind;
use crate::state::{AppState, ProviderSession};

fn get_session(state: &AppState, session_id: &str) -> Result<ProviderSession, String> {
    state
        .sessions
        .read()
        .get(session_id)
        .cloned()
        .ok_or_else(|| "session not found".to_string())
}

#[tauri::command]
pub async fn fetch_albums(
    session_id: String,
    sort: Option<String>,
    filter: Option<String>,
    state: State<'_, AppState>,
) -> Result<Vec<Album>, String> {
    let session = get_session(&state, &session_id)?;
    match ProviderKind::parse(&session.provider)? {
        ProviderKind::Subsonic => SubsonicProvider::new()?.get_albums(&session, sort, filter).await,
        ProviderKind::Jellyfin => JellyfinProvider::new().get_albums(&session).await,
        ProviderKind::Plex => PlexProvider::new().get_albums(&session).await,
        ProviderKind::Local => LocalProvider.get_albums(&session).await,
    }
}

#[tauri::command]
pub async fn fetch_artists(
    session_id: String,
    state: State<'_, AppState>,
) -> Result<Vec<Artist>, String> {
    let session = get_session(&state, &session_id)?;
    match ProviderKind::parse(&session.provider)? {
        ProviderKind::Subsonic => SubsonicProvider::new()?.get_artists(&session).await,
        ProviderKind::Jellyfin => JellyfinProvider::new().get_artists(&session).await,
        ProviderKind::Plex => PlexProvider::new().get_artists(&session).await,
        ProviderKind::Local => LocalProvider.get_artists(&session).await,
    }
}

#[tauri::command]
pub async fn fetch_album_details(
    session_id: String,
    album_id: String,
    state: State<'_, AppState>,
) -> Result<AlbumDetail, String> {
    let session = get_session(&state, &session_id)?;
    match ProviderKind::parse(&session.provider)? {
        ProviderKind::Subsonic => {
            let provider = SubsonicProvider::new()?;
            let albums = provider.get_albums(&session, None, None).await?;
            let album = albums
                .into_iter()
                .find(|album| album.id == album_id)
                .ok_or_else(|| "album not found".to_string())?;
            let songs = provider
                .get_album_songs(&session, album.id.clone())
                .await
                .unwrap_or_default();
            Ok(AlbumDetail { album, songs })
        }
        _ => Err("album details are not implemented for this provider".to_string()),
    }
}

#[tauri::command]
pub async fn fetch_playlists(
    session_id: String,
    state: State<'_, AppState>,
) -> Result<Vec<Playlist>, String> {
    let session = get_session(&state, &session_id)?;
    match ProviderKind::parse(&session.provider)? {
        ProviderKind::Subsonic => SubsonicProvider::new()?.get_playlists(&session).await,
        ProviderKind::Jellyfin => JellyfinProvider::new().get_playlists(&session).await,
        ProviderKind::Plex => PlexProvider::new().get_playlists(&session).await,
        ProviderKind::Local => LocalProvider.get_playlists(&session).await,
    }
}

#[tauri::command]
pub async fn search_library(
    session_id: String,
    query: String,
    state: State<'_, AppState>,
) -> Result<SearchResults, String> {
    let session = get_session(&state, &session_id)?;
    match ProviderKind::parse(&session.provider)? {
        ProviderKind::Subsonic => SubsonicProvider::new()?.search(&session, query).await,
        ProviderKind::Jellyfin => JellyfinProvider::new().search(&session, query).await,
        ProviderKind::Plex => PlexProvider::new().search(&session, query).await,
        ProviderKind::Local => LocalProvider.search(&session, query).await,
    }
}

#[tauri::command]
pub async fn fetch_libraries(
    session_id: String,
    state: State<'_, AppState>,
) -> Result<Vec<Library>, String> {
    let session = get_session(&state, &session_id)?;
    match ProviderKind::parse(&session.provider)? {
        ProviderKind::Subsonic => SubsonicProvider::new()?.get_libraries(&session).await,
        ProviderKind::Local => Ok(vec![Library {
            id: "local".to_string(),
            name: "Local Library".to_string(),
            collection_type: "music".to_string(),
            image_url: None,
        }]),
        _ => Ok(vec![]),
    }
}

#[tauri::command]
pub async fn fetch_playlist_tracks(
    session_id: String,
    playlist_id: String,
    state: State<'_, AppState>,
) -> Result<Vec<Song>, String> {
    let session = get_session(&state, &session_id)?;
    match ProviderKind::parse(&session.provider)? {
        ProviderKind::Subsonic => SubsonicProvider::new()?
            .get_playlist_tracks(&session, playlist_id)
            .await,
        ProviderKind::Jellyfin => JellyfinProvider::new().get_tracks(&session).await,
        ProviderKind::Plex => PlexProvider::new().get_tracks(&session).await,
        ProviderKind::Local => Ok(vec![]),
    }
}

#[tauri::command]
pub async fn get_all_tracks(
    session_id: String,
    state: State<'_, AppState>,
) -> Result<Vec<Song>, String> {
    let session = get_session(&state, &session_id)?;
    match ProviderKind::parse(&session.provider)? {
        ProviderKind::Subsonic => SubsonicProvider::new()?.get_all_tracks(&session).await,
        ProviderKind::Jellyfin => JellyfinProvider::new().get_tracks(&session).await,
        ProviderKind::Plex => PlexProvider::new().get_tracks(&session).await,
        ProviderKind::Local => Ok(vec![]),
    }
}

#[tauri::command]
pub async fn get_starred_tracks(
    session_id: String,
    state: State<'_, AppState>,
) -> Result<Vec<Song>, String> {
    let session = get_session(&state, &session_id)?;
    match ProviderKind::parse(&session.provider)? {
        ProviderKind::Subsonic => SubsonicProvider::new()?.get_starred_tracks(&session).await,
        _ => Ok(vec![]),
    }
}

#[tauri::command]
pub async fn toggle_favorite(
    session_id: String,
    item_id: String,
    is_favorite: bool,
    state: State<'_, AppState>,
) -> Result<(), String> {
    let session = get_session(&state, &session_id)?;
    match ProviderKind::parse(&session.provider)? {
        ProviderKind::Subsonic => {
            SubsonicProvider::new()?
                .toggle_favorite(&session, item_id, is_favorite)
                .await
        }
        _ => Ok(()),
    }
}

#[tauri::command]
pub async fn create_playlist(
    session_id: String,
    name: String,
    state: State<'_, AppState>,
) -> Result<Option<Playlist>, String> {
    let session = get_session(&state, &session_id)?;
    match ProviderKind::parse(&session.provider)? {
        ProviderKind::Subsonic => SubsonicProvider::new()?.create_playlist(&session, name).await,
        _ => Ok(None),
    }
}

#[tauri::command]
pub async fn add_track_to_playlist(
    session_id: String,
    playlist_id: String,
    track_id: String,
    state: State<'_, AppState>,
) -> Result<(), String> {
    let session = get_session(&state, &session_id)?;
    match ProviderKind::parse(&session.provider)? {
        ProviderKind::Subsonic => {
            SubsonicProvider::new()?
                .add_to_playlist(&session, playlist_id, track_id)
                .await
        }
        _ => Ok(()),
    }
}

#[tauri::command]
pub async fn remove_track_from_playlist(
    session_id: String,
    playlist_id: String,
    track_index: usize,
    state: State<'_, AppState>,
) -> Result<(), String> {
    let session = get_session(&state, &session_id)?;
    match ProviderKind::parse(&session.provider)? {
        ProviderKind::Subsonic => {
            SubsonicProvider::new()?
                .remove_track_from_playlist(&session, playlist_id, track_index)
                .await
        }
        _ => Ok(()),
    }
}

#[tauri::command]
pub async fn rename_playlist(
    session_id: String,
    playlist_id: String,
    new_name: String,
    state: State<'_, AppState>,
) -> Result<(), String> {
    let session = get_session(&state, &session_id)?;
    match ProviderKind::parse(&session.provider)? {
        ProviderKind::Subsonic => {
            SubsonicProvider::new()?
                .rename_playlist(&session, playlist_id, new_name)
                .await
        }
        _ => Ok(()),
    }
}

#[tauri::command]
pub async fn remove_playlist(
    session_id: String,
    playlist_id: String,
    state: State<'_, AppState>,
) -> Result<(), String> {
    let session = get_session(&state, &session_id)?;
    match ProviderKind::parse(&session.provider)? {
        ProviderKind::Subsonic => {
            SubsonicProvider::new()?
                .remove_playlist(&session, playlist_id)
                .await
        }
        _ => Ok(()),
    }
}
