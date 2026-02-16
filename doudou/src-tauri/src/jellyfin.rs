//! Jellyfin API client; returns doudou_core types.

use doudou_core::{
    Album, Artist, JellyfinServer, Library, Playlist, Track,
};
use reqwest::Client;
use serde::Deserialize;
use std::sync::Mutex;

/// Jellyfin API response item (raw).
#[derive(Debug, Deserialize)]
struct JellyfinItem {
    #[serde(rename = "Id")]
    id: String,
    #[serde(rename = "Name")]
    name: String,
    #[serde(rename = "AlbumArtist")]
    album_artist: Option<String>,
    #[serde(rename = "Album")]
    album: Option<String>,
    #[serde(rename = "Artists")]
    artists: Option<Vec<String>>,
    #[serde(rename = "AlbumId")]
    album_id: Option<String>,
    #[serde(rename = "PlaylistItemId")]
    playlist_item_id: Option<String>,
    #[serde(rename = "RunTimeTicks")]
    run_time_ticks: Option<i64>,
    #[serde(rename = "IndexNumber")]
    index_number: Option<u32>,
    #[serde(rename = "ImageTags")]
    image_tags: Option<serde_json::Value>,
    #[serde(rename = "UserData")]
    user_data: Option<UserData>,
    #[serde(rename = "ProductionYear")]
    production_year: Option<i32>,
    #[serde(rename = "DateCreated")]
    date_created: Option<String>,
    #[serde(rename = "CollectionType")]
    collection_type: Option<String>,
    #[serde(rename = "ChildCount")]
    child_count: Option<u32>,
}

#[derive(Debug, Deserialize)]
struct UserData {
    #[serde(rename = "IsFavorite")]
    is_favorite: Option<bool>,
    #[serde(rename = "PlayCount")]
    play_count: Option<u32>,
}

#[derive(Debug, Deserialize)]
struct ItemsResponse {
    #[serde(rename = "Items")]
    items: Option<Vec<JellyfinItem>>,
}

#[derive(Debug, Deserialize)]
struct AuthResponse {
    #[serde(rename = "AccessToken")]
    access_token: Option<String>,
    #[serde(rename = "User")]
    user: Option<AuthUser>,
}

#[derive(Debug, Deserialize)]
struct AuthUser {
    #[serde(rename = "Id")]
    id: String,
    #[serde(rename = "Name")]
    name: Option<String>,
}

const APP_VERSION: &str = env!("CARGO_PKG_VERSION");

fn has_primary_image(tags: &Option<serde_json::Value>) -> bool {
    tags.as_ref()
        .and_then(|t| t.get("Primary"))
        .is_some()
}

fn item_image_id(id: &str, image_tags: &Option<serde_json::Value>) -> Option<String> {
    if has_primary_image(image_tags) {
        Some(id.to_string())
    } else {
        None
    }
}

fn duration_ticks_to_ms(ticks: Option<i64>) -> Option<u64> {
    ticks.map(|t| (t / 10_000).max(0) as u64)
}

pub struct JellyfinClient {
    client: Client,
    server: Mutex<Option<JellyfinServer>>,
}

impl JellyfinClient {
    pub fn new() -> Self {
        Self {
            client: Client::builder()
                .connect_timeout(std::time::Duration::from_secs(10))
                .timeout(std::time::Duration::from_secs(30))
                .build()
                .expect("reqwest client"),
            server: Mutex::new(None),
        }
    }

    fn base_url(server: &JellyfinServer) -> String {
        server
            .server_url
            .trim_end_matches('/')
            .to_string()
    }

    fn token(server: &JellyfinServer) -> Option<&str> {
        server.access_token.as_deref()
    }

    pub fn set_server(&self, server: Option<JellyfinServer>) {
        *self.server.lock().unwrap() = server;
    }

    pub fn get_server(&self) -> Option<JellyfinServer> {
        self.server.lock().unwrap().clone()
    }

