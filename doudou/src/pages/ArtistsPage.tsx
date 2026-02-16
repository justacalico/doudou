import { Link } from "react-router-dom";
import { useLibraryStore } from "../stores/libraryStore";
import { useServerStore } from "../stores/serverStore";

export function ArtistsPage() {
  const session = useServerStore((state) => state.activeSession);
  const { artists, loadLibrary, isLoading } = useLibraryStore();

  return (
    <section className="page-card">
      <h2 style={{ marginTop: 0 }}>Artists</h2>
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
      <div style={{ marginTop: 12, display: "grid", gap: 8 }}>
        {artists.map((artist) => (
          <Link key={artist.id} className="nav-link" to={`/artists/${artist.id}`}>
            {artist.name}
          </Link>
        ))}
      </div>
    </section>
  );
}
