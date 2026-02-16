use std::collections::HashMap;

use chrono::Utc;
use reqwest::Client;
use serde_json::{Map, Value};
use uuid::Uuid;

use crate::models::{Album, Artist, Library, Playlist, SearchResults, Song};
use crate::state::ProviderSession;

pub struct SubsonicProvider {
    client: Client,
}

impl SubsonicProvider {
    pub fn new() -> Result<Self, String> {
        let mut builder = Client::builder().timeout(std::time::Duration::from_secs(30));
        if cfg!(target_os = "linux") {
            builder = builder.danger_accept_invalid_certs(true);
        }
        let client = builder.build().map_err(|e| e.to_string())?;
        Ok(Self { client })
    }

    fn normalized_server_url(server_url: &str) -> String {
        server_url.trim_end_matches('/').to_string()
    }

    fn token(password: &str, salt: &str) -> String {
        format!("{:x}", md5::compute(format!("{password}{salt}")))
    }

    fn base_params(username: &str, token: &str, salt: &str) -> HashMap<String, String> {
        HashMap::from([
            ("u".to_string(), username.to_string()),
            ("t".to_string(), token.to_string()),
            ("s".to_string(), salt.to_string()),
            ("v".to_string(), "1.16.1".to_string()),
            ("c".to_string(), "Doudou".to_string()),
            ("f".to_string(), "json".to_string()),
        ])
    }

    pub async fn authenticate(
        &self,
        server_url: &str,
        username: &str,
        password: &str,
    ) -> Result<ProviderSession, String> {
        let clean_url = Self::normalized_server_url(server_url);
        let salt = Utc::now().timestamp_millis().to_string();
        let token = Self::token(password, &salt);
        let params = Self::base_params(username, &token, &salt);

        let url = format!("{clean_url}/rest/ping");
        let body = self.get_json(&url, &params).await?;
        Self::require_ok(&body)?;

        Ok(ProviderSession {
            id: format!("subsonic-{}", Uuid::new_v4()),
            provider: "subsonic".to_string(),
            server_url: clean_url,
            username: username.to_string(),
            token,
            salt: Some(salt),
        })
    }

    fn session_params(session: &ProviderSession) -> HashMap<String, String> {
        Self::base_params(
            &session.username,
            &session.token,
            session.salt.as_deref().unwrap_or_default(),
        )
    }

    async fn get_json(
        &self,
        url: &str,
        params: &HashMap<String, String>,
    ) -> Result<Value, String> {
        let mut delay_ms = 150_u64;
        let mut last_error = String::new();
        for _attempt in 0..3 {
            match self
                .client
                .get(url)
                .query(params)
                .send()
                .await
                .map_err(|e| e.to_string())
                .and_then(|response| response.error_for_status().map_err(|e| e.to_string()))
            {
                Ok(response) => {
                    return response
                        .json::<Value>()
                        .await
                        .map_err(|e| format!("invalid subsonic payload: {e}"));
                }
                Err(error) => {
                    last_error = error;
                    tokio::time::sleep(std::time::Duration::from_millis(delay_ms)).await;
                    delay_ms *= 2;
                }
            }
        }
        Err(format!("subsonic request failed after retries: {last_error}"))
    }

    fn require_ok(value: &Value) -> Result<&Value, String> {
        let response = value
            .get("subsonic-response")
            .ok_or_else(|| "missing subsonic-response".to_string())?;
        if response
            .get("status")
            .and_then(Value::as_str)
            .unwrap_or_default()
            != "ok"
        {
            let message = response
                .get("error")
                .and_then(|e| e.get("message"))
                .and_then(Value::as_str)
                .unwrap_or("subsonic request failed");
            return Err(message.to_string());
        }
        Ok(response)
    }

    fn values_from_maybe_array(value: Option<&Value>) -> Vec<&Value> {
        match value {
            Some(Value::Array(items)) => items.iter().collect(),
            Some(item @ Value::Object(_)) => vec![item],
            _ => vec![],
        }
    }

