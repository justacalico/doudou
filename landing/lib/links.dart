import 'package:url_launcher/url_launcher.dart';

abstract final class Links {
  static const download = 'https://openlyst.ink/apps/doudou';
  static const repo = 'https://gitlab.com/Openlyst/doudou';
  static const releases = 'https://gitlab.com/Openlyst/doudou/-/releases';
  static const issues = 'https://gitlab.com/Openlyst/doudou/-/issues';
  static const license =
      'https://gitlab.com/Openlyst/doudou/-/blob/main/LICENSE';
  static const harmonyMusic = 'https://github.com/anandnet/Harmony-Music';

  /// Opens [url] in a new tab. Rebound in tests to capture calls.
  static Future<void> Function(String url) open = _open;

  static Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
}
