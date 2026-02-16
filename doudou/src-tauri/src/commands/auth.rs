use crate::models::Session;

#[tauri::command]
pub async fn connect_server(
    provider: String,
    _url: String,
    username: String,
    _password: String,
) -> Result<Session, String> {
    Ok(Session {
        id: format!("{provider}-{username}"),
        server_id: provider.clone(),
        provider,
        token: "pending-provider-token".to_string(),
        user_id: None,
    })
}

#[tauri::command]
pub async fn disconnect_server(_session_id: String) -> Result<(), String> {
    Ok(())
}
