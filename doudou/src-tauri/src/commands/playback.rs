use rand::seq::SliceRandom;
use tauri::State;

use crate::models::{PlaybackState, Queue, QueueItem, RepeatMode, Song};
use crate::state::AppState;

#[tauri::command]
pub async fn play_song(session_id: String, song_id: String, state: State<'_, AppState>) -> Result<(), String> {
    let downloaded_path = state
        .downloads
        .read()
        .values()
        .find(|download| download.item_id == song_id && download.status == "completed")
        .and_then(|download| download.local_path.clone());
    let mut playback = state.playback.write();
    let next_song = Song {
        id: song_id.clone(),
        title: format!("Track {song_id}"),
        album_id: String::new(),
        album_name: "Unknown Album".to_string(),
        artist_id: String::new(),
        artist_name: "Unknown Artist".to_string(),
        duration: 0.0,
        track_number: None,
        disc_number: None,
        year: None,
        genre: None,
        cover_art_url: None,
        stream_url: downloaded_path
            .as_ref()
            .map(|path| format!("file://{path}")),
        is_favorite: false,
        is_downloaded: downloaded_path.is_some(),
        local_path: downloaded_path,
        server_id: session_id,
    };
    playback.current_song = Some(next_song.clone());
    playback.is_playing = true;
    playback.current_time = 0.0;
    playback.duration = next_song.duration;

    if let Some(index) = playback
        .queue_original
        .iter()
        .position(|item| item.song.id == next_song.id)
    {
        playback.current_index = index as i32;
    } else {
        let next_queue_id = format!("q-{}", playback.queue_original.len() + 1);
        playback.queue_original.push(QueueItem {
            song: next_song,
            queue_id: next_queue_id,
        });
        playback.current_index = (playback.queue_original.len() - 1) as i32;
    }
    Ok(())
}

#[tauri::command]
pub async fn pause(state: State<'_, AppState>) -> Result<(), String> {
    state.playback.write().is_playing = false;
    Ok(())
}

#[tauri::command]
pub async fn resume(state: State<'_, AppState>) -> Result<(), String> {
    state.playback.write().is_playing = true;
    Ok(())
}

#[tauri::command]
pub async fn next_song(state: State<'_, AppState>) -> Result<(), String> {
    let mut playback = state.playback.write();
    if playback.queue_original.is_empty() {
        playback.current_song = None;
        playback.current_index = -1;
        playback.is_playing = false;
        return Ok(());
    }
    let len = playback.queue_original.len() as i32;
    let mut next = playback.current_index + 1;
    if next >= len {
        match playback.repeat_mode {
            RepeatMode::All => next = 0,
            RepeatMode::One => next = playback.current_index.max(0),
            RepeatMode::Off => {
                playback.is_playing = false;
                return Ok(());
            }
        }
    }
    playback.current_index = next;
    playback.current_song = playback
        .queue_original
        .get(next as usize)
        .map(|item| item.song.clone());
    Ok(())
}

#[tauri::command]
pub async fn previous_song(state: State<'_, AppState>) -> Result<(), String> {
    let mut playback = state.playback.write();
    if playback.current_time > playback.duration * 0.2 {
        playback.current_time = 0.0;
        return Ok(());
    }
    if playback.queue_original.is_empty() {
        return Ok(());
    }
    let len = playback.queue_original.len() as i32;
    let mut previous = playback.current_index - 1;
    if previous < 0 {
        previous = if playback.repeat_mode == RepeatMode::All {
            len - 1
        } else {
            0
        };
    }
    playback.current_index = previous;
    playback.current_song = playback
        .queue_original
        .get(previous as usize)
        .map(|item| item.song.clone());
    Ok(())
}

#[tauri::command]
pub async fn seek(position: f64, state: State<'_, AppState>) -> Result<(), String> {
    state.playback.write().current_time = position.max(0.0);
    Ok(())
}

#[tauri::command]
pub async fn set_volume(volume: f64, state: State<'_, AppState>) -> Result<(), String> {
    state.playback.write().volume = volume.clamp(0.0, 1.0);
    Ok(())
}

