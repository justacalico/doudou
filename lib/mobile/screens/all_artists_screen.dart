import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/jellyfin_models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'artist_detail_screen.dart';

/// All artists screen with search
class AllArtistsScreen extends StatefulWidget {
  const AllArtistsScreen({super.key});

  @override
  State<AllArtistsScreen> createState() => _AllArtistsScreenState();
}

class _AllArtistsScreenState extends State<AllArtistsScreen> {
  String _searchQuery = '';

  List<Artist> _filterArtists(List<Artist> artists) {
    if (_searchQuery.isEmpty) {
      return artists..sort((a, b) => a.name.compareTo(b.name));
    }
    return artists
        .where((a) => a.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final artists = _filterArtists(appState.artists);

        return CupertinoPageScaffold(
          backgroundColor: AppTheme.background(context),
          navigationBar: CupertinoNavigationBar(
            middle: const Text('Artists'),
            backgroundColor: AppTheme.background(context),
            border: null,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Search field
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: CupertinoSearchTextField(
                    placeholder: 'Search Artists',
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),

                // Artist list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 150),
                    itemCount: artists.length,
                    itemBuilder: (context, index) {
                      final artist = artists[index];
                      return Column(
                        children: [
                          ArtistTile(
                            artist: artist,
                            getImageUrl: appState.getImageUrl,
                            onTap: () => Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) => ArtistDetailScreen(artist: artist),
                              ),
                            ),
                          ),
                          if (index < artists.length - 1)
                            Padding(
                              padding: EdgeInsets.only(
                                left: AppTheme.spacingL + AppTheme.albumArtMedium + AppTheme.spacingM,
                              ),
                              child: Container(
                                height: 0.5,
                                color: AppTheme.separator(context),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
