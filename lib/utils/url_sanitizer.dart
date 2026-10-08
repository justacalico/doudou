/// Query parameters that carry credentials and must never be persisted to
/// disk or synced to other devices.
const _authQueryParams = {'api_key', 'X-Plex-Token'};

/// Removes credential-bearing query parameters from [url]. Returns the input
/// unchanged when it carries none or cannot be parsed.
String scrubUrlAuthParams(String url) {
  if (!url.contains('api_key=') && !url.contains('X-Plex-Token=')) {
    return url;
  }
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final kept = Map<String, String>.from(uri.queryParameters)
    ..removeWhere((key, _) => _authQueryParams.contains(key));
  if (kept.length == uri.queryParameters.length) return url;
  if (kept.isEmpty) {
    // Uri.replace leaves a dangling '?' when all params are gone.
    return uri.replace(queryParameters: <String, String>{}).toString().replaceFirst(RegExp(r'\?$'), '');
  }
  return uri.replace(queryParameters: kept).toString();
}
