import { useLibraryStore } from "../stores/libraryStore";

export function useLibrary() {
  return useLibraryStore((state) => ({
    albums: state.albums,
    artists: state.artists,
    playlists: state.playlists,
    searchResults: state.searchResults,
    loadLibrary: state.loadLibrary,
    search: state.search,
  }));
}