    pub async fn authenticate(
        &self,
        server_url: &str,
        username: &str,
        password: &str,
    ) -> Result<JellyfinServer, String> {
        let url = format!(
            "{}/Users/AuthenticateByName",
            server_url.trim_end_matches('/')
        );
        let body = serde_json::json!({
            "Username": username,
            "Pw": password
        });
        let res = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header(
                "X-Emby-Authorization",
                format!(
                    "MediaBrowser Client=\"Doudou\", Device=\"Tauri\", DeviceId=\"doudou-tauri\", Version=\"{}\"",
                    APP_VERSION
                ),
            )
            .json(&body)
            .send()
            .await
            .map_err(|e| e.to_string())?;

        if !res.status().is_success() {
            let status = res.status();
            let text = res.text().await.unwrap_or_default();
            return Err(format!("{}: {}", status, text));
        }

        let auth: AuthResponse = res.json().await.map_err(|e| e.to_string())?;
        let token = auth.access_token.ok_or("No access token")?;
        let user_id = auth.user.as_ref().ok_or("No user")?.id.clone();
        let user_name = auth
            .user
            .as_ref()
            .and_then(|u| u.name.clone())
            .unwrap_or_else(|| username.to_string());

        let server = JellyfinServer {
            server_url: server_url.to_string(),
            api_key: None,
            user_id: Some(user_id.clone()),
            access_token: Some(token),
            username: Some(user_name),
            password: Some(password.to_string()),
        };
        self.set_server(Some(server.clone()));
        Ok(server)
    }

    pub async fn get_albums(&self) -> Result<Vec<Album>, String> {
        let server = self.get_server().ok_or("Not logged in")?;
        let url = format!(
            "{}/Users/{}/Items",
            Self::base_url(&server),
            server.user_id.as_deref().unwrap_or("")
        );
        let params: Vec<(&str, &str)> = vec![
            ("IncludeItemTypes", "MusicAlbum"),
            ("Recursive", "true"),
            ("Fields", "PrimaryImageAspectRatio,ImageTags,DateCreated"),
            ("SortBy", "DateCreated"),
            ("SortOrder", "Descending"),
        ];
        let res = self.get_with_params(&url, &server, &params).await?;
        let data: ItemsResponse = serde_json::from_value(res).map_err(|e| e.to_string())?;
        let items = data.items.unwrap_or_default();
        let albums = items
            .into_iter()
            .map(|i| {
                let image_url = item_image_id(&i.id, &i.image_tags);
                Album {
                    id: i.id,
                    name: i.name,
                    artist_name: i.album_artist,
                    image_url,
                    year: i.production_year,
                    date_created: i.date_created,
                    is_favorite: i.user_data.as_ref().and_then(|u| u.is_favorite).unwrap_or(false),
                }
            })
            .collect();
        Ok(albums)
    }

    pub async fn get_artists(&self) -> Result<Vec<Artist>, String> {
        let server = self.get_server().ok_or("Not logged in")?;
        let url = format!("{}/Artists", Self::base_url(&server));
        let user_id = server.user_id.as_deref().unwrap_or("");
        let params: Vec<(&str, &str)> = vec![
            ("userId", user_id),
            ("Fields", "PrimaryImageAspectRatio,ImageTags"),
            ("SortBy", "SortName"),
            ("SortOrder", "Ascending"),
        ];
        let res = self.get_with_params(&url, &server, &params).await?;
        let data: ItemsResponse = serde_json::from_value(res).map_err(|e| e.to_string())?;
        let items = data.items.unwrap_or_default();
        let artists = items
            .into_iter()
            .map(|i| {
                let image_url = item_image_id(&i.id, &i.image_tags);
                Artist {
                    id: i.id,
                    name: i.name,
                    image_url,
                }
            })
            .collect();
        Ok(artists)
    }

    pub async fn get_tracks(&self, parent_id: Option<&str>) -> Result<Vec<Track>, String> {
        let server = self.get_server().ok_or("Not logged in")?;
        let url = format!(
            "{}/Users/{}/Items",
            Self::base_url(&server),
            server.user_id.as_deref().unwrap_or("")
        );
        let mut params: Vec<(&str, &str)> = vec![
            ("IncludeItemTypes", "Audio"),
            ("Recursive", "true"),
            (
                "Fields",
                "PrimaryImageAspectRatio,ImageTags,Artists,Album,AlbumId,IndexNumber,RunTimeTicks,UserData",
            ),
            ("SortBy", "Album,IndexNumber"),
            ("SortOrder", "Ascending"),
        ];
        if let Some(pid) = parent_id {
            params.push(("ParentId", pid));
        }
        let res = self.get_with_params(&url, &server, &params).await?;
        let data: ItemsResponse = serde_json::from_value(res).map_err(|e| e.to_string())?;
        let items = data.items.unwrap_or_default();
        let tracks = items
            .into_iter()
            .map(|i| {
                let artist_name = i
                    .artists
                    .as_ref()
                    .map(|a| a.join(", "))
                    .unwrap_or_default();
                let img = item_image_id(&i.id, &i.image_tags).or(i.album_id.clone());
                Track {
                    id: i.id,
                    name: i.name,
                    album_name: i.album,
                    artist_name: if artist_name.is_empty() {
                        None
                    } else {
                        Some(artist_name)
                    },
                    album_id: i.album_id,
                    playlist_item_id: i.playlist_item_id,
                    duration: duration_ticks_to_ms(i.run_time_ticks),
                    track_number: i.index_number,
                    image_url: img,
                    is_favorite: i.user_data.as_ref().and_then(|u| u.is_favorite).unwrap_or(false),
                    play_count: i.user_data.as_ref().and_then(|u| u.play_count),
                }
            })
            .collect();
        Ok(tracks)
    }

