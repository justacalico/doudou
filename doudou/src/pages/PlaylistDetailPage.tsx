import { useEffect } from "react";
import { useParams } from "react-router-dom";
import { useLibraryStore } from "../stores/libraryStore";
import { usePlayerStore } from "../stores/playerStore";
import { useServerStore } from "../stores/serverStore";

export function PlaylistDetailPage() {
  const { playlistId } = useParams();
  const session = useServerStore((state) => state.activeSession);
  const { selectedPlaylistTracks, loadPlaylistTracks, isLoading, error } = useLibraryStore();
  const play = usePlayerStore((state) => state.play);

  useEffect(() => {
    if (!session || !playlistId) {
      return;
    }
    void loadPlaylistTracks(session.id, playlistId);
  }, [loadPlaylistTracks, playlistId, session]);

  return (
    <section className="page-card">
      <h2 style={{ marginTop: 0 }}>Playlist Detail</h2>
      <p>Playlist ID: {playlistId ?? "unknown"}</p>
      {isLoading ? <p>Loading playlist...</p> : null}
      {error ? <p style={{ color: "#ff9f9f" }}>{error}</p> : null}
      <div style={{ display: "grid", gap: 8 }}>
        {selectedPlaylistTracks.map((song) => (
          <div key={song.id} className="page-card">
            <strong>{song.title}</strong>
            <div style={{ display: "flex", justifyContent: "space-between", gap: 8 }}>
              <small>{song.artistName}</small>
              <button
                type="button"
                disabled={!session}
                onClick={() => {
                  if (session) {
                    void play(session.id, song);
                  }
                }}
              >
                Play
              </button>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
