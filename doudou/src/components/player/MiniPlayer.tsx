import { Link } from "react-router-dom";
import { usePlayerStore } from "../../stores/playerStore";

interface MiniPlayerProps {
  compact?: boolean;
}

export function MiniPlayer({ compact = false }: MiniPlayerProps) {
  const currentSong = usePlayerStore((state) => state.currentSong);
  const isPlaying = usePlayerStore((state) => state.isPlaying);
  const pausePlayback = usePlayerStore((state) => state.pausePlayback);
  const resumePlayback = usePlayerStore((state) => state.resumePlayback);

  return (
    <div className={compact ? "mobile-mini-player" : "mini-player"}>
      <div>
        <div>{currentSong?.title ?? "Nothing playing"}</div>
        {!compact && <small>{currentSong?.artistName ?? "Queue is empty"}</small>}
      </div>
      <div style={{ display: "flex", gap: 8 }}>
        <button type="button" onClick={() => (isPlaying ? pausePlayback() : resumePlayback())}>
          {isPlaying ? "Pause" : "Play"}
        </button>
        <Link className="nav-link" to="/now-playing">
          Open
        </Link>
      </div>
    </div>
  );
}