    pub async fn get_playlists(&self) -> Result<Vec<Playlist>, String> {
        let server = self.get_server().ok_or("Not logged in")?;
        let url = format!(
            "{}/Users/{}/Items",
            Self::base_url(&server),
            server.user_id.as_deref().unwrap_or("")
        );
        let params: Vec<(&str, &str)> = vec![
            ("IncludeItemTypes", "Playlist"),
            ("Recursive", "true"),
            ("Fields", "PrimaryImageAspectRatio,ImageTags,ChildCount"),
            ("SortBy", "SortName"),
            ("SortOrder", "Ascending"),
        ];
        let res = self.get_with_params(&url, &server, &params).await?;
        let data: ItemsResponse = serde_json::from_value(res).map_err(|e| e.to_string())?;
        let items = data.items.unwrap_or_default();
        let playlists = items
            .into_iter()
            .map(|i| {
                let image_url = item_image_id(&i.id, &i.image_tags);
                Playlist {
                    id: i.id,
                    name: i.name,
                    image_url,
                    track_count: i.child_count.unwrap_or(0),
                }
            })
            .collect();
        Ok(playlists)
    }

    pub async fn get_views(&self) -> Result<Vec<Library>, String> {
        let server = self.get_server().ok_or("Not logged in")?;
        let url = format!(
            "{}/Users/{}/Views",
            Self::base_url(&server),
            server.user_id.as_deref().unwrap_or("")
        );
        let params: Vec<(&str, &str)> = vec![];
        let res = self.get_with_params(&url, &server, &params).await?;
        let data: ItemsResponse = serde_json::from_value(res).map_err(|e| e.to_string())?;
        let items = data.items.unwrap_or_default();
        let libraries = items
            .into_iter()
            .map(|i| {
                let image_url = item_image_id(&i.id, &i.image_tags);
                let coll = i.collection_type.unwrap_or_else(|| "unknown".to_string());
                Library {
                    id: i.id,
                    name: i.name,
                    collection_type: coll,
                    image_url,
                }
            })
            .collect();
        Ok(libraries)
    }

    pub fn get_image_url(
        &self,
        item_id: &str,
        image_type: &str,
        width: Option<u32>,
        height: Option<u32>,
    ) -> String {
        let server = match self.get_server() {
            Some(s) => s,
            None => return String::new(),
        };
        if item_id.starts_with("http://") || item_id.starts_with("https://") {
            return item_id.to_string();
        }
        let base = Self::base_url(&server);
        let mut q = String::new();
        if let Some(w) = width {
            q.push_str(&format!("MaxWidth={}", w));
        }
        if let Some(h) = height {
            if !q.is_empty() {
                q.push('&');
            }
            q.push_str(&format!("MaxHeight={}", h));
        }
        if q.is_empty() {
            format!("{}/Items/{}/Images/{}", base, item_id, image_type)
        } else {
            format!("{}/Items/{}/Images/{}?{}", base, item_id, image_type, q)
        }
    }

    pub fn get_stream_url(&self, track_id: &str, _bitrate: Option<u32>) -> String {
        let server = match self.get_server() {
            Some(s) => s,
            None => return String::new(),
        };
        let base = Self::base_url(&server);
        let user_id = server.user_id.as_deref().unwrap_or("");
        let token = server.access_token.as_deref().unwrap_or("");
        format!(
            "{}/Audio/{}/stream?UserId={}&DeviceId=doudou-tauri&api_key={}&AudioCodec=mp3,aac,flac",
            base, track_id, user_id, token
        )
    }

    async fn get_with_params(
        &self,
        url: &str,
        server: &JellyfinServer,
        params: &[(&str, &str)],
    ) -> Result<serde_json::Value, String> {
        let mut req = self.client.get(url);
        if let Some(token) = Self::token(server) {
            req = req.header("X-Emby-Token", token);
        }
        for (k, v) in params {
            req = req.query(&[(k, v)]);
        }
        let res = req.send().await.map_err(|e| e.to_string())?;
        if !res.status().is_success() {
            return Err(format!("{}", res.status()));
        }
        res.json().await.map_err(|e| e.to_string())
    }
}

impl Default for JellyfinClient {
    fn default() -> Self {
        Self::new()
    }
}
