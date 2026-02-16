#![allow(non_snake_case)]

use dioxus::prelude::*;
use crate::tauri;

#[derive(serde::Deserialize)]
struct PlaybackState {
    current_track: Option<crate::state::Track>,
    is_playing: bool,
    position_ms: u64,
    duration_ms: u64,
}

#[component]
pub fn MiniPlayer() -> Element {
    let mut state = use_signal(|| None::<PlaybackState>);

    use_effect(move || {
        spawn(async move {
            let result: Result<PlaybackState, _> =
                tauri::invoke_tauri("get_playback_state", &()).await;
            if let Ok(s) = result {
                state.set(Some(s));
            }
        });
    });

    let play_pause = move |_| {
        let mut state_handle = state;
        spawn(async move {
            let current: Result<PlaybackState, _> =
                tauri::invoke_tauri("get_playback_state", &()).await;
            let is_playing = current.as_ref().map(|s| s.is_playing).unwrap_or(false);
            if is_playing {
                let _: Result<serde_json::Value, _> = tauri::invoke_tauri("pause", &()).await;
            } else {
                let _: Result<serde_json::Value, _> = tauri::invoke_tauri("resume", &()).await;
            }
            let updated: Result<PlaybackState, _> =
                tauri::invoke_tauri("get_playback_state", &()).await;
            state_handle.set(updated.ok());
        });
    };

    let label = state.read().as_ref().and_then(|s| {
        s.current_track
            .as_ref()
            .map(|t| format!("{} – {}", t.name, t.artist_name.as_deref().unwrap_or("")))
    }).unwrap_or_else(|| "No track playing".to_string());

    let is_playing = state.read().as_ref().map(|s| s.is_playing).unwrap_or(false);

    rsx! {
        div { class: "mini-player-inner",
            span { class: "mini-player-label", "{label}" }
            button {
                class: "mini-player-btn",
                onclick: play_pause,
                if is_playing { "Pause" } else { "Play" }
            }
        }
    }
}
