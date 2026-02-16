import { create } from "zustand";
import {
  getPlaybackState,
  nextSong,
  pause,
  playSong,
  previousSong,
  resume,
  seek,
  setVolume,
  setRepeatMode,
  setShuffle,
} from "../lib/tauri-commands";
import type { PlaybackState, RepeatMode, Song } from "../types";

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
  refresh: () => Promise<void>;
  setRepeat: (mode: RepeatMode) => Promise<void>;
  setShuffleMode: (enabled: boolean) => Promise<void>;
}

export const usePlayerStore = create<PlayerState>((set) => ({
  ...defaultState,
  play: async (sessionId, song) => {
    await playSong(sessionId, song.id);
    const state = await getPlaybackState();
    set({
      ...state,
      currentSong: state.currentSong ?? song,
    });
  },
  pausePlayback: async () => {
    await pause();
    const state = await getPlaybackState();
    set(state);
  },
  resumePlayback: async () => {
    await resume();
    const state = await getPlaybackState();
    set(state);
  },
  next: async () => {
    await nextSong();
    const state = await getPlaybackState();
    set(state);
  },
  previous: async () => {
    await previousSong();
    const state = await getPlaybackState();
    set(state);
  },
  seekTo: async (position) => {
    await seek(position);
    const state = await getPlaybackState();
    set(state);
  },
  setPlayerVolume: async (volume) => {
    await setVolume(volume);
    const state = await getPlaybackState();
    set(state);
  },
  refresh: async () => {
    const state = await getPlaybackState();
    set(state);
  },
  setRepeat: async (mode) => {
    await setRepeatMode(mode);
    const state = await getPlaybackState();
    set(state);
  },
  setShuffleMode: async (enabled) => {
    await setShuffle(enabled);
    const state = await getPlaybackState();
    set(state);
  },
}));
