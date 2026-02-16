import { useState } from "react";
import { useLibraryStore } from "../stores/libraryStore";
import { useServerStore } from "../stores/serverStore";

export function SearchPage() {
  const [query, setQuery] = useState("");
  const session = useServerStore((state) => state.activeSession);
  const { searchResults, search, isLoading, error } = useLibraryStore();

  return (
    <section className="page-card">
      <h2 style={{ marginTop: 0 }}>Search</h2>
      <div style={{ display: "flex", gap: 8 }}>
        <input
          value={query}
          onChange={(event) => setQuery(event.currentTarget.value)}
          placeholder="Search tracks, albums, artists"
        />
        <button
          type="button"
          disabled={!session || !query.trim() || isLoading}
          onClick={() => {
            if (session && query.trim()) {
              void search(session.id, query.trim());
            }
          }}
        >
          {isLoading ? "Searching..." : "Search"}
        </button>
      </div>
      {error ? <p style={{ color: "#ff9f9f" }}>{error}</p> : null}
      <div style={{ marginTop: 12, display: "grid", gap: 8 }}>
        <div className="page-card">
          <strong>Albums ({searchResults?.albums.length ?? 0})</strong>
        </div>
        <div className="page-card">
          <strong>Artists ({searchResults?.artists.length ?? 0})</strong>
        </div>
        <div className="page-card">
          <strong>Songs ({searchResults?.songs.length ?? 0})</strong>
        </div>
      </div>
    </section>
  );
}
