use crate::models::{Album, Artist, Playlist, SearchResults, Session, Song};
use crate::providers::{Credentials, MediaProvider, QueryParams};

#[derive(Default)]
pub struct LocalProvider;

impl MediaProvider for LocalProvider {
    async fn authenticate(
        &self,
        _server_url: String,
        credentials: Credentials,
    ) -> Result<Session, String> {
        Ok(Session {
            id: format!("local-{}", credentials.username),
            server_id: "local".to_string(),
            provider: "local".to_string(),
            token: String::new(),
            user_id: None,
        })
    }

    async fn get_albums(
        &self,
        _session: &Session,
        _params: QueryParams,
    ) -> Result<Vec<Album>, String> {
        Ok(vec![])
    }

    async fn get_artists(&self, _session: &Session) -> Result<Vec<Artist>, String> {
        Ok(vec![])
    }

    async fn get_songs(&self, _session: &Session, _album_id: String) -> Result<Vec<Song>, String> {
        Ok(vec![])
    }

    async fn get_playlists(&self, _session: &Session) -> Result<Vec<Playlist>, String> {
        Ok(vec![])
    }

    async fn search(&self, _session: &Session, _query: String) -> Result<SearchResults, String> {
        Ok(SearchResults {
            albums: vec![],
            artists: vec![],
            songs: vec![],
            playlists: vec![],
        })
    }
}
