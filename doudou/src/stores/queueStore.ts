import { create } from "zustand";
import { addToQueue, clearQueue } from "../lib/tauri-commands";
import type { QueueItem } from "../types";

interface QueueState {
  items: QueueItem[];
  enqueue: (sessionId: string, songIds: string[]) => Promise<void>;
  resetQueue: () => Promise<void>;
}

export const useQueueStore = create<QueueState>((set) => ({
  items: [],
  enqueue: async (sessionId, songIds) => {
    await addToQueue(sessionId, songIds);
  },
  resetQueue: async () => {
    await clearQueue();
    set({ items: [] });
  },
}));
