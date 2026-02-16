import { useEffect } from "react";
import { useDownloadStore } from "../stores/downloadStore";
import { useLibraryStore } from "../stores/libraryStore";
import { useServerStore } from "../stores/serverStore";

export function DownloadsPage() {
  const session = useServerStore((state) => state.activeSession);
  const songs = useLibraryStore((state) => state.songs);
  const { downloads, refreshDownloads, queueDownload } = useDownloadStore();

  useEffect(() => {
    void refreshDownloads();
  }, [refreshDownloads]);

  return (
    <section className="page-card">
      <h2 style={{ marginTop: 0 }}>Downloads</h2>
      {session && songs.length ? (
        <button
          type="button"
          onClick={() => {
            const firstSong = songs[0];
            if (!firstSong) {
              return;
            }
            void queueDownload(session.id, firstSong.id, "song").then(() => refreshDownloads());
          }}
        >
          Download First Loaded Song
        </button>
      ) : (
        <p>Load a library first to queue downloads.</p>
      )}
      <div style={{ marginTop: 12, display: "grid", gap: 8 }}>
        {downloads.map((download) => (
          <div key={download.id} className="page-card">
            <strong>{download.itemId}</strong>
            <div>
              {download.status} - {Math.round(download.progress)}%
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
