use reqwest::Client;
use uuid::Uuid;

use crate::models::{Album, Artist, Playlist, SearchResults, Song};
use crate::providers::ProviderAdapter;
use crate::state::ProviderSession;

pub struct JellyfinProvider {
    client: Client,
}

impl ProviderAdapter for JellyfinProvider {}

impl JellyfinProvider {
    pub fn new() -> Self {
        Self {
            client: Client::new(),
        }
    }

    pub async fn authenticate(
        &self,
        server_url: &str,
        username: &str,
        password: &str,
    ) -> Result<ProviderSession, String> {
        let clean = Self::normalize_url(server_url);
        let auth_url = format!("{clean}/Users/AuthenticateByName");
        let response = self
            .client
            .post(auth_url)
            .json(&serde_json::json!({
                "Username": username,
                "Pw": password
            }))
            .send()
            .await
            .map_err(|e| e.to_string())?;

        if !response.status().is_success() {
            return Err("jellyfin authentication failed".to_string());
        }
        Ok(ProviderSession {
            id: format!("jellyfin-{}", Uuid::new_v4()),
            provider: "jellyfin".to_string(),
            server_url: clean,
            username: username.to_string(),
            token: String::new(),
            salt: None,
        })
    }

    pub async fn get_albums(&self, _session: &ProviderSession) -> Result<Vec<Album>, String> {
        Ok(vec![])
    }

    pub async fn get_artists(&self, _session: &ProviderSession) -> Result<Vec<Artist>, String> {
        Ok(vec![])
    }

    pub async fn get_playlists(&self, _session: &ProviderSession) -> Result<Vec<Playlist>, String> {
        Ok(vec![])
    }

    pub async fn search(
        &self,
        _session: &ProviderSession,
        _query: String,
    ) -> Result<SearchResults, String> {
        Ok(SearchResults {
            albums: vec![],
            artists: vec![],
            songs: vec![],
            playlists: vec![],
        })
    }

    pub async fn get_tracks(&self, _session: &ProviderSession) -> Result<Vec<Song>, String> {
        Ok(vec![])
    }
}
