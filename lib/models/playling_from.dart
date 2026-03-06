// ignore_for_file: constant_identifier_names

import 'package:get/get.dart';
import '/l10n/app_localizations.dart';

class PlaylingFrom {
  PlaylingFromType type;
  String name;

  PlaylingFrom({required this.type, this.name = ""});

  get typeString {
    final l10n = AppLocalizations.of(Get.context!)!;
    switch (type) {
      case PlaylingFromType.ALBUM:
        return l10n.playingfromAlbum;
      case PlaylingFromType.PLAYLIST:
        return l10n.playingfromPlaylist;
      case PlaylingFromType.SELECTION:
        return l10n.playingfromSelection;
      case PlaylingFromType.ARTIST:
        return l10n.playingfromArtist;
    }
  }

  get nameString {
    if (type == PlaylingFromType.SELECTION) {
      return AppLocalizations.of(Get.context!)!.randomSelection;
    }
    return name;
  }
}

enum PlaylingFromType { ALBUM, PLAYLIST, SELECTION, ARTIST }
