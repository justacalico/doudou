import { usePlayerStore } from "../stores/playerStore";

export function useAudio() {
  return usePlayerStore((state) => ({
    currentSong: state.currentSong,
    isPlaying: state.isPlaying,
    currentTime: state.currentTime,
    duration: state.duration,
    volume: state.volume,
    play: state.play,
    pausePlayback: state.pausePlayback,
    resumePlayback: state.resumePlayback,
    next: state.next,
    previous: state.previous,
    seekTo: state.seekTo,
    setPlayerVolume: state.setPlayerVolume,
  }));
}
