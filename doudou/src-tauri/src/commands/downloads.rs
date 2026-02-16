use crate::models::Download;

#[tauri::command]
pub async fn download_for_offline(
    _session_id: String,
    item_id: String,
    _item_type: String,
) -> Result<String, String> {
    Ok(format!("download-{item_id}"))
}

#[tauri::command]
pub async fn get_downloads() -> Result<Vec<Download>, String> {
    Ok(vec![])
}

#[tauri::command]
pub async fn delete_download(_download_id: String) -> Result<(), String> {
    Ok(())
}
