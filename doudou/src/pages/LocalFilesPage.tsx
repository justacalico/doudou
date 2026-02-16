import { useState } from "react";
import { scanLocalFolder } from "../lib/tauri-commands";
import type { Song } from "../types";

export function LocalFilesPage() {
  const [path, setPath] = useState("");
  const [songs, setSongs] = useState<Song[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  return (
    <section className="page-card">
      <h2 style={{ marginTop: 0 }}>Local Files</h2>
      <div style={{ display: "flex", gap: 8 }}>
        <input
          value={path}
          onChange={(event) => setPath(event.currentTarget.value)}
          placeholder="/path/to/music"
        />
        <button
          type="button"
          disabled={!path.trim() || loading}
          onClick={() => {
            setLoading(true);
            setError(null);
            void scanLocalFolder(path.trim())
              .then((result) => setSongs(result))
              .catch((err: unknown) =>
                setError(err instanceof Error ? err.message : "Local scan failed"),
              )
              .finally(() => setLoading(false));
          }}
        >
          {loading ? "Scanning..." : "Scan"}
        </button>
      </div>
      {error ? <p style={{ color: "#ff9f9f" }}>{error}</p> : null}
      <p style={{ marginTop: 12 }}>{songs.length} tracks found.</p>
      <div style={{ display: "grid", gap: 8 }}>
        {songs.slice(0, 100).map((song) => (
          <div key={song.id} className="page-card">
            <strong>{song.title}</strong>
            <div>{song.artistName}</div>
          </div>
        ))}
      </div>
    </section>
  );
}
