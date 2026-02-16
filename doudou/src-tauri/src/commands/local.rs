use tauri::State;

use crate::local as local_service;
use crate::models::{Metadata, Song};
use crate::state::AppState;

#[tauri::command]
pub async fn scan_local_folder(path: String, state: State<'_, AppState>) -> Result<Vec<Song>, String> {
    let files = local_service::scan(&path);
    let mut songs = Vec::with_capacity(files.len());
    let mut index = state.local_index.write();
    for file in files {
        let metadata = local_service::read_metadata(&file);
        let song = local_service::song_from_file(&file, &metadata);
        index.insert(song.id.clone(), song.clone());
        songs.push(song);
    }
    Ok(songs)
}

#[tauri::command]
pub async fn read_audio_metadata(path: String) -> Result<Metadata, String> {
    Ok(local_service::read_metadata(&path))
}

#[tauri::command]
pub async fn fetch_online_artwork(artist: String, album: String) -> Result<String, String> {
    let query = format!("{artist} {album} cover");
    let encoded = query.replace(' ', "+");
    Ok(format!(
        "https://coverartarchive.org/search/?q={encoded}"
    ))
}