    fn cover_art_url(
        &self,
        session: &ProviderSession,
        cover_art: Option<&str>,
        width: Option<u32>,
    ) -> Option<String> {
        let cover_art = cover_art?;
        let mut params = Self::session_params(session);
        params.insert("id".to_string(), cover_art.to_string());
        if let Some(w) = width {
            params.insert("size".to_string(), w.to_string());
        }
        let query = serde_urlencoded::to_string(params).ok()?;
        Some(format!("{}/rest/getCoverArt?{query}", session.server_url))
    }

    fn map_song(&self, session: &ProviderSession, song: &Value) -> Song {
        Song {
            id: song
                .get("id")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_string(),
            title: song
                .get("title")
                .and_then(Value::as_str)
                .unwrap_or("Unknown Title")
                .to_string(),
            album_id: song
                .get("albumId")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_string(),
            album_name: song
                .get("album")
                .and_then(Value::as_str)
                .unwrap_or("Unknown Album")
                .to_string(),
            artist_id: song
                .get("artistId")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_string(),
            artist_name: song
                .get("artist")
                .and_then(Value::as_str)
                .unwrap_or("Unknown Artist")
                .to_string(),
            duration: song.get("duration").and_then(Value::as_f64).unwrap_or(0.0) * 1000.0,
            track_number: song.get("track").and_then(Value::as_u64).map(|v| v as u32),
            disc_number: song.get("discNumber").and_then(Value::as_u64).map(|v| v as u32),
            year: song.get("year").and_then(Value::as_u64).map(|v| v as u32),
            genre: song.get("genre").and_then(Value::as_str).map(ToString::to_string),
            cover_art_url: self.cover_art_url(
                session,
                song.get("coverArt").and_then(Value::as_str),
                None,
            ),
            stream_url: None,
            is_favorite: song.get("starred").is_some(),
            is_downloaded: false,
            local_path: None,
            server_id: session.id.clone(),
        }
    }

    fn map_album(&self, session: &ProviderSession, album: &Value) -> Album {
        Album {
            id: album
                .get("id")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_string(),
            name: album
                .get("name")
                .and_then(Value::as_str)
                .unwrap_or("Unknown Album")
                .to_string(),
            artist_id: album
                .get("artistId")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_string(),
            artist_name: album
                .get("artist")
                .and_then(Value::as_str)
                .unwrap_or("Unknown Artist")
                .to_string(),
            year: album.get("year").and_then(Value::as_u64).map(|v| v as u32),
            song_count: album
                .get("songCount")
                .and_then(Value::as_u64)
                .unwrap_or_default() as u32,
            duration: album.get("duration").and_then(Value::as_f64).unwrap_or(0.0) * 1000.0,
            genre: album.get("genre").and_then(Value::as_str).map(ToString::to_string),
            cover_art_url: self.cover_art_url(
                session,
                album.get("coverArt").and_then(Value::as_str),
                None,
            ),
            server_id: session.id.clone(),
        }
    }

    fn map_artist(&self, session: &ProviderSession, artist: &Value) -> Artist {
        Artist {
            id: artist
                .get("id")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_string(),
            name: artist
                .get("name")
                .and_then(Value::as_str)
                .unwrap_or("Unknown Artist")
                .to_string(),
            album_count: artist
                .get("albumCount")
                .and_then(Value::as_u64)
                .unwrap_or_default() as u32,
            cover_art_url: self.cover_art_url(
                session,
                artist.get("coverArt").and_then(Value::as_str),
                None,
            ),
            server_id: session.id.clone(),
        }
    }

    fn map_playlist(&self, session: &ProviderSession, playlist: &Value) -> Playlist {
        Playlist {
            id: playlist
                .get("id")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_string(),
            name: playlist
                .get("name")
                .and_then(Value::as_str)
                .unwrap_or("Untitled Playlist")
                .to_string(),
            song_count: playlist
                .get("songCount")
                .and_then(Value::as_u64)
                .unwrap_or_default() as u32,
            duration: playlist.get("duration").and_then(Value::as_f64).unwrap_or(0.0) * 1000.0,
            cover_art_url: self.cover_art_url(
                session,
                playlist.get("coverArt").and_then(Value::as_str),
                None,
            ),
            is_public: false,
            server_id: session.id.clone(),
        }
    }

