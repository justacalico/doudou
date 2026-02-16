import { create } from "zustand";
import {
  nextSong,
  pause,
  playSong,
  previousSong,
  resume,
  seek,
  setVolume,
} from "../lib/tauri-commands";
import type { PlaybackState, Song } from "../types";

const defaultState: PlaybackState = {
  currentSong: null,
  isPlaying: false,
  currentTime: 0,
  duration: 0,
  volume: 1,
  shuffle: false,
  repeatMode: "off",
  queue: [],
  currentQueueIndex: -1,
  isBackground: false,
};

interface PlayerState extends PlaybackState {
  play: (sessionId: string, song: Song) => Promise<void>;
  pausePlayback: () => Promise<void>;
  resumePlayback: () => Promise<void>;
  next: () => Promise<void>;
  previous: () => Promise<void>;
  seekTo: (position: number) => Promise<void>;
  setPlayerVolume: (volume: number) => Promise<void>;
}

export const usePlayerStore = create<PlayerState>((set) => ({
  ...defaultState,
  play: async (sessionId, song) => {
    await playSong(sessionId, song.id);
    set({ currentSong: song, isPlaying: true, duration: song.duration });
  },
  pausePlayback: async () => {
    await pause();
    set({ isPlaying: false });
  },
  resumePlayback: async () => {
    await resume();
    set({ isPlaying: true });
  },
  next: async () => {
    await nextSong();
  },
  previous: async () => {
    await previousSong();
  },
  seekTo: async (position) => {
    await seek(position);
    set({ currentTime: position });
  },
  setPlayerVolume: async (volume) => {
    await setVolume(volume);
    set({ volume });
  },
}));
