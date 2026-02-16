use crate::models::{QueueItem, RepeatMode, Song};

#[derive(Debug, Default, Clone)]
pub struct QueueEngine {
    pub queue: Vec<QueueItem>,
    pub current_index: i32,
    pub shuffle_enabled: bool,
    pub repeat_mode: RepeatMode,
}

impl QueueEngine {
    pub fn current(&self) -> Option<&Song> {
        self.queue
            .get(self.current_index.max(0) as usize)
            .map(|item| &item.song)
    }

    pub fn push(&mut self, item: QueueItem) {
        self.queue.push(item);
        if self.current_index < 0 {
            self.current_index = 0;
        }
    }
}
