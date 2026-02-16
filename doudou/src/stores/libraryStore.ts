import { create } from "zustand";
import {
  fetchAlbums,
  fetchArtists,
  fetchPlaylists,
  searchLibrary,
} from "../lib/tauri-commands";
import type { Album, Artist, Playlist, SearchResults } from "../types";

interface LibraryState {
  albums: Album[];
  artists: Artist[];
  playlists: Playlist[];
  searchResults: SearchResults | null;
  loadLibrary: (sessionId: string) => Promise<void>;
  search: (sessionId: string, query: string) => Promise<void>;
}

export const useLibraryStore = create<LibraryState>((set) => ({
  albums: [],
  artists: [],
  playlists: [],
  searchResults: null,
  loadLibrary: async (sessionId) => {
    const [albums, artists, playlists] = await Promise.all([
      fetchAlbums({ sessionId }),
      fetchArtists(sessionId),
      fetchPlaylists(sessionId),
    ]);
    set({ albums, artists, playlists });
  },
  search: async (sessionId, query) => {
    const results = await searchLibrary(sessionId, query);
    set({ searchResults: results });
  },
}));
