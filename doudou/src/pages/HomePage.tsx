import { useMemo } from "react";
import { useLibraryStore } from "../stores/libraryStore";
import { useServerStore } from "../stores/serverStore";

export function HomePage() {
  const session = useServerStore((state) => state.activeSession);
  const { albums, artists, playlists, songs, loadLibrary, isLoading, error } = useLibraryStore();

  const stats = useMemo(
    () => [
      { label: "Albums", value: albums.length },
      { label: "Artists", value: artists.length },
      { label: "Tracks", value: songs.length },
      { label: "Playlists", value: playlists.length },
    ],
    [albums.length, artists.length, songs.length, playlists.length],
  );

  return (
    <section className="page-card">
      <h2 style={{ marginTop: 0 }}>Home</h2>
      <p>
        {session
          ? `Connected with ${session.provider}.`
          : "No active server session. Open Settings to connect."}
      </p>
      <div style={{ display: "flex", gap: 8, marginBottom: 16 }}>
        <button
          type="button"
          disabled={!session || isLoading}
          onClick={() => {
            if (!session) {
              return;
            }
            void loadLibrary(session.id);
          }}
        >
          {isLoading ? "Loading..." : "Refresh Library"}
        </button>
      </div>
      {error ? <p style={{ color: "#ff9f9f" }}>{error}</p> : null}
      <div style={{ display: "grid", gap: 8, gridTemplateColumns: "repeat(2, minmax(0, 1fr))" }}>
        {stats.map((item) => (
          <div key={item.label} className="page-card">
            <strong>{item.label}</strong>
            <div>{item.value}</div>
          </div>
        ))}
      </div>
    </section>
  );
}
