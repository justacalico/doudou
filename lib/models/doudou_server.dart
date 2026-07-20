/// Configuration for a doudou-server instance. Stored locally on each client.
///
/// The [key] is the shared password the server operator set via
/// `doudou-server -set login`. It is stored locally so the client can
/// authenticate, but it is never sent to any music server and never leaves the
/// client except when talking to this doudou-server.
class DoudouServerConfig {
  DoudouServerConfig({
    required this.url,
    required this.key,
    this.deviceName,
  });

  /// Base URL of the doudou-server, e.g. `http://192.168.1.20:7427`.
  final String url;
  final String key;
  final String? deviceName;

  Map<String, dynamic> toMap() => {
        'url': url,
        'key': key,
        'deviceName': deviceName,
      };

  factory DoudouServerConfig.fromMap(Map<String, dynamic> map) =>
      DoudouServerConfig(
        url: map['url'] as String? ?? '',
        key: map['key'] as String? ?? '',
        deviceName: map['deviceName'] as String?,
      );

  DoudouServerConfig copyWith({
    String? url,
    String? key,
    String? deviceName,
  }) =>
      DoudouServerConfig(
        url: url ?? this.url,
        key: key ?? this.key,
        deviceName: deviceName ?? this.deviceName,
      );
}
