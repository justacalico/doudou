import { usePlayerStore } from "../stores/playerStore";

export function NowPlayingPage() {
  const {
    currentSong,
    isPlaying,
    currentTime,
    duration,
    volume,
    pausePlayback,
    resumePlayback,
    next,
    previous,
    seekTo,
    setPlayerVolume,
    repeatMode,
    setRepeat,
    shuffle,
    setShuffleMode,
  } = usePlayerStore();

  const nextRepeat = repeatMode === "off" ? "one" : repeatMode === "one" ? "all" : "off";

  return (
    <section className="page-card">
      <h2 style={{ marginTop: 0 }}>Now Playing</h2>
      <h3>{currentSong?.title ?? "Nothing playing"}</h3>
      <p>{currentSong?.artistName ?? "Select a track from albums/playlists"}</p>
      <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
        <button type="button" onClick={() => void previous()}>
          Previous
        </button>
        <button type="button" onClick={() => void (isPlaying ? pausePlayback() : resumePlayback())}>
          {isPlaying ? "Pause" : "Play"}
        </button>
        <button type="button" onClick={() => void next()}>
          Next
        </button>
      </div>
      <div style={{ marginTop: 12, display: "grid", gap: 10 }}>
        <label>
          Position: {Math.floor(currentTime)} / {Math.floor(duration || 0)}
          <input
            type="range"
            min={0}
            max={Math.max(duration || 0, 1)}
            value={Math.min(currentTime, Math.max(duration || 0, 1))}
            onChange={(event) => void seekTo(Number(event.currentTarget.value))}
          />
        </label>
        <label>
          Volume: {Math.round(volume * 100)}%
          <input
            type="range"
            min={0}
            max={1}
            step={0.01}
            value={volume}
            onChange={(event) => void setPlayerVolume(Number(event.currentTarget.value))}
          />
        </label>
        <div style={{ display: "flex", gap: 8 }}>
          <button type="button" onClick={() => void setRepeat(nextRepeat)}>
            Repeat: {repeatMode}
          </button>
          <button type="button" onClick={() => void setShuffleMode(!shuffle)}>
            Shuffle: {shuffle ? "on" : "off"}
          </button>
        </div>
      </div>
    </section>
  );
}
