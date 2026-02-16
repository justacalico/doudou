use tauri::State;

use crate::models::Session;
use crate::providers::jellyfin::JellyfinProvider;
use crate::providers::local::LocalProvider;
use crate::providers::plex::PlexProvider;
use crate::providers::subsonic::SubsonicProvider;
use crate::providers::ProviderKind;
use crate::state::AppState;

#[tauri::command]
pub async fn connect_server(
    provider: String,
    url: String,
    username: String,
    password: String,
    state: State<'_, AppState>,
) -> Result<Session, String> {
    let provider_kind = ProviderKind::parse(&provider)?;
    let provider_session = match provider_kind {
        ProviderKind::Subsonic => {
            let subsonic = SubsonicProvider::new()?;
            subsonic.authenticate(&url, &username, &password).await?
        }
        ProviderKind::Jellyfin => JellyfinProvider::new()
            .authenticate(&url, &username, &password)
            .await?,
        ProviderKind::Plex => PlexProvider::new()
            .authenticate(&url, &username, &password)
            .await?,
        ProviderKind::Local => {
            LocalProvider
                .authenticate(&url, &username, &password)
                .await?
        }
    };

    let response = Session {
        id: provider_session.id.clone(),
        server_id: provider_session.id.clone(),
        provider: provider_session.provider.clone(),
        token: provider_session.token.clone(),
        user_id: Some(provider_session.username.clone()),
    };
    state
        .sessions
        .write()
        .insert(provider_session.id.clone(), provider_session);
    Ok(response)
}

#[tauri::command]
pub async fn disconnect_server(session_id: String, state: State<'_, AppState>) -> Result<(), String> {
    state.sessions.write().remove(&session_id);
    Ok(())
}
