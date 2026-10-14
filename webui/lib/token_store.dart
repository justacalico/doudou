abstract class TokenStore {
  String? read();
  void write(String token);
  void clear();
}

class MemoryTokenStore implements TokenStore {
  String? token;

  @override
  String? read() => token;

  @override
  void write(String token) => this.token = token;

  @override
  void clear() => token = null;
}
