use crate::models::{Queue, QueueItem, Song};

#[tauri::command]
pub async fn play_song(_session_id: String, _song_id: String) -> Result<(), String> {
    Ok(())
}

#[tauri::command]
pub async fn pause() -> Result<(), String> {
    Ok(())
}

#[tauri::command]
pub async fn resume() -> Result<(), String> {
    Ok(())
}

#[tauri::command]
pub async fn next_song() -> Result<(), String> {
    Ok(())
}

#[tauri::command]
pub async fn previous_song() -> Result<(), String> {
    Ok(())
}

#[tauri::command]
pub async fn seek(_position: f64) -> Result<(), String> {
    Ok(())
}

#[tauri::command]
pub async fn set_volume(_volume: f64) -> Result<(), String> {
    Ok(())
}

#[tauri::command]
pub async fn add_to_queue(_session_id: String, _songs: Vec<String>) -> Result<(), String> {
    Ok(())
}

#[tauri::command]
pub async fn reorder_queue(_from: usize, _to: usize) -> Result<(), String> {
    Ok(())
}

#[tauri::command]
pub async fn clear_queue() -> Result<(), String> {
    Ok(())
}

#[tauri::command]
pub async fn get_queue() -> Result<Queue, String> {
    let sample_song = Song {
        id: "demo-song-1".to_string(),
        title: "Feature Parity (Work In Progress)".to_string(),
        album_id: "demo-album-1".to_string(),
        album_name: "Porting Baseline".to_string(),
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
        server_id: "demo".to_string(),
    };
    Ok(Queue {
        items: vec![QueueItem {
            song: sample_song,
            queue_id: "demo-q-1".to_string(),
        }],
        current_index: 0,
    })
}

#[tauri::command]
pub async fn enable_background_playback() -> Result<(), String> {
    Ok(())
}

#[tauri::command]
pub async fn update_now_playing_info(_song: Song) -> Result<(), String> {
    Ok(())
}
