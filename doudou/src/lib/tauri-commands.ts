import { invoke } from "@tauri-apps/api/core";
import type {
  Album,
  Artist,
  Download,
  Platform,
  Playlist,
  ProviderType,
  SearchResults,
  Session,
  Settings,
  Song,
} from "../types";

interface ConnectServerPayload extends Record<string, unknown> {
  provider: ProviderType;
  url: string;
  username: string;
  password: string;
}

interface FetchAlbumsPayload extends Record<string, unknown> {
  sessionId: string;
  sort?: string;
  filter?: string;
}

interface DownloadPayload extends Record<string, unknown> {
  sessionId: string;
  itemId: string;
  itemType: "song" | "album" | "playlist";
}

export function getPlatform() {
  return invoke<Platform>("get_platform");
}

export function connectServer(payload: ConnectServerPayload) {
  return invoke<Session>("connect_server", payload);
}

export function disconnectServer(sessionId: string) {
  return invoke<void>("disconnect_server", { sessionId });
}

export function fetchAlbums(payload: FetchAlbumsPayload) {
  return invoke<Album[]>("fetch_albums", payload);
}

export function fetchArtists(sessionId: string) {
  return invoke<Artist[]>("fetch_artists", { sessionId });
}

export function fetchPlaylists(sessionId: string) {
  return invoke<Playlist[]>("fetch_playlists", { sessionId });
}

export function searchLibrary(sessionId: string, query: string) {
  return invoke<SearchResults>("search_library", { sessionId, query });
}

export function playSong(sessionId: string, songId: string) {
  return invoke<void>("play_song", { sessionId, songId });
}

export function pause() {
  return invoke<void>("pause");
}

export function resume() {
  return invoke<void>("resume");
}

export function nextSong() {
  return invoke<void>("next_song");
}

export function previousSong() {
  return invoke<void>("previous_song");
}

export function seek(position: number) {
  return invoke<void>("seek", { position });
}

export function setVolume(volume: number) {
  return invoke<void>("set_volume", { volume });
}

export function addToQueue(sessionId: string, songs: string[]) {
  return invoke<void>("add_to_queue", { sessionId, songs });
}

export function clearQueue() {
  return invoke<void>("clear_queue");
}

export function downloadForOffline(payload: DownloadPayload) {
  return invoke<string>("download_for_offline", payload);
}

export function getDownloads() {
  return invoke<Download[]>("get_downloads");
}

export function getSettings() {
  return invoke<Settings>("get_settings");
}

export function updateSettings(settings: Settings) {
  return invoke<void>("update_settings", { settings });
}

export function scanLocalFolder(path: string) {
  return invoke<Song[]>("scan_local_folder", { path });
}
