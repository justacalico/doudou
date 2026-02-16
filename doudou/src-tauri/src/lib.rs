mod commands;
mod models;
mod providers;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_http::init())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            commands::platform::get_platform,
            commands::auth::connect_server,
            commands::auth::disconnect_server,
            commands::library::fetch_albums,
            commands::library::fetch_artists,
            commands::library::fetch_album_details,
            commands::library::fetch_playlists,
            commands::library::search_library,
            commands::playback::play_song,
            commands::playback::pause,
            commands::playback::resume,
            commands::playback::next_song,
            commands::playback::previous_song,
            commands::playback::seek,
            commands::playback::set_volume,
            commands::playback::add_to_queue,
            commands::playback::reorder_queue,
            commands::playback::clear_queue,
            commands::playback::get_queue,
            commands::playback::enable_background_playback,
            commands::playback::update_now_playing_info,
            commands::downloads::download_for_offline,
            commands::downloads::get_downloads,
            commands::downloads::delete_download,
            commands::local::scan_local_folder,
            commands::local::read_audio_metadata,
            commands::local::fetch_online_artwork,
            commands::settings::get_settings,
            commands::settings::update_settings,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
