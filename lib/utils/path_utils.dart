/// Helpers for local file path handling (e.g. artwork URLs).
library;

/// Returns true if [url] is a local file path (file:// or absolute path).
bool isLocalFilePath(String url) {
  return url.startsWith('file://') || url.startsWith('/');
}

/// Returns the filesystem path from [url] (strips 'file://' prefix if present).
String getFilePath(String url) {
  if (url.startsWith('file://')) {
    return url.substring(7); // Remove 'file://' prefix
  }
  return url;
}
