# Temp notes: Volume slider bug (volume not respected on next song)

## Bug

Volume slider worked for the current track, but when the next song started it didn’t respect the volume; user had to move the slider again.

## Investigation

1. **Where volume is set**
   - UI (e.g. `desktop_layout.dart` `_PlayerExtras`) reads/writes volume via `audioHandler?.setVolume(value)` and `audioHandler?.volumeStream`.
   - `UnifiedAudioHandler.setVolume()` updates `AudioStateController` and calls `_player.setVolume(volume)`.

2. **Where tracks change**
   - Track completion → `_handleTrackCompletion()` → desktop: `_playNextTrackWithRetry()` / mobile: `_performSkipToQueueItem()`.
   - Both paths end up in `_playTrackAtIndex()` → `_loadAndPlayTrackWithFallbacks()` → `_loadAndPlayTrack()`.

3. **Root cause**
   - **Desktop:** `_loadAndPlayTrack()` calls `_recreatePlayer()`, which creates a new `AudioPlayer` via `_createPlayer()`. The new player has default volume (and speed) 1.0. The state controller still had the user’s volume, but it was never applied to the new player.
   - **Mobile/Web:** Same player is reused; applying volume/speed after each load ensures it sticks even if the backend resets it on `setAudioSource`.

## Fix applied

In `lib/services/audio/unified_audio_handler.dart`:

1. **New helper**  
   `_applyVolumeAndSpeedToPlayer()`  
   - Reads `_stateController.volume` and `_stateController.speed`.  
   - Calls `_player.setVolume()` and `_player.setSpeed()`.  
   - Wrapped in try/catch so failures don’t break playback.

2. **Call after every successful track load**
   - **Desktop branch:** After `setAudioSource()` and `play()` succeed, call `await _applyVolumeAndSpeedToPlayer()`.
   - **Mobile/Web branch:** After the same (including when using `_tryLoadWithFallbacks` on web), call `await _applyVolumeAndSpeedToPlayer()`.

Result: whenever a new track is loaded (next track after completion or skip), the current volume and speed from state are reapplied to the player.

## Files touched

- `lib/services/audio/unified_audio_handler.dart` – added `_applyVolumeAndSpeedToPlayer()`, called in both branches of `_loadAndPlayTrack()`.
- `changelog/15.0.0.md` – entry: “Fixed volume (and speed) not applying when the next track starts…”

## Commit

- `Fix volume/speed not applying when next track plays`
