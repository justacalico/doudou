import { invoke } from "@tauri-apps/api/core";
import type {
  Album,
  AlbumDetail,
  Artist,
  Download,
  Library,
  PlaybackState,
  Platform,
  Playlist,
  ProviderType,
  QueueItem,
  RepeatMode,
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

export function fetchLibraries(sessionId: string) {
  return invoke<Library[]>("fetch_libraries", { sessionId });
}

export function fetchAlbumDetails(sessionId: string, albumId: string) {
  return invoke<AlbumDetail>("fetch_album_details", { sessionId, albumId });
}

export function fetchPlaylists(sessionId: string) {
  return invoke<Playlist[]>("fetch_playlists", { sessionId });
}

export function fetchPlaylistTracks(sessionId: string, playlistId: string) {
  return invoke<Song[]>("fetch_playlist_tracks", { sessionId, playlistId });
}

export function searchLibrary(sessionId: string, query: string) {
  return invoke<SearchResults>("search_library", { sessionId, query });
}

export function getAllTracks(sessionId: string) {
  return invoke<Song[]>("get_all_tracks", { sessionId });
}

export function getStarredTracks(sessionId: string) {
  return invoke<Song[]>("get_starred_tracks", { sessionId });
}

export function toggleFavorite(sessionId: string, itemId: string, isFavorite: boolean) {
  return invoke<void>("toggle_favorite", { sessionId, itemId, isFavorite });
}

export function createPlaylist(sessionId: string, name: string) {
  return invoke<Playlist | null>("create_playlist", { sessionId, name });
}

export function addTrackToPlaylist(sessionId: string, playlistId: string, trackId: string) {
  return invoke<void>("add_track_to_playlist", { sessionId, playlistId, trackId });
}

export function removeTrackFromPlaylist(sessionId: string, playlistId: string, trackIndex: number) {
  return invoke<void>("remove_track_from_playlist", { sessionId, playlistId, trackIndex });
}

export function renamePlaylist(sessionId: string, playlistId: string, newName: string) {
  return invoke<void>("rename_playlist", { sessionId, playlistId, newName });
}

export function removePlaylist(sessionId: string, playlistId: string) {
  return invoke<void>("remove_playlist", { sessionId, playlistId });
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

export function getQueue() {
  return invoke<{ items: QueueItem[]; currentIndex: number }>("get_queue");
}

export function getPlaybackState() {
  return invoke<PlaybackState>("get_playback_state");
}

export function setRepeatMode(mode: RepeatMode) {
  return invoke<void>("set_repeat_mode", { mode });
}

export function setShuffle(enabled: boolean) {
  return invoke<void>("set_shuffle", { enabled });
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
