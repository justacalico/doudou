import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:get/get.dart';

import 'artist_screen_controller.dart';

class AboutArtist extends StatelessWidget {
  const AboutArtist({
    super.key,
    required this.artistScreenController,
    this.padding = const EdgeInsets.only(bottom: 90, top: 16),
  });

  final EdgeInsetsGeometry padding;
  final ArtistScreenController artistScreenController;

  static bool hasDescription(ArtistScreenController controller) {
    final artistData = controller.artistData;
    return artistData.containsKey("description") &&
        artistData["description"] != null &&
        (artistData["description"] as String).trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final artistData = artistScreenController.artistData;
    final hasDesc = hasDescription(artistScreenController);
    final source = artistData["descriptionSource"] as String?;
    final fromWikipedia = source != null &&
        source.toLowerCase().contains("wikipedia");
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          padding: padding,
          child: artistScreenController.isArtistContentFetced.value
              ? hasDesc
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (fromWikipedia)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                context.l10n.fromWikipedia,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      fontStyle: FontStyle.italic,
                                    ),
                              ),
                            ),
                          Text(
                            artistData["description"] as String,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  : SizedBox(
                      height: 120,
                      child: Center(
                        child: Text(
                          context.l10n.artistDesNotAvailable,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
