import { useDownloadStore } from "../stores/downloadStore";

export function useDownloads() {
  return useDownloadStore((state) => ({
    downloads: state.downloads,
    refreshDownloads: state.refreshDownloads,
    queueDownload: state.queueDownload,
  }));
}