    pub async fn get_libraries(&self, session: &ProviderSession) -> Result<Vec<Library>, String> {
        let params = Self::session_params(session);
        let url = format!("{}/rest/getMusicFolders", session.server_url);
        let body = self.get_json(&url, &params).await?;
        let response = Self::require_ok(&body)?;
        let folders = Self::values_from_maybe_array(
            response
                .get("musicFolders")
                .and_then(|v| v.get("musicFolder")),
        );
        Ok(folders
            .into_iter()
            .map(|folder| Library {
                id: folder
                    .get("id")
                    .map(|v| {
                        if let Some(s) = v.as_str() {
                            s.to_string()
                        } else {
                            v.to_string().trim_matches('"').to_string()
                        }
                    })
                    .unwrap_or_default(),
                name: folder
                    .get("name")
                    .and_then(Value::as_str)
                    .unwrap_or("Library")
                    .to_string(),
                collection_type: "music".to_string(),
                image_url: None,
            })
            .collect())
    }

    pub async fn get_albums(
        &self,
        session: &ProviderSession,
        sort: Option<String>,
        filter: Option<String>,
    ) -> Result<Vec<Album>, String> {
        let mut params = Self::session_params(session);
        params.insert(
            "type".to_string(),
            sort.unwrap_or_else(|| "alphabeticalByName".to_string()),
        );
        if let Some(music_folder_id) = filter {
            params.insert("musicFolderId".to_string(), music_folder_id);
        }

        let url = format!("{}/rest/getAlbumList2", session.server_url);
        let body = self.get_json(&url, &params).await?;
        let response = Self::require_ok(&body)?;
        let albums = Self::values_from_maybe_array(
            response.get("albumList2").and_then(|node| node.get("album")),
        );
        Ok(albums
            .iter()
            .map(|album| self.map_album(session, album))
            .collect())
    }

    pub async fn get_artists(&self, session: &ProviderSession) -> Result<Vec<Artist>, String> {
        let params = Self::session_params(session);
        let url = format!("{}/rest/getArtists", session.server_url);
        let body = self.get_json(&url, &params).await?;
        let response = Self::require_ok(&body)?;
        let indexes =
            Self::values_from_maybe_array(response.get("artists").and_then(|node| node.get("index")));
        let mut artists = Vec::new();
        for index in indexes {
            let artist_nodes = Self::values_from_maybe_array(index.get("artist"));
            for artist in artist_nodes {
                artists.push(self.map_artist(session, artist));
            }
        }
        Ok(artists)
    }

    pub async fn get_album_songs(
        &self,
        session: &ProviderSession,
        album_id: String,
    ) -> Result<Vec<Song>, String> {
        let mut params = Self::session_params(session);
        params.insert("id".to_string(), album_id);
        let url = format!("{}/rest/getAlbum", session.server_url);
        let body = self.get_json(&url, &params).await?;
        let response = Self::require_ok(&body)?;
        let songs = Self::values_from_maybe_array(response.get("album").and_then(|node| node.get("song")));
        Ok(songs
            .iter()
            .map(|song| self.map_song(session, song))
            .collect())
    }

    pub async fn get_random_songs(
        &self,
        session: &ProviderSession,
        size: Option<u32>,
    ) -> Result<Vec<Song>, String> {
        let mut params = Self::session_params(session);
        params.insert("size".to_string(), size.unwrap_or(50).to_string());
        let url = format!("{}/rest/getRandomSongs", session.server_url);
        let body = self.get_json(&url, &params).await?;
        let response = Self::require_ok(&body)?;
        let songs =
            Self::values_from_maybe_array(response.get("randomSongs").and_then(|node| node.get("song")));
        Ok(songs
            .iter()
            .map(|song| self.map_song(session, song))
            .collect())
    }