#[tauri::command]
pub async fn add_to_queue(session_id: String, songs: Vec<String>, state: State<'_, AppState>) -> Result<(), String> {
    let mut playback = state.playback.write();
    for song_id in songs {
        let next_queue_id = format!("q-{}", playback.queue_original.len() + 1);
        playback.queue_original.push(QueueItem {
            song: Song {
                id: song_id.clone(),
                title: format!("Track {song_id}"),
                album_id: String::new(),
                album_name: "Unknown Album".to_string(),
                artist_id: String::new(),
                artist_name: "Unknown Artist".to_string(),
                duration: 0.0,
                track_number: None,
                disc_number: None,
                year: None,
                genre: None,
                cover_art_url: None,
                stream_url: None,
                is_favorite: false,
                is_downloaded: false,
                local_path: None,
                server_id: session_id.clone(),
            },
            queue_id: next_queue_id,
        });
    }
    if playback.current_index < 0 && !playback.queue_original.is_empty() {
        playback.current_index = 0;
        playback.current_song = playback.queue_original.first().map(|item| item.song.clone());
    }
    Ok(())
}

#[tauri::command]
pub async fn reorder_queue(from: usize, to: usize, state: State<'_, AppState>) -> Result<(), String> {
    let mut playback = state.playback.write();
    if from >= playback.queue_original.len() || to >= playback.queue_original.len() {
        return Ok(());
    }
    let item = playback.queue_original.remove(from);
    playback.queue_original.insert(to, item);
    if let Some(current) = &playback.current_song {
        if let Some(index) = playback
            .queue_original
            .iter()
            .position(|queued| queued.song.id == current.id)
        {
            playback.current_index = index as i32;
        }
    }
    Ok(())
}

#[tauri::command]
pub async fn clear_queue(state: State<'_, AppState>) -> Result<(), String> {
    let mut playback = state.playback.write();
    playback.queue_original.clear();
    playback.queue_before_shuffle = None;
    playback.current_index = -1;
    playback.current_song = None;
    playback.is_playing = false;
    Ok(())
}

#[tauri::command]
pub async fn get_queue(state: State<'_, AppState>) -> Result<Queue, String> {
    let playback = state.playback.read();
    Ok(Queue {
        items: playback.queue_original.clone(),
        current_index: playback.current_index,
    })
}

#[tauri::command]
pub async fn enable_background_playback(state: State<'_, AppState>) -> Result<(), String> {
    state.playback.write().is_background = true;
    Ok(())
}

#[tauri::command]
pub async fn update_now_playing_info(song: Song, state: State<'_, AppState>) -> Result<(), String> {
    state.playback.write().current_song = Some(song);
    Ok(())
}

#[tauri::command]
pub async fn get_playback_state(state: State<'_, AppState>) -> Result<PlaybackState, String> {
    let playback = state.playback.read();
    Ok(PlaybackState {
        current_song: playback.current_song.clone(),
        is_playing: playback.is_playing,
        current_time: playback.current_time,
        duration: playback.duration,
        volume: playback.volume,
        shuffle: playback.shuffle,
        repeat_mode: playback.repeat_mode.clone(),
        queue: playback.queue_original.clone(),
        current_queue_index: playback.current_index,
        is_background: playback.is_background,
    })
}

#[tauri::command]
pub async fn set_repeat_mode(mode: RepeatMode, state: State<'_, AppState>) -> Result<(), String> {
    state.playback.write().repeat_mode = mode;
    Ok(())
}

#[tauri::command]
pub async fn set_shuffle(enabled: bool, state: State<'_, AppState>) -> Result<(), String> {
    let mut playback = state.playback.write();
    if enabled && !playback.shuffle {
        playback.queue_before_shuffle = Some(playback.queue_original.clone());
        if let Some(current_song) = playback.current_song.clone() {
            let mut rest: Vec<QueueItem> = playback
                .queue_original
                .iter()
                .filter(|item| item.song.id != current_song.id)
                .cloned()
                .collect();
            rest.shuffle(&mut rand::rng());
            let current_item = playback
                .queue_original
                .iter()
                .find(|item| item.song.id == current_song.id)
                .cloned();
            if let Some(current) = current_item {
                let mut shuffled = vec![current];
                shuffled.extend(rest);
                playback.queue_original = shuffled;
                playback.current_index = 0;
            }
        } else {
            playback.queue_original.shuffle(&mut rand::rng());
            if !playback.queue_original.is_empty() {
                playback.current_index = 0;
            }
        }
    } else if !enabled && playback.shuffle {
        if let Some(original) = playback.queue_before_shuffle.take() {
            let current_id = playback.current_song.as_ref().map(|song| song.id.clone());
            playback.queue_original = original;
            if let Some(current_id) = current_id {
                playback.current_index = playback
                    .queue_original
                    .iter()
                    .position(|item| item.song.id == current_id)
                    .map(|i| i as i32)
                    .unwrap_or(0);
            }
        }
    }
    playback.shuffle = enabled;
    Ok(())
}
