
import 'package:get/get.dart';
import '/l10n/app_localizations.dart';

class PlayingFrom {
  PlayingFromType type;
  String name;

  PlayingFrom({required this.type, this.name = ""});

  get typeString {
    final l10n = AppLocalizations.of(Get.context!)!;
    switch (type) {
      case PlayingFromType.album:
        return l10n.playingfromAlbum;
      case PlayingFromType.playlist:
        return l10n.playingfromPlaylist;
      case PlayingFromType.selection:
        return l10n.playingfromSelection;
      case PlayingFromType.artist:
        return l10n.playingfromArtist;
    }
  }

  get nameString {
    if (type == PlayingFromType.selection) {
      return AppLocalizations.of(Get.context!)!.randomSelection;
    }
    return name;
  }
}

enum PlayingFromType { album, playlist, selection, artist }
