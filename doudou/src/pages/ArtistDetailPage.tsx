import { useParams } from "react-router-dom";
import { PagePlaceholder } from "../components/layout/PagePlaceholder";

export function ArtistDetailPage() {
  const { artistId } = useParams();

  return (
    <PagePlaceholder
      title="Artist Detail"
      description={`Discography and top tracks for artist ${artistId ?? "unknown"} will match Flutter UX.`}
    />
  );
}
