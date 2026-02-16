use uuid::Uuid;

use crate::local as local_service;
use crate::models::{Album, Artist, Playlist, SearchResults, Song};
use crate::state::ProviderSession;

pub struct LocalProvider;

impl LocalProvider {
    pub async fn authenticate(
        &self,
        _server_url: &str,
        username: &str,
        _password: &str,
    ) -> Result<ProviderSession, String> {
        Ok(ProviderSession {
            id: format!("local-{}", Uuid::new_v4()),
            provider: "local".to_string(),
            server_url: "local://".to_string(),
            username: username.to_string(),
            token: String::new(),
            salt: None,
        })
    }

    pub async fn scan_path(&self, path: &str) -> Result<Vec<Song>, String> {
        let files = local_service::scan(path);
        Ok(files
            .iter()
            .map(|file| {
                let metadata = local_service::read_metadata(file);
                local_service::song_from_file(file, &metadata)
            })
            .collect())
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
}
