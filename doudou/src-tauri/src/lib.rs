mod audio;
mod db;
mod jellyfin;
mod storage;

use doudou_core::{LibraryResponse, PlaybackStateResponse, Track};
use tauri::{Emitter, Manager};
use storage::AppSettings;

#[tauri::command]
async fn login(
    app: tauri::AppHandle,
    server_url: String,
    username: String,
    password: String,
) -> Result<doudou_core::JellyfinServer, String> {
    let client = app.state::<jellyfin::JellyfinClient>();
    let server = client
        .authenticate(server_url.trim(), &username, &password)
        .await?;
    storage::save_server(&app, &server)?;
    Ok(server)
}

#[tauri::command]
async fn logout(app: tauri::AppHandle) -> Result<(), String> {
    let client = app.state::<jellyfin::JellyfinClient>();
    client.set_server(None);
    storage::clear_server(&app)?;
    Ok(())
}

#[tauri::command]
async fn get_library(app: tauri::AppHandle) -> Result<LibraryResponse, String> {
    let client = app.state::<jellyfin::JellyfinClient>();
    let albums = client.get_albums().await?;
    let artists = client.get_artists().await?;
    let tracks = client.get_tracks(None).await?;
    let playlists = client.get_playlists().await?;
    let libraries = client.get_views().await?;
    Ok(LibraryResponse {
        albums,
        artists,
        tracks,
        playlists,
        libraries,
    })
}

#[tauri::command]
fn get_image_url(
    app: tauri::AppHandle,
    item_id: String,
    image_type: Option<String>,
    width: Option<u32>,
    height: Option<u32>,
) -> Result<String, String> {
    let client = app.state::<jellyfin::JellyfinClient>();
    let url = client.get_image_url(
        &item_id,
        image_type.as_deref().unwrap_or("Primary"),
        width,
        height,
    );
    Ok(url)
}

#[tauri::command]
fn get_settings(app: tauri::AppHandle) -> Result<AppSettings, String> {
    storage::load_settings(&app)
}

#[tauri::command]
fn set_settings(app: tauri::AppHandle, settings: AppSettings) -> Result<(), String> {
    storage::save_settings(&app, &settings)
}

#[tauri::command]
fn get_server(app: tauri::AppHandle) -> Result<Option<doudou_core::JellyfinServer>, String> {
    let stored = storage::load_server(&app)?;
    if let Some(ref server) = stored {
        let client = app.state::<jellyfin::JellyfinClient>();
        client.set_server(Some(server.clone()));
    }
    Ok(stored)
}

#[tauri::command]
fn get_playback_state(app: tauri::AppHandle) -> Result<PlaybackStateResponse, String> {
    let audio = app.state::<audio::AudioState>();
    let state = audio.0.lock().map_err(|e| e.to_string())?;
    Ok(state.to_response())
}

#[tauri::command]
async fn play_track(app: tauri::AppHandle, track: Track) -> Result<(), String> {
    let client = app.state::<jellyfin::JellyfinClient>();
    let _stream_url = client.get_stream_url(&track.id, None);
    let audio = app.state::<audio::AudioState>();
    let duration_ms = track.duration.unwrap_or(0);
    let mut state = audio.0.lock().map_err(|e| e.to_string())?;
    state.current_track = Some(track);
    state.is_playing = true;
    state.position_ms = 0;
    state.duration_ms = duration_ms;
    state.started_at = Some(std::time::Instant::now());
    drop(state);
    let _ = app.emit("playback-state", ());
    Ok(())
}

#[tauri::command]
fn pause(app: tauri::AppHandle) -> Result<(), String> {
    let audio = app.state::<audio::AudioState>();
    let mut state = audio.0.lock().map_err(|e| e.to_string())?;
    state.is_playing = false;
    drop(state);
    let _ = app.emit("playback-state", ());
    Ok(())
}

#[tauri::command]
fn resume(app: tauri::AppHandle) -> Result<(), String> {
    let audio = app.state::<audio::AudioState>();
    let mut state = audio.0.lock().map_err(|e| e.to_string())?;
    state.is_playing = true;
    state.started_at = Some(std::time::Instant::now());
    drop(state);
    let _ = app.emit("playback-state", ());
    Ok(())
}

#[tauri::command]
fn seek(_app: tauri::AppHandle, position_ms: u64) -> Result<(), String> {
    let audio = _app.state::<audio::AudioState>();
    let mut state = audio.0.lock().map_err(|e| e.to_string())?;
    state.position_ms = position_ms;
    state.started_at = Some(std::time::Instant::now());
    drop(state);
    let _ = _app.emit("playback-state", ());
    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_store::Builder::default().build())
        .setup(|app| {
            let client = app.state::<jellyfin::JellyfinClient>();
            if let Ok(Some(server)) = storage::load_server(app.handle()) {
                client.set_server(Some(server));
            }
            if let Ok(dir) = app.path().app_data_dir() {
                let _ = db::init(&dir.join("cache.db"));
            }
            Ok(())
        })
        .manage(jellyfin::JellyfinClient::new())
        .manage(audio::AudioState::default())
        .invoke_handler(tauri::generate_handler![
            login,
            logout,
            get_library,
            get_image_url,
            get_settings,
            set_settings,
            get_server,
            get_playback_state,
            play_track,
            pause,
            resume,
            seek,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
