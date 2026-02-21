/// A saved server configuration for multi-server management.
class SavedServer {
  final String id;
  final String? name;
  final String serverType;
  final String serverUrl;
  final String authMethod;
  final String? identifier;
  final String? credential;
  final String? apiKey;
  final String? userId;

  const SavedServer({
    required this.id,
    this.name,
    required this.serverType,
    required this.serverUrl,
    required this.authMethod,
    this.identifier,
    this.credential,
    this.apiKey,
    this.userId,
  });

  String get displayLabel => name?.trim().isNotEmpty == true
      ? name!
      : serverUrl.replaceFirst(RegExp(r'^https?://'), '').split('/').first;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'serverType': serverType,
        'serverUrl': serverUrl,
        'authMethod': authMethod,
        'identifier': identifier,
        'credential': credential,
        'apiKey': apiKey,
        'userId': userId,
      };

  factory SavedServer.fromJson(Map<String, dynamic> json) {
    return SavedServer(
      id: json['id'] as String,
      name: json['name'] as String?,
      serverType: json['serverType'] as String,
      serverUrl: json['serverUrl'] as String,
      authMethod: json['authMethod'] as String? ?? 'password',
      identifier: json['identifier'] as String?,
      credential: json['credential'] as String?,
      apiKey: json['apiKey'] as String?,
      userId: json['userId'] as String?,
    );
  }

  SavedServer copyWith({
    String? id,
    String? name,
    String? serverType,
    String? serverUrl,
    String? authMethod,
    String? identifier,
    String? credential,
    String? apiKey,
    String? userId,
  }) {
    return SavedServer(
      id: id ?? this.id,
      name: name ?? this.name,
      serverType: serverType ?? this.serverType,
      serverUrl: serverUrl ?? this.serverUrl,
      authMethod: authMethod ?? this.authMethod,
      identifier: identifier ?? this.identifier,
      credential: credential ?? this.credential,
      apiKey: apiKey ?? this.apiKey,
      userId: userId ?? this.userId,
    );
  }
}