    pub async fn get_playlists(&self, session: &ProviderSession) -> Result<Vec<Playlist>, String> {
        let params = Self::session_params(session);
        let url = format!("{}/rest/getPlaylists", session.server_url);
        let body = self.get_json(&url, &params).await?;
        let response = Self::require_ok(&body)?;
        let playlists =
            Self::values_from_maybe_array(response.get("playlists").and_then(|node| node.get("playlist")));
        Ok(playlists
            .iter()
            .map(|playlist| self.map_playlist(session, playlist))
            .collect())
    }

    pub async fn get_playlist_tracks(
        &self,
        session: &ProviderSession,
        playlist_id: String,
    ) -> Result<Vec<Song>, String> {
        let mut params = Self::session_params(session);
        params.insert("id".to_string(), playlist_id);
        let url = format!("{}/rest/getPlaylist", session.server_url);
        let body = self.get_json(&url, &params).await?;
        let response = Self::require_ok(&body)?;
        let tracks = Self::values_from_maybe_array(response.get("playlist").and_then(|node| node.get("entry")));
        Ok(tracks
            .iter()
            .map(|song| self.map_song(session, song))
            .collect())
    }

    pub fn get_stream_url(&self, session: &ProviderSession, song_id: &str) -> String {
        let mut params = Self::session_params(session);
        params.insert("id".to_string(), song_id.to_string());
        let query = serde_urlencoded::to_string(params).unwrap_or_default();
        format!("{}/rest/stream?{query}", session.server_url)
    }

    pub fn get_download_url(&self, session: &ProviderSession, song_id: &str) -> String {
        let mut params = Self::session_params(session);
        params.insert("id".to_string(), song_id.to_string());
        let query = serde_urlencoded::to_string(params).unwrap_or_default();
        format!("{}/rest/download?{query}", session.server_url)
    }

    pub async fn search(
        &self,
        session: &ProviderSession,
        query: String,
    ) -> Result<SearchResults, String> {
        let mut params = Self::session_params(session);
        params.insert("query".to_string(), query);
        params.insert("artistCount".to_string(), "100".to_string());
        params.insert("albumCount".to_string(), "100".to_string());
        params.insert("songCount".to_string(), "100".to_string());

        let url = format!("{}/rest/search3", session.server_url);
        let body = self.get_json(&url, &params).await?;
        let response = Self::require_ok(&body)?;
        let search_result = response
            .get("searchResult3")
            .and_then(Value::as_object)
            .cloned()
            .unwrap_or(Map::new());

        let albums = Self::values_from_maybe_array(search_result.get("album"))
            .iter()
            .map(|album| self.map_album(session, album))
            .collect();
        let artists = Self::values_from_maybe_array(search_result.get("artist"))
            .iter()
            .map(|artist| self.map_artist(session, artist))
            .collect();
        let songs = Self::values_from_maybe_array(search_result.get("song"))
            .iter()
            .map(|song| self.map_song(session, song))
            .collect();

        Ok(SearchResults {
            albums,
            artists,
            songs,
            playlists: vec![],
        })
    }

    pub async fn toggle_favorite(
        &self,
        session: &ProviderSession,
        item_id: String,
        is_favorite: bool,
    ) -> Result<(), String> {
        let mut params = Self::session_params(session);
        params.insert("id".to_string(), item_id);
        let endpoint = if is_favorite { "unstar" } else { "star" };
        let url = format!("{}/rest/{endpoint}", session.server_url);
        let body = self.get_json(&url, &params).await?;
        let _ = Self::require_ok(&body)?;
        Ok(())
    }

