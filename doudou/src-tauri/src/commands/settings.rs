use tauri::State;

use crate::models::Settings;
use crate::state::AppState;

#[tauri::command]
pub async fn get_settings(state: State<'_, AppState>) -> Result<Settings, String> {
    Ok(state.settings.read().clone())
}

#[tauri::command]
pub async fn update_settings(settings: Settings, state: State<'_, AppState>) -> Result<(), String> {
    *state.settings.write() = settings;
    Ok(())
}
