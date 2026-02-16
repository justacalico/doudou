use std::path::Path;

use lofty::prelude::{Accessor, TaggedFileExt};
use lofty::file::AudioFile;
use lofty::probe::Probe;
use walkdir::WalkDir;

use crate::models::{Metadata, Song};

const SUPPORTED_EXTENSIONS: [&str; 12] = [
    "mp3", "flac", "wav", "ogg", "m4a", "aac", "wma", "opus", "aiff", "alac", "ape", "webm",
];

pub fn is_supported(path: &Path) -> bool {
    path.extension()
        .and_then(|value| value.to_str())
        .map(|ext| SUPPORTED_EXTENSIONS.contains(&ext.to_ascii_lowercase().as_str()))
        .unwrap_or(false)
}

pub fn scan(path: &str) -> Vec<String> {
    WalkDir::new(path)
        .follow_links(true)
        .into_iter()
        .filter_map(Result::ok)
        .filter(|entry| entry.file_type().is_file())
        .map(|entry| entry.into_path())
        .filter(|path| is_supported(path))
        .filter_map(|path| path.to_str().map(ToString::to_string))
        .collect()
}

pub fn read_metadata(path: &str) -> Metadata {
    let mut metadata = Metadata {
        title: None,
        artist: None,
        album: None,
        duration_seconds: None,
    };

    if let Ok(tagged_file) = Probe::open(path).and_then(|probe| probe.read()) {
        if let Some(tag) = tagged_file.primary_tag().or_else(|| tagged_file.first_tag()) {
            metadata.title = tag.title().map(|value| value.to_string());
            metadata.artist = tag.artist().map(|value| value.to_string());
            metadata.album = tag.album().map(|value| value.to_string());
        }
        metadata.duration_seconds = Some(tagged_file.properties().duration().as_secs_f64());
    }

    metadata
}

pub fn song_from_file(path: &str, metadata: &Metadata) -> Song {
    let fallback_name = std::path::Path::new(path)
        .file_stem()
        .and_then(|v| v.to_str())
        .unwrap_or("Unknown Track")
        .to_string();
    Song {
        id: format!("local-{:x}", md5::compute(path)),
        title: metadata.title.clone().unwrap_or(fallback_name),
        album_id: format!(
            "local-album-{:x}",
            md5::compute(metadata.album.clone().unwrap_or_default())
        ),
        album_name: metadata.album.clone().unwrap_or_else(|| "Unknown Album".to_string()),
        artist_id: format!(
            "local-artist-{:x}",
            md5::compute(metadata.artist.clone().unwrap_or_default())
        ),
        artist_name: metadata
            .artist
            .clone()
            .unwrap_or_else(|| "Unknown Artist".to_string()),
        duration: metadata.duration_seconds.unwrap_or_default() * 1000.0,
        track_number: None,
        disc_number: None,
        year: None,
        genre: None,
        cover_art_url: None,
        stream_url: Some(format!("file://{path}")),
        is_favorite: false,
        is_downloaded: true,
        local_path: Some(path.to_string()),
        server_id: "local".to_string(),
    }
}
