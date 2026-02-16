#![allow(dead_code)]

use serde_json::Value;

pub mod jellyfin;
pub mod local;
pub mod plex;
pub mod subsonic;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProviderKind {
    Jellyfin,
    Plex,
    Subsonic,
    Local,
}

impl ProviderKind {
    pub fn parse(value: &str) -> Result<Self, String> {
        match value {
            "jellyfin" => Ok(Self::Jellyfin),
            "plex" => Ok(Self::Plex),
            "subsonic" => Ok(Self::Subsonic),
            "local" => Ok(Self::Local),
            _ => Err(format!("unsupported provider: {value}")),
        }
    }
}

pub trait ProviderAdapter {
    fn normalize_url(url: &str) -> String {
        url.trim_end_matches('/').to_string()
    }

    fn single_or_array(value: Option<&Value>) -> Vec<&Value> {
        match value {
            Some(Value::Array(values)) => values.iter().collect(),
            Some(item @ Value::Object(_)) => vec![item],
            _ => vec![],
        }
    }
}
