import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/playbook.dart';
import '../models/jellyfin_models.dart';
import 'base_service.dart';
import 'players/jellyfin_service.dart';
import 'players/navidrome_service.dart';
import 'players/plex_service.dart';
import 'players/local_music_service.dart';

/// Service for managing multiple music service playbooks
class PlaybookService extends ChangeNotifier {
  static const String _playbooksKey = 'playbooks';
  static const String _activePlaybookKey = 'active_playbook_id';
  
  final List<Playbook> _playbooks = [];
  String? _activePlaybookId;
  bool _isInitialized = false;
  
  // Service instances cache
  final Map<String, BaseMediaService> _serviceInstances = {};
  
  // Getters
  List<Playbook> get playbooks => List.unmodifiable(_playbooks);
  List<Playbook> get enabledPlaybooks => _playbooks.where((p) => p.isEnabled).toList();
  String? get activePlaybookId => _activePlaybookId;
  bool get isInitialized => _isInitialized;
  bool get hasPlaybooks => _playbooks.isNotEmpty;
  bool get hasEnabledPlaybooks => enabledPlaybooks.isNotEmpty;
  
  Playbook? get activePlaybook {
    if (_activePlaybookId == null) return null;
    try {
      return _playbooks.firstWhere((p) => p.id == _activePlaybookId);
    } catch (_) {
      return null;
    }
  }
  
