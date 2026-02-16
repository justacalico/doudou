#![allow(dead_code)]

use crate::models::{Album, Artist, Playlist, SearchResults, Session, Song};

pub mod jellyfin;
pub mod local;
pub mod plex;
pub mod subsonic;

#[derive(Debug, Clone)]
pub struct Credentials {
    pub username: String,
    pub password: String,
}

#[derive(Debug, Clone)]
pub struct QueryParams {
    pub sort: Option<String>,
    pub filter: Option<String>,
}

pub trait MediaProvider {
    fn authenticate(
        &self,
        server_url: String,
        credentials: Credentials,
    ) -> impl std::future::Future<Output = Result<Session, String>> + Send;

    fn get_albums(
        &self,
        session: &Session,
        params: QueryParams,
    ) -> impl std::future::Future<Output = Result<Vec<Album>, String>> + Send;

    fn get_artists(
        &self,
        session: &Session,
    ) -> impl std::future::Future<Output = Result<Vec<Artist>, String>> + Send;

    fn get_songs(
        &self,
        session: &Session,
        album_id: String,
    ) -> impl std::future::Future<Output = Result<Vec<Song>, String>> + Send;

    fn get_playlists(
        &self,
        session: &Session,
    ) -> impl std::future::Future<Output = Result<Vec<Playlist>, String>> + Send;

    fn search(
        &self,
        session: &Session,
        query: String,
    ) -> impl std::future::Future<Output = Result<SearchResults, String>> + Send;
}
