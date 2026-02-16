use std::path::{Path, PathBuf};

use chrono::Utc;
use tokio::io::AsyncWriteExt;
use tokio::fs;
use uuid::Uuid;

use crate::models::Download;

pub fn downloads_dir(base: &Path) -> PathBuf {
    base.join("downloads")
}

pub async fn ensure_download_dirs(base: &Path) -> Result<(), String> {
    let dir = downloads_dir(base);
    fs::create_dir_all(dir.join("images"))
        .await
        .map_err(|e| e.to_string())
}

pub async fn persist_downloads(base: &Path, downloads: &[Download]) -> Result<(), String> {
    let file_path = downloads_dir(base).join("downloads.json");
    let mut file = fs::File::create(file_path)
        .await
        .map_err(|e| e.to_string())?;
    let payload = serde_json::to_vec_pretty(downloads).map_err(|e| e.to_string())?;
    file.write_all(&payload).await.map_err(|e| e.to_string())
}

pub async fn load_downloads(base: &Path) -> Result<Vec<Download>, String> {
    let file_path = downloads_dir(base).join("downloads.json");
    if !file_path.exists() {
        return Ok(vec![]);
    }
    let payload = fs::read(file_path).await.map_err(|e| e.to_string())?;
    serde_json::from_slice::<Vec<Download>>(&payload).map_err(|e| e.to_string())
}

pub fn build_download_record(
    item_id: String,
    item_type: String,
    server_id: String,
    local_path: Option<String>,
) -> Download {
    Download {
        id: format!("dl-{}", Uuid::new_v4()),
        item_id,
        item_type,
        server_id,
        progress: 100.0,
        status: "completed".to_string(),
        local_path,
        created_at: Utc::now().timestamp_millis(),
    }
}
