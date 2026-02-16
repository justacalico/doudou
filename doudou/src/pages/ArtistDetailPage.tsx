import { useParams } from "react-router-dom";
import { useLibraryStore } from "../stores/libraryStore";

export function ArtistDetailPage() {
  const { artistId } = useParams();
  const songs = useLibraryStore((state) => state.songs);
  const filtered = songs.filter((song) => song.artistId === artistId);

  return (
    <section className="page-card">
      <h2 style={{ marginTop: 0 }}>Artist Detail</h2>
      <p>Artist ID: {artistId ?? "unknown"}</p>
      <div style={{ display: "grid", gap: 8 }}>
        {filtered.length ? (
          filtered.map((song) => (
            <div key={song.id} className="page-card">
              {song.title}
            </div>
          ))
        ) : (
          <p>No tracks loaded for this artist yet.</p>
        )}
      </div>
    </section>
  );
}
