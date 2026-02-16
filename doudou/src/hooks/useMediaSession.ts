import { useEffect } from "react";
import { usePlayerStore } from "../stores/playerStore";

export function useMediaSession() {
  const currentSong = usePlayerStore((state) => state.currentSong);
  const isPlaying = usePlayerStore((state) => state.isPlaying);

  useEffect(() => {
    if (!("mediaSession" in navigator) || !currentSong) {
      return;
    }
    navigator.mediaSession.metadata = new MediaMetadata({
      title: currentSong.title,
      artist: currentSong.artistName,
      album: currentSong.albumName,
    });
    navigator.mediaSession.playbackState = isPlaying ? "playing" : "paused";
  }, [currentSong, isPlaying]);
}
