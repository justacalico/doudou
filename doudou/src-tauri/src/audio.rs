//! Playback state and commands. Actual audio output can be added with rodio/symphonia later.

use doudou_core::{PlaybackStateResponse, Track};
use std::sync::Mutex;
use std::time::Instant;

pub struct PlaybackState {
    pub current_track: Option<Track>,
    pub is_playing: bool,
    pub position_ms: u64,
    pub duration_ms: u64,
    pub started_at: Option<Instant>,
}

impl Default for PlaybackState {
    fn default() -> Self {
        Self {
            current_track: None,
            is_playing: false,
            position_ms: 0,
            duration_ms: 0,
            started_at: None,
        }
    }
}

impl PlaybackState {
    pub fn to_response(&self) -> PlaybackStateResponse {
        PlaybackStateResponse {
            current_track: self.current_track.clone(),
            is_playing: self.is_playing,
            position_ms: self.position_ms,
            duration_ms: self.duration_ms,
        }
    }
}

pub struct AudioState(pub Mutex<PlaybackState>);

impl Default for AudioState {
    fn default() -> Self {
        Self(Mutex::new(PlaybackState::default()))
    }
}
