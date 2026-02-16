#[tauri::command]
pub fn get_platform() -> String {
    if cfg!(target_os = "windows") {
        return "windows".to_string();
    }
    if cfg!(target_os = "macos") {
        return "macos".to_string();
    }
    if cfg!(target_os = "linux") {
        return "linux".to_string();
    }
    if cfg!(target_os = "android") {
        return "android".to_string();
    }
    if cfg!(target_os = "ios") {
        return "ios".to_string();
    }
    "linux".to_string()
}
