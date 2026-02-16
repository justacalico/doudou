use crate::models::Settings;

#[tauri::command]
pub async fn get_settings() -> Result<Settings, String> {
    Ok(Settings {
        theme: "dark".to_string(),
        accent_color: "#4f8bff".to_string(),
        crossfade_seconds: 0,
        gapless_enabled: true,
        normalize_audio: false,
        scrobbling_enabled: false,
        download_path: None,
    })
}

#[tauri::command]
pub async fn update_settings(_settings: Settings) -> Result<(), String> {
    Ok(())
}
