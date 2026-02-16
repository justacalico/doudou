import { create } from "zustand";
import { connectServer, disconnectServer } from "../lib/tauri-commands";
import type { ProviderType, Session } from "../types";

interface ServerState {
  activeSession: Session | null;
  connect: (
    provider: ProviderType,
    url: string,
    username: string,
    password: string,
  ) => Promise<void>;
  disconnect: () => Promise<void>;
}

export const useServerStore = create<ServerState>((set, get) => ({
  activeSession: null,
  connect: async (provider, url, username, password) => {
    const session = await connectServer({ provider, url, username, password });
    set({ activeSession: session });
  },
  disconnect: async () => {
    const session = get().activeSession;
    if (!session) {
      return;
    }
    await disconnectServer(session.id);
    set({ activeSession: null });
  },
}));
