use crate::models::{Metadata, Song};

#[tauri::command]
pub async fn scan_local_folder(_path: String) -> Result<Vec<Song>, String> {
    Ok(vec![])
}

#[tauri::command]
pub async fn read_audio_metadata(_path: String) -> Result<Metadata, String> {
    Ok(Metadata {
        title: None,
        artist: None,
        album: None,
        duration_seconds: None,
    })
}

#[tauri::command]
pub async fn fetch_online_artwork(_artist: String, _album: String) -> Result<String, String> {
    Ok(String::new())
}
