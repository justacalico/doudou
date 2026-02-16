//! Persist server config and settings to app data dir.

use doudou_core::JellyfinServer;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use tauri::Manager;

const SERVER_FILE: &str = "server.json";
const SETTINGS_FILE: &str = "settings.json";

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct AppSettings {
    pub theme_mode: Option<String>, // "light" | "dark" | "system"
    pub accent_color: Option<String>,
    pub locale: Option<String>,
}

fn app_data_dir(app: &tauri::AppHandle) -> Result<PathBuf, String> {
    app.path()
        .app_data_dir()
        .map_err(|e| e.to_string())
}

fn ensure_app_data_dir(app: &tauri::AppHandle) -> Result<PathBuf, String> {
    let dir = app_data_dir(app)?;
    fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    Ok(dir)
}

pub fn load_server(app: &tauri::AppHandle) -> Result<Option<JellyfinServer>, String> {
    let dir = app_data_dir(app)?;
    let path = dir.join(SERVER_FILE);
    if !path.exists() {
        return Ok(None);
    }
    let s = fs::read_to_string(&path).map_err(|e| e.to_string())?;
    let server: JellyfinServer = serde_json::from_str(&s).map_err(|e| e.to_string())?;
    Ok(Some(server))
}

pub fn save_server(app: &tauri::AppHandle, server: &JellyfinServer) -> Result<(), String> {
    let dir = ensure_app_data_dir(app)?;
    let path = dir.join(SERVER_FILE);
    let s = serde_json::to_string_pretty(server).map_err(|e| e.to_string())?;
    fs::write(path, s).map_err(|e| e.to_string())
}

pub fn clear_server(app: &tauri::AppHandle) -> Result<(), String> {
    let dir = app_data_dir(app)?;
    let path = dir.join(SERVER_FILE);
    if path.exists() {
        fs::remove_file(path).map_err(|e| e.to_string())?;
    }
    Ok(())
}

pub fn load_settings(app: &tauri::AppHandle) -> Result<AppSettings, String> {
    let dir = app_data_dir(app)?;
    let path = dir.join(SETTINGS_FILE);
    if !path.exists() {
        return Ok(AppSettings::default());
    }
    let s = fs::read_to_string(&path).map_err(|e| e.to_string())?;
    serde_json::from_str(&s).map_err(|e| e.to_string())
}

pub fn save_settings(app: &tauri::AppHandle, settings: &AppSettings) -> Result<(), String> {
    let dir = ensure_app_data_dir(app)?;
    let path = dir.join(SETTINGS_FILE);
    let s = serde_json::to_string_pretty(settings).map_err(|e| e.to_string())?;
    fs::write(path, s).map_err(|e| e.to_string())
}