    pub async fn create_playlist(
        &self,
        session: &ProviderSession,
        name: String,
    ) -> Result<Option<Playlist>, String> {
        let mut params = Self::session_params(session);
        params.insert("name".to_string(), name.clone());
        let url = format!("{}/rest/createPlaylist", session.server_url);
        let body = self.get_json(&url, &params).await?;
        let response = Self::require_ok(&body)?;
        let playlist = response.get("playlist");
        Ok(playlist.map(|value| self.map_playlist(session, value)).or_else(|| {
            Some(Playlist {
                id: String::new(),
                name,
                song_count: 0,
                duration: 0.0,
                cover_art_url: None,
                is_public: false,
                server_id: session.id.clone(),
            })
        }))
    }

    pub async fn add_to_playlist(
        &self,
        session: &ProviderSession,
        playlist_id: String,
        song_id: String,
    ) -> Result<(), String> {
        let mut params = Self::session_params(session);
        params.insert("playlistId".to_string(), playlist_id);
        params.insert("songIdToAdd".to_string(), song_id);
        let url = format!("{}/rest/updatePlaylist", session.server_url);
        let body = self.get_json(&url, &params).await?;
        let _ = Self::require_ok(&body)?;
        Ok(())
    }

    pub async fn remove_track_from_playlist(
        &self,
        session: &ProviderSession,
        playlist_id: String,
        track_index: usize,
    ) -> Result<(), String> {
        let mut params = Self::session_params(session);
        params.insert("playlistId".to_string(), playlist_id);
        params.insert("songIndexToRemove".to_string(), track_index.to_string());
        let url = format!("{}/rest/updatePlaylist", session.server_url);
        let body = self.get_json(&url, &params).await?;
        let _ = Self::require_ok(&body)?;
        Ok(())
    }

    pub async fn rename_playlist(
        &self,
        session: &ProviderSession,
        playlist_id: String,
        name: String,
    ) -> Result<(), String> {
        let mut params = Self::session_params(session);
        params.insert("playlistId".to_string(), playlist_id);
        params.insert("name".to_string(), name);
        let url = format!("{}/rest/updatePlaylist", session.server_url);
        let body = self.get_json(&url, &params).await?;
        let _ = Self::require_ok(&body)?;
        Ok(())
    }

    pub async fn remove_playlist(
        &self,
        session: &ProviderSession,
        playlist_id: String,
    ) -> Result<(), String> {
        let mut params = Self::session_params(session);
        params.insert("id".to_string(), playlist_id);
        let url = format!("{}/rest/deletePlaylist", session.server_url);
        let body = self.get_json(&url, &params).await?;
        let _ = Self::require_ok(&body)?;
        Ok(())
    }

    pub async fn get_all_tracks(&self, session: &ProviderSession) -> Result<Vec<Song>, String> {
        let mut all = Vec::new();
        let mut offset = 0_u32;
        let page_size = 500_u32;

        loop {
            let mut params = Self::session_params(session);
            params.insert("query".to_string(), String::new());
            params.insert("songCount".to_string(), page_size.to_string());
            params.insert("songOffset".to_string(), offset.to_string());
            params.insert("artistCount".to_string(), "0".to_string());
            params.insert("albumCount".to_string(), "0".to_string());

            let url = format!("{}/rest/search3", session.server_url);
            let body = self.get_json(&url, &params).await?;
            let response = Self::require_ok(&body)?;
            let page = Self::values_from_maybe_array(
                response
                    .get("searchResult3")
                    .and_then(|node| node.get("song")),
            );
            if page.is_empty() {
                break;
            }
            all.extend(page.iter().map(|song| self.map_song(session, song)));
            if page.len() < page_size as usize {
                break;
            }
            offset += page_size;
        }
        Ok(all)
    }

    pub async fn get_starred_tracks(&self, session: &ProviderSession) -> Result<Vec<Song>, String> {
        let params = Self::session_params(session);
        let url = format!("{}/rest/getStarred2", session.server_url);
        let body = self.get_json(&url, &params).await?;
        let response = Self::require_ok(&body)?;
        let songs =
            Self::values_from_maybe_array(response.get("starred2").and_then(|node| node.get("song")));
        Ok(songs
            .iter()
            .map(|song| self.map_song(session, song))
            .collect())
    }
}
