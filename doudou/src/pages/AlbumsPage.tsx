import { Link } from "react-router-dom";
import { useLibraryStore } from "../stores/libraryStore";
import { useServerStore } from "../stores/serverStore";

export function AlbumsPage() {
  const session = useServerStore((state) => state.activeSession);
  const { albums, loadLibrary, isLoading, error } = useLibraryStore();

  return (
    <section className="page-card">
      <h2 style={{ marginTop: 0 }}>Albums</h2>
      <div style={{ display: "flex", gap: 8, marginBottom: 12 }}>
        <button
          type="button"
          disabled={!session || isLoading}
          onClick={() => {
            if (session) {
              void loadLibrary(session.id);
            }
          }}
        >
          {isLoading ? "Loading..." : "Reload"}
        </button>
      </div>
      {error ? <p style={{ color: "#ff9f9f" }}>{error}</p> : null}
      {!albums.length && !isLoading ? <p>No albums found.</p> : null}
      <div style={{ display: "grid", gap: 10 }}>
        {albums.map((album) => (
          <Link key={album.id} to={`/albums/${album.id}`} className="nav-link">
            <strong>{album.name}</strong>
            <div style={{ opacity: 0.9 }}>{album.artistName || "Unknown Artist"}</div>
          </Link>
        ))}
      </div>
    </section>
  );
}
