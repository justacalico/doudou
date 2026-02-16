import { useParams } from "react-router-dom";
import { PagePlaceholder } from "../components/layout/PagePlaceholder";

export function AlbumDetailPage() {
  const { albumId } = useParams();

  return (
    <PagePlaceholder
      title="Album Detail"
      description={`Track list and album actions for album ${albumId ?? "unknown"} will be ported from Flutter behavior.`}
    />
  );
}
