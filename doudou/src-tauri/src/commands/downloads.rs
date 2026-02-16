use std::path::PathBuf;

use tauri::State;
use tokio::fs;

use crate::downloads::{
    build_download_record, downloads_dir, ensure_download_dirs, load_downloads, persist_downloads,
};
use crate::models::Download;
use crate::providers::subsonic::SubsonicProvider;
use crate::providers::ProviderKind;
use crate::state::AppState;

#[tauri::command]
pub async fn download_for_offline(
    session_id: String,
    item_id: String,
    item_type: String,
    state: State<'_, AppState>,
) -> Result<String, String> {
    let session = state
        .sessions
        .read()
        .get(&session_id)
        .cloned()
        .ok_or_else(|| "session not found".to_string())?;

    let app_data_dir = state
        .app_data_dir
        .read()
        .clone()
        .ok_or_else(|| "app data directory is not initialized".to_string())?;
    ensure_download_dirs(&app_data_dir).await?;

    let output_path = downloads_dir(&app_data_dir).join(format!("{item_id}.audio"));
    if ProviderKind::parse(&session.provider)? == ProviderKind::Subsonic {
        let provider = SubsonicProvider::new()?;
        let download_url = provider.get_download_url(&session, &item_id);
        let bytes = reqwest::get(download_url)
            .await
            .map_err(|e| e.to_string())?
            .bytes()
            .await
            .map_err(|e| e.to_string())?;
        fs::write(&output_path, bytes)
            .await
            .map_err(|e| e.to_string())?;
    }

    let record = build_download_record(
        item_id.clone(),
        item_type,
        session_id,
        Some(output_path.to_string_lossy().to_string()),
    );
    let id = record.id.clone();
    let snapshot = {
        let mut downloads = state.downloads.write();
        downloads.insert(id.clone(), record);
        app_data_downloads_snapshot(&downloads)
    };
    let _ = persist_downloads(&app_data_dir, &snapshot).await;
    Ok(id)
}

#[tauri::command]
pub async fn get_downloads(state: State<'_, AppState>) -> Result<Vec<Download>, String> {
    let app_data_dir = state
        .app_data_dir
        .read()
        .clone()
        .ok_or_else(|| "app data directory is not initialized".to_string())?;

    if state.downloads.read().is_empty() {
        let persisted = load_downloads(&app_data_dir).await.unwrap_or_default();
        if !persisted.is_empty() {
            let mut cache = state.downloads.write();
            for item in persisted {
                cache.insert(item.id.clone(), item);
            }
        }
    }
    Ok(state.downloads.read().values().cloned().collect())
}

#[tauri::command]
pub async fn delete_download(download_id: String, state: State<'_, AppState>) -> Result<(), String> {
    let app_data_dir = state
        .app_data_dir
        .read()
        .clone()
        .ok_or_else(|| "app data directory is not initialized".to_string())?;
    let removed = state.downloads.write().remove(&download_id);
    if let Some(download) = removed {
        if let Some(local_path) = download.local_path {
            let path = PathBuf::from(local_path);
            if path.exists() {
                let _ = fs::remove_file(path).await;
            }
        }
    }
    let snapshot = state.downloads.read().values().cloned().collect::<Vec<_>>();
    let _ = persist_downloads(&app_data_dir, &snapshot).await;
    Ok(())
}

fn app_data_downloads_snapshot(
    downloads: &std::collections::HashMap<String, Download>,
) -> Vec<Download> {
    let mut snapshot = downloads.values().cloned().collect::<Vec<_>>();
    snapshot.sort_by_key(|entry| entry.created_at);
    snapshot
}
