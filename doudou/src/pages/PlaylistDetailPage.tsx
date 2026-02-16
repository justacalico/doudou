import { useParams } from "react-router-dom";
import { PagePlaceholder } from "../components/layout/PagePlaceholder";

export function PlaylistDetailPage() {
  const { playlistId } = useParams();

  return (
    <PagePlaceholder
      title="Playlist Detail"
      description={`Queue, ordering, and offline actions for playlist ${playlistId ?? "unknown"} are queued for porting.`}
    />
  );
}
