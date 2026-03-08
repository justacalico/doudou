# UI Performance Notes

## Rebuild-heavy paths profiled
- `HomeScreen` tab body (`lib/ui/screens/Home/home_screen.dart`)
- Horizontal section rows in `library_section_builders.dart`
- Large list surfaces in `list_widget.dart` and `content_list_widget.dart`

## Applied optimizations
- Disabled synchronous build-time debug file logging by default:
  - `_enableAgentBuildLogging = false`
  - avoids file I/O in hot build paths.
- Moved `SongDownloads` count lookup out of widget build logic into
  `HomeScreenController.downloadedSongsCount` with explicit refresh method.
- Added stable list item keys across high-volume list rows (`ValueKey`).
- Added `PageStorageKey` and `cacheExtent` to scrolling list views.
- Restored virtualization-friendly defaults:
  - enabled `addAutomaticKeepAlives` and `addRepaintBoundaries` where
    they were previously disabled.
- Precomputed album artist subtitle strings in `list_widget.dart` so repeated
  artist string composition is no longer done inside item builders.

## Route for future profiling
- Use Flutter DevTools Rebuild Tracker and Frame Analysis on:
  - home tab scroll
  - queue open/close
  - library large list scrolling
- Target metrics:
  - lower raster/UI frame time spikes while scrolling
  - fewer widget rebuilds for unchanged rows
