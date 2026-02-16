export type ProviderType = "jellyfin" | "plex" | "subsonic" | "local";
export type Platform = "windows" | "macos" | "linux" | "android" | "ios";

export interface Server {
  id: string;
  type: ProviderType;
  name: string;
  url: string;
  username: string;
  userId?: string;
  token?: string;
  isActive: boolean;
}

export interface Song {
  id: string;
  title: string;
  albumId: string;
  albumName: string;
  artistId: string;
  artistName: string;
  duration: number;
  trackNumber?: number;
  discNumber?: number;
  year?: number;
  genre?: string;
  coverArtUrl?: string;
  streamUrl?: string;
  isFavorite: boolean;
  isDownloaded: boolean;
  localPath?: string;
  serverId: string;
}

export interface Album {
  id: string;
  name: string;
  artistId: string;
  artistName: string;
  year?: number;
  songCount: number;
  duration: number;
  genre?: string;
  coverArtUrl?: string;
  serverId: string;
}

export interface Artist {
  id: string;
  name: string;
  albumCount: number;
  coverArtUrl?: string;
  serverId: string;
}

export interface Playlist {
  id: string;
  name: string;
  songCount: number;
  duration: number;
  coverArtUrl?: string;
  isPublic: boolean;
  serverId: string;
}

export interface Library {
  id: string;
  name: string;
  collectionType: string;
  imageUrl?: string;
}

export interface SearchResults {
  albums: Album[];
  artists: Artist[];
  songs: Song[];
  playlists: Playlist[];
}

export interface AlbumDetail {
  album: Album;
  songs: Song[];
}

export interface QueueItem {
  song: Song;
  queueId: string;
}

export type RepeatMode = "off" | "one" | "all";

export interface PlaybackState {
  currentSong: Song | null;
  isPlaying: boolean;
  currentTime: number;
  duration: number;
  volume: number;
  shuffle: boolean;
  repeatMode: RepeatMode;
  queue: QueueItem[];
  currentQueueIndex: number;
  isBackground: boolean;
}

export type DownloadStatus = "pending" | "downloading" | "completed" | "failed";

export interface Download {
  id: string;
  itemId: string;
  itemType: "song" | "album" | "playlist";
  serverId: string;
  progress: number;
  status: DownloadStatus;
  localPath?: string;
  createdAt: number;
}

export interface Settings {
  theme: "dark" | "light" | "system";
  accentColor: string;
  crossfadeSeconds: number;
  gaplessEnabled: boolean;
  normalizeAudio: boolean;
  scrobblingEnabled: boolean;
  downloadPath?: string;
}

export interface Session {
  id: string;
  serverId: string;
  provider: ProviderType;
  token: string;
  userId?: string;
}
