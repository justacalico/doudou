import { create } from "zustand";
import { addToQueue, clearQueue, getQueue } from "../lib/tauri-commands";
import type { QueueItem } from "../types";

interface QueueState {
  items: QueueItem[];
  enqueue: (sessionId: string, songIds: string[]) => Promise<void>;
  resetQueue: () => Promise<void>;
  refreshQueue: () => Promise<void>;
}

export const useQueueStore = create<QueueState>((set) => ({
  items: [],
  enqueue: async (sessionId, songIds) => {
    await addToQueue(sessionId, songIds);
    const queue = await getQueue();
    set({ items: queue.items });
  },
  resetQueue: async () => {
    await clearQueue();
    set({ items: [] });
  },
  refreshQueue: async () => {
    const queue = await getQueue();
    set({ items: queue.items });
  },
}));