  /// Initialize the service and load saved playbooks
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    
    // Load playbooks
    final playbooksJson = prefs.getString(_playbooksKey);
    if (playbooksJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(playbooksJson);
        _playbooks.clear();
        _playbooks.addAll(decoded.map((json) => Playbook.fromJson(json)));
      } catch (e) {
        if (kDebugMode) {
          print('PlaybookService: Error loading playbooks: $e');
        }
      }
    }
    
    // Load active playbook ID
    _activePlaybookId = prefs.getString(_activePlaybookKey);
    
    // Validate active playbook exists and is enabled
    if (_activePlaybookId != null) {
      final active = activePlaybook;
      if (active == null || !active.isEnabled) {
        // Try to find first enabled playbook
        final firstEnabled = enabledPlaybooks.isNotEmpty ? enabledPlaybooks.first : null;
        _activePlaybookId = firstEnabled?.id;
        await _saveActivePlaybook();
      }
    }
    
    _isInitialized = true;
    
    if (kDebugMode) {
      print('PlaybookService: Initialized with ${_playbooks.length} playbooks');
      print('PlaybookService: Active playbook: ${activePlaybook?.name}');
    }
    
    notifyListeners();
  }
  
  /// Add a new playbook
  Future<Playbook> addPlaybook({
    required String name,
    required ServerType type,
    required Map<String, dynamic> config,
    bool isEnabled = true,
  }) async {
    final playbook = Playbook(
      id: const Uuid().v4(),
      name: name,
      type: type,
      config: config,
      isEnabled: isEnabled,
    );
    
    _playbooks.add(playbook);
    await _savePlaybooks();
    
    // If this is the first enabled playbook, make it active
    if (_activePlaybookId == null && isEnabled) {
      _activePlaybookId = playbook.id;
      await _saveActivePlaybook();
    }
    
    if (kDebugMode) {
      print('PlaybookService: Added playbook ${playbook.name}');
    }
    
    notifyListeners();
    return playbook;
  }
  
  /// Update an existing playbook
  Future<void> updatePlaybook(Playbook playbook) async {
    final index = _playbooks.indexWhere((p) => p.id == playbook.id);
    if (index >= 0) {
      _playbooks[index] = playbook;
      await _savePlaybooks();
      
      // Clear cached service instance to force recreation
      _serviceInstances.remove(playbook.id);
      
      notifyListeners();
    }
  }
  
  /// Remove a playbook
  Future<void> removePlaybook(String playbookId) async {
    _playbooks.removeWhere((p) => p.id == playbookId);
    _serviceInstances.remove(playbookId);
    
    // If we removed the active playbook, select another
    if (_activePlaybookId == playbookId) {
      final firstEnabled = enabledPlaybooks.isNotEmpty ? enabledPlaybooks.first : null;
      _activePlaybookId = firstEnabled?.id;
      await _saveActivePlaybook();
    }
    
    await _savePlaybooks();
    notifyListeners();
  }
  
  /// Toggle playbook enabled state
  Future<void> togglePlaybook(String playbookId, bool enabled) async {
    final index = _playbooks.indexWhere((p) => p.id == playbookId);
    if (index >= 0) {
      _playbooks[index] = _playbooks[index].copyWith(isEnabled: enabled);
      await _savePlaybooks();
      
      // If we disabled the active playbook, select another
      if (!enabled && _activePlaybookId == playbookId) {
        final firstEnabled = enabledPlaybooks.isNotEmpty ? enabledPlaybooks.first : null;
        _activePlaybookId = firstEnabled?.id;
        await _saveActivePlaybook();
      }
      
      notifyListeners();
    }
  }
  
  /// Set the active playbook
  Future<void> setActivePlaybook(String playbookId) async {
    final playbook = _playbooks.firstWhere(
      (p) => p.id == playbookId,
      orElse: () => throw Exception('Playbook not found'),
    );
    
    if (!playbook.isEnabled) {
      throw Exception('Cannot activate disabled playbook');
    }
    
    _activePlaybookId = playbookId;
    
    // Update last used time
    final index = _playbooks.indexOf(playbook);
    _playbooks[index] = playbook.copyWith(lastUsedAt: DateTime.now());
    
    await _saveActivePlaybook();
    await _savePlaybooks();
    notifyListeners();
  }
  
  /// Get or create a service instance for a playbook
  Future<BaseMediaService?> getServiceForPlaybook(String playbookId) async {
    // Return cached instance if available
    if (_serviceInstances.containsKey(playbookId)) {
      return _serviceInstances[playbookId];
    }
    
    final playbook = _playbooks.firstWhere(
      (p) => p.id == playbookId,
      orElse: () => throw Exception('Playbook not found'),
    );
    
    BaseMediaService? service;
    
    switch (playbook.type) {
      case ServerType.jellyfin:
        service = await _createJellyfinService(playbook);
        break;
      case ServerType.navidrome:
        service = await _createNavidromeService(playbook);
        break;
      case ServerType.plex:
        service = await _createPlexService(playbook);
        break;
      case ServerType.local:
        service = await _createLocalMusicService(playbook);
        break;
    }
    
    if (service != null) {
      _serviceInstances[playbookId] = service;
    }
    
    return service;
  }
  
  /// Get service for the active playbook
  Future<BaseMediaService?> getActiveService() async {
    if (_activePlaybookId == null) return null;
    return getServiceForPlaybook(_activePlaybookId!);
  }
  
  Future<JellyfinService?> _createJellyfinService(Playbook playbook) async {
    final service = JellyfinService();
    final config = playbook.config;
    
    final serverUrl = config['serverUrl'] as String?;
    if (serverUrl == null) return null;
    
    // Try to restore session with existing credentials
    final accessToken = config['accessToken'] as String?;
    final userId = config['userId'] as String?;
    
    if (accessToken != null && userId != null) {
      // Restore existing session using JellyfinServer
      service.setJellyfinServer(JellyfinServer(
        serverUrl: serverUrl,
        userId: userId,
        accessToken: accessToken,
        username: config['username'] as String?,
      ));
    } else {
      service.setServer(serverUrl);
      
      // Try to authenticate if we have credentials
      final username = config['username'] as String?;
      final password = config['password'] as String?;
      
      if (username != null && password != null) {
        try {
          await service.authenticate(serverUrl, username, password);
        } catch (e) {
          if (kDebugMode) {
            print('PlaybookService: Jellyfin auth failed: $e');
          }
        }
      }
    }
    
    return service;
  }
  
  Future<NavidromeService?> _createNavidromeService(Playbook playbook) async {
    final service = NavidromeService();
    final config = playbook.config;
    
    final serverUrl = config['serverUrl'] as String?;
    final username = config['username'] as String?;
    
    if (serverUrl == null || username == null) return null;
    
    service.setServer(serverUrl);
    
    // Try to authenticate
    final password = config['password'] as String?;
    if (password != null) {
      try {
        await service.authenticate(serverUrl, username, password);
      } catch (e) {
        if (kDebugMode) {
          print('PlaybookService: Navidrome auth failed: $e');
        }
      }
    }
    
    return service;
  }
  
  Future<PlexService?> _createPlexService(Playbook playbook) async {
    final service = PlexService();
    final config = playbook.config;
    
    final serverUrl = config['serverUrl'] as String?;
    final token = config['token'] as String?;
    
    if (serverUrl == null) return null;
    
    service.setServer(serverUrl);
    
    // Authenticate with token if available
    if (token != null) {
      try {
        await service.authenticate(serverUrl, '', token);
      } catch (e) {
        if (kDebugMode) {
          print('PlaybookService: Plex auth failed: $e');
        }
      }
    }
    
    return service;
  }
  
  Future<LocalMusicService?> _createLocalMusicService(Playbook playbook) async {
    final service = LocalMusicService();
    await service.initialize();
    
    final config = playbook.config;
    final directories = config['directories'] as List<dynamic>?;
    
    if (directories != null) {
      for (final dir in directories) {
        try {
          await service.addDirectory(dir as String);
        } catch (e) {
          if (kDebugMode) {
            print('PlaybookService: Error adding directory $dir: $e');
          }
        }
      }
    }
    
    final fetchOnlineArtwork = config['fetchOnlineArtwork'] as bool? ?? true;
    await service.setFetchOnlineArtwork(fetchOnlineArtwork);
    
    return service;
  }
  
  /// Validate a playbook's credentials
  Future<bool> validatePlaybook(String playbookId) async {
    try {
      final service = await getServiceForPlaybook(playbookId);
      if (service == null) return false;
      return await service.validateCredentials();
    } catch (e) {
      if (kDebugMode) {
        print('PlaybookService: Error validating playbook: $e');
      }
      return false;
    }
  }
  
  /// Clear all playbooks and cached data
  Future<void> clearAll() async {
    _playbooks.clear();
    _serviceInstances.clear();
    _activePlaybookId = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_playbooksKey);
    await prefs.remove(_activePlaybookKey);
    
    notifyListeners();
  }
  
  Future<void> _savePlaybooks() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_playbooks.map((p) => p.toJson()).toList());
    await prefs.setString(_playbooksKey, json);
  }
  
  Future<void> _saveActivePlaybook() async {
    final prefs = await SharedPreferences.getInstance();
    if (_activePlaybookId != null) {
      await prefs.setString(_activePlaybookKey, _activePlaybookId!);
    } else {
      await prefs.remove(_activePlaybookKey);
    }
  }
  
  /// Get aggregated content from all enabled playbooks
  Future<List<Album>> getAllAlbums({int? limit}) async {
    final albums = <Album>[];
    
    for (final playbook in enabledPlaybooks) {
      try {
        final service = await getServiceForPlaybook(playbook.id);
        if (service != null) {
          final serviceAlbums = await service.getAlbums(limit: limit);
          albums.addAll(serviceAlbums);
        }
      } catch (e) {
        if (kDebugMode) {
          print('PlaybookService: Error getting albums from ${playbook.name}: $e');
        }
      }
    }
    
    return albums;
  }
  
  /// Get aggregated tracks from all enabled playbooks
  Future<List<Track>> getAllTracks({int? limit}) async {
    final tracks = <Track>[];
    
    for (final playbook in enabledPlaybooks) {
      try {
        final service = await getServiceForPlaybook(playbook.id);
        if (service != null) {
          final serviceTracks = await service.getTracks(limit: limit);
          tracks.addAll(serviceTracks);
        }
      } catch (e) {
        if (kDebugMode) {
          print('PlaybookService: Error getting tracks from ${playbook.name}: $e');
        }
      }
    }
    
    return tracks;
  }
  
  /// Search across all enabled playbooks
  Future<SearchResults> searchAll(String query, {int? limit}) async {
    final allAlbums = <Album>[];
    final allArtists = <Artist>[];
    final allTracks = <Track>[];
    final allPlaylists = <Playlist>[];
    
    for (final playbook in enabledPlaybooks) {
      try {
        final service = await getServiceForPlaybook(playbook.id);
        if (service != null) {
          final results = await service.search(query, limit: limit);
          allAlbums.addAll(results.albums);
          allArtists.addAll(results.artists);
          allTracks.addAll(results.tracks);
          allPlaylists.addAll(results.playlists);
        }
      } catch (e) {
        if (kDebugMode) {
          print('PlaybookService: Error searching ${playbook.name}: $e');
        }
      }
    }
    
    return SearchResults(
      albums: allAlbums,
      artists: allArtists,
      tracks: allTracks,
      playlists: allPlaylists,
    );
  }
}
