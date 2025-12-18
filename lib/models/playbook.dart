import '../services/base_service.dart';

/// Represents a configured music service (Jellyfin, Navidrome, Local, etc.)
class Playbook {
  final String id;
  final String name;
  final ServerType type;
  final bool isEnabled;
  final Map<String, dynamic> config;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  Playbook({
    required this.id,
    required this.name,
    required this.type,
    this.isEnabled = true,
    required this.config,
    DateTime? createdAt,
    this.lastUsedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create a copy with updated fields
  Playbook copyWith({
    String? id,
    String? name,
    ServerType? type,
    bool? isEnabled,
    Map<String, dynamic>? config,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) {
    return Playbook(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isEnabled: isEnabled ?? this.isEnabled,
      config: config ?? Map.from(this.config),
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'isEnabled': isEnabled,
      'config': config,
      'createdAt': createdAt.toIso8601String(),
      'lastUsedAt': lastUsedAt?.toIso8601String(),
    };
  }

  /// Create from JSON
  factory Playbook.fromJson(Map<String, dynamic> json) {
    return Playbook(
      id: json['id'] as String,
      name: json['name'] as String,
      type: ServerType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ServerType.jellyfin,
      ),
      isEnabled: json['isEnabled'] as bool? ?? true,
      config: Map<String, dynamic>.from(json['config'] as Map),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      lastUsedAt: json['lastUsedAt'] != null 
          ? DateTime.tryParse(json['lastUsedAt'] as String)
          : null,
    );
  }

  /// Get display icon for this service type
  String get typeDisplayName {
    switch (type) {
      case ServerType.jellyfin:
        return 'Jellyfin';
      case ServerType.plex:
        return 'Plex';
      case ServerType.navidrome:
        return 'Navidrome';
      case ServerType.local:
        return 'Local Music';
    }
  }

  /// Get server URL from config (for server-based services)
  String? get serverUrl => config['serverUrl'] as String?;

  /// Get username from config (for server-based services)
  String? get username => config['username'] as String?;

  /// Get directories from config (for local music)
  List<String> get directories {
    final dirs = config['directories'];
    if (dirs is List) {
      return dirs.cast<String>();
    }
    return [];
  }

  @override
  String toString() => 'Playbook($name, $type, enabled: $isEnabled)';
}

/// Configuration templates for creating new Playbooks
class PlaybookConfig {
  /// Create Jellyfin playbook config
  static Map<String, dynamic> jellyfin({
    required String serverUrl,
    required String username,
    String? password,
    String? apiKey,
    String? userId,
    String? accessToken,
  }) {
    return {
      'serverUrl': serverUrl,
      'username': username,
      'password': password,
      'apiKey': apiKey,
      'userId': userId,
      'accessToken': accessToken,
    };
  }

  /// Create Plex playbook config
  static Map<String, dynamic> plex({
    required String serverUrl,
    String? token,
  }) {
    return {
      'serverUrl': serverUrl,
      'token': token,
    };
  }

  /// Create Navidrome playbook config
  static Map<String, dynamic> navidrome({
    required String serverUrl,
    required String username,
    String? password,
    String? salt,
    String? token,
  }) {
    return {
      'serverUrl': serverUrl,
      'username': username,
      'password': password,
      'salt': salt,
      'token': token,
    };
  }

  /// Create Local music playbook config
  static Map<String, dynamic> local({
    required List<String> directories,
    bool fetchOnlineArtwork = true,
  }) {
    return {
      'directories': directories,
      'fetchOnlineArtwork': fetchOnlineArtwork,
    };
  }
}
