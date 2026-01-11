import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'album_detail_screen.dart';

/// All albums screen with sorting options
class AllAlbumsScreen extends StatefulWidget {
  const AllAlbumsScreen({super.key});

  @override
  State<AllAlbumsScreen> createState() => _AllAlbumsScreenState();
}

class _AllAlbumsScreenState extends State<AllAlbumsScreen> {
  String _sortBy = 'name'; // name, artist, year, recent

  List<Album> _sortAlbums(List<Album> albums) {
    final sorted = List<Album>.from(albums);
    switch (_sortBy) {
      case 'name':
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'artist':
        sorted.sort((a, b) => (a.artistName ?? '').compareTo(b.artistName ?? ''));
        break;
      case 'year':
        sorted.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
        break;
      case 'recent':
        sorted.sort((a, b) {
          if (a.dateCreated == null && b.dateCreated == null) return 0;
          if (a.dateCreated == null) return 1;
          if (b.dateCreated == null) return -1;
          return b.dateCreated!.compareTo(a.dateCreated!);
        });
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final albums = _sortAlbums(appState.albums);

        return CupertinoPageScaffold(
          backgroundColor: AppTheme.background(context),
          navigationBar: CupertinoNavigationBar(
            middle: const Text('Albums'),
            backgroundColor: AppTheme.background(context),
            border: null,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.sort_down),
              onPressed: () => _showSortOptions(context),
            ),
          ),
          child: SafeArea(
            child: CustomScrollView(
              slivers: [
                AlbumGrid(
                  albums: albums,
                  getImageUrl: appState.getImageUrl,
                  onAlbumTap: (album) => Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => AlbumDetailScreen(album: album),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 150),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSortOptions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Sort By'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _sortBy = 'name');
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Name'),
                if (_sortBy == 'name') ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark, size: 18),
                ],
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _sortBy = 'artist');
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Artist'),
                if (_sortBy == 'artist') ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark, size: 18),
                ],
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _sortBy = 'year');
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Year'),
                if (_sortBy == 'year') ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark, size: 18),
                ],
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _sortBy = 'recent');
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Recently Added'),
                if (_sortBy == 'recent') ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark, size: 18),
                ],
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
