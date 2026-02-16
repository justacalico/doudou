import { create } from "zustand";
import {
  fetchAlbumDetails,
  fetchAlbums,
  fetchArtists,
  fetchPlaylistTracks,
  fetchPlaylists,
  getAllTracks,
  searchLibrary,
} from "../lib/tauri-commands";
import type { Album, AlbumDetail, Artist, Playlist, SearchResults, Song } from "../types";

interface LibraryState {
  albums: Album[];
  artists: Artist[];
  playlists: Playlist[];
  songs: Song[];
  selectedAlbum: AlbumDetail | null;
  selectedPlaylistTracks: Song[];
  searchResults: SearchResults | null;
  isLoading: boolean;
  error: string | null;
  loadLibrary: (sessionId: string) => Promise<void>;
  search: (sessionId: string, query: string) => Promise<void>;
  loadAlbumDetail: (sessionId: string, albumId: string) => Promise<void>;
  loadPlaylistTracks: (sessionId: string, playlistId: string) => Promise<void>;
}

export const useLibraryStore = create<LibraryState>((set) => ({
  albums: [],
  artists: [],
  playlists: [],
  songs: [],
  selectedAlbum: null,
  selectedPlaylistTracks: [],
  searchResults: null,
  isLoading: false,
  error: null,
  loadLibrary: async (sessionId) => {
    set({ isLoading: true, error: null });
    try {
      const [albums, artists, playlists, songs] = await Promise.all([
        fetchAlbums({ sessionId }),
        fetchArtists(sessionId),
        fetchPlaylists(sessionId),
        getAllTracks(sessionId),
      ]);
      set({ albums, artists, playlists, songs, isLoading: false });
    } catch (error) {
      const message = error instanceof Error ? error.message : "Failed to load library";
      set({ isLoading: false, error: message });
    }
  },
  search: async (sessionId, query) => {
    set({ isLoading: true, error: null });
    try {
      const results = await searchLibrary(sessionId, query);
      set({ searchResults: results, isLoading: false });
    } catch (error) {
      const message = error instanceof Error ? error.message : "Search failed";
      set({ isLoading: false, error: message });
    }
  },
  loadAlbumDetail: async (sessionId, albumId) => {
    set({ isLoading: true, error: null });
    try {
      const detail = await fetchAlbumDetails(sessionId, albumId);
      set({ selectedAlbum: detail, isLoading: false });
    } catch (error) {
      const message = error instanceof Error ? error.message : "Could not load album";
      set({ isLoading: false, error: message });
    }
  },
  loadPlaylistTracks: async (sessionId, playlistId) => {
    set({ isLoading: true, error: null });
    try {
      const tracks = await fetchPlaylistTracks(sessionId, playlistId);
      set({ selectedPlaylistTracks: tracks, isLoading: false });
    } catch (error) {
      const message = error instanceof Error ? error.message : "Could not load playlist";
      set({ isLoading: false, error: message });
    }
  },
}));
