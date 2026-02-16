import { Navigate, RouterProvider, createHashRouter } from "react-router-dom";
import { PlatformAwareLayout } from "./components/layout/PlatformAwareLayout";
import { AlbumDetailPage } from "./pages/AlbumDetailPage";
import { AlbumsPage } from "./pages/AlbumsPage";
import { ArtistDetailPage } from "./pages/ArtistDetailPage";
import { ArtistsPage } from "./pages/ArtistsPage";
import { DownloadsPage } from "./pages/DownloadsPage";
import { HomePage } from "./pages/HomePage";
import { LocalFilesPage } from "./pages/LocalFilesPage";
import { NowPlayingPage } from "./pages/NowPlayingPage";
import { PlaylistDetailPage } from "./pages/PlaylistDetailPage";
import { PlaylistsPage } from "./pages/PlaylistsPage";
import { SearchPage } from "./pages/SearchPage";
import { SettingsPage } from "./pages/SettingsPage";

const router = createHashRouter([
  {
    path: "/",
    element: <PlatformAwareLayout />,
    children: [
      { index: true, element: <HomePage /> },
      { path: "albums", element: <AlbumsPage /> },
      { path: "albums/:albumId", element: <AlbumDetailPage /> },
      { path: "artists", element: <ArtistsPage /> },
      { path: "artists/:artistId", element: <ArtistDetailPage /> },
      { path: "playlists", element: <PlaylistsPage /> },
      { path: "playlists/:playlistId", element: <PlaylistDetailPage /> },
      { path: "search", element: <SearchPage /> },
      { path: "downloads", element: <DownloadsPage /> },
      { path: "local-files", element: <LocalFilesPage /> },
      { path: "settings", element: <SettingsPage /> },
      { path: "now-playing", element: <NowPlayingPage /> },
      { path: "*", element: <Navigate to="/" replace /> },
    ],
  },
]);

export default function App() {
  return <RouterProvider router={router} />;
}
