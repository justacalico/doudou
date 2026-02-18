/// Stub for platforms that don't support HttpServer (web).
class StreamProxyService {
  StreamProxyService._();
  static final StreamProxyService instance = StreamProxyService._();

  Future<void> ensureStarted() async {}
  Future<String> register(String url, Map<String, String> headers) async =>
      url;
}
