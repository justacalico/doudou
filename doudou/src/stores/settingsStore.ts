import { create } from "zustand";
import { getSettings, updateSettings } from "../lib/tauri-commands";
import type { Platform, Settings } from "../types";

const defaultSettings: Settings = {
  theme: "dark",
  accentColor: "#4f8bff",
  crossfadeSeconds: 0,
  gaplessEnabled: true,
  normalizeAudio: false,
  scrobblingEnabled: false,
};

interface SettingsState {
  platform: Platform;
  settings: Settings;
  setPlatform: (platform: Platform) => void;
  loadSettings: () => Promise<void>;
  saveSettings: (next: Settings) => Promise<void>;
}

export const useSettingsStore = create<SettingsState>((set) => ({
  platform: "linux",
  settings: defaultSettings,
  setPlatform: (platform) => set({ platform }),
  loadSettings: async () => {
    const settings = await getSettings();
    set({ settings });
  },
  saveSettings: async (next) => {
    await updateSettings(next);
    set({ settings: next });
  },
}));
