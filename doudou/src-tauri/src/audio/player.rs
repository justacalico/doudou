use super::queue::QueueEngine;
use crate::models::{PlaybackState, RepeatMode};

#[derive(Debug, Clone)]
pub struct AudioPlayer {
    pub queue: QueueEngine,
    pub is_playing: bool,
    pub current_time: f64,
    pub duration: f64,
    pub volume: f64,
}

impl Default for AudioPlayer {
    fn default() -> Self {
        Self {
            queue: QueueEngine {
                queue: vec![],
                current_index: -1,
                shuffle_enabled: false,
                repeat_mode: RepeatMode::Off,
            },
            is_playing: false,
            current_time: 0.0,
            duration: 0.0,
            volume: 1.0,
        }
    }
}

impl AudioPlayer {
    pub fn snapshot(&self) -> PlaybackState {
        PlaybackState {
            current_song: self.queue.current().cloned(),
            is_playing: self.is_playing,
            current_time: self.current_time,
            duration: self.duration,
            volume: self.volume,
            shuffle: self.queue.shuffle_enabled,
            repeat_mode: self.queue.repeat_mode.clone(),
            queue: self.queue.queue.clone(),
            current_queue_index: self.queue.current_index,
            is_background: false,
        }
    }
}
