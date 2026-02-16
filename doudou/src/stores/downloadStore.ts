import { create } from "zustand";
import { downloadForOffline, getDownloads } from "../lib/tauri-commands";
import type { Download } from "../types";

interface DownloadState {
  downloads: Download[];
  refreshDownloads: () => Promise<void>;
  queueDownload: (
    sessionId: string,
    itemId: string,
    itemType: "song" | "album" | "playlist",
  ) => Promise<string>;
}

export const useDownloadStore = create<DownloadState>((set) => ({
  downloads: [],
  refreshDownloads: async () => {
    const downloads = await getDownloads();
    set({ downloads });
  },
  queueDownload: async (sessionId, itemId, itemType) => {
    return downloadForOffline({ sessionId, itemId, itemType });
  },
}));
