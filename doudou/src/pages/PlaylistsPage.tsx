import { Link } from "react-router-dom";
import { useLibraryStore } from "../stores/libraryStore";

export function PlaylistsPage() {
  const playlists = useLibraryStore((state) => state.playlists);

  return (
    <section className="page-card">
      <h2 style={{ marginTop: 0 }}>Playlists</h2>
      {!playlists.length ? <p>No playlists found.</p> : null}
      <div style={{ display: "grid", gap: 8 }}>
        {playlists.map((playlist) => (
          <Link key={playlist.id} className="nav-link" to={`/playlists/${playlist.id}`}>
            <strong>{playlist.name}</strong>
            <div>{playlist.songCount} tracks</div>
          </Link>
        ))}
      </div>
    </section>
  );
}
