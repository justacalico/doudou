use crate::models::{Album, Artist, Playlist, SearchResults, Session, Song};
use crate::providers::{Credentials, MediaProvider, QueryParams};

#[derive(Default)]
pub struct SubsonicProvider;

impl MediaProvider for SubsonicProvider {
    async fn authenticate(
        &self,
        _server_url: String,
        _credentials: Credentials,
    ) -> Result<Session, String> {
        Err("Subsonic provider is not implemented yet".to_string())
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
