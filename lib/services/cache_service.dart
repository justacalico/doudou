import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/jellyfin_models.dart';

class CacheService {
  static CacheService? _instance;
  static CacheService get instance => _instance ??= CacheService._();
  
  CacheService._();
  
  Database? _database;
  SharedPreferences? _prefs;
  
  // Cache duration constants
  static const Duration _albumsCacheDuration = Duration(hours: 12);
  static const Duration _artistsCacheDuration = Duration(hours: 12);
  static const Duration _tracksCacheDuration = Duration(hours: 6);
  static const Duration _playlistsCacheDuration = Duration(hours: 2);
  
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _initDatabase();
  }
  
  Future<void> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'doudou_cache.db');
    
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Albums cache table
        await db.execute('''
          CREATE TABLE albums_cache (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
        
        // Artists cache table
        await db.execute('''
          CREATE TABLE artists_cache (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
        
        // Tracks cache table
        await db.execute('''
          CREATE TABLE tracks_cache (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
        
        // Playlists cache table
        await db.execute('''
          CREATE TABLE playlists_cache (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
        
        // Album tracks cache table
        await db.execute('''
          CREATE TABLE album_tracks_cache (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
        
        // Playlist tracks cache table
        await db.execute('''
          CREATE TABLE playlist_tracks_cache (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
        
        // Favorites cache table
        await db.execute('''
          CREATE TABLE favorites_cache (
            key TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
        
        if (kDebugMode) {
          print('Cache database initialized');
        }
      },
    );
  }
  
  // Generic cache methods
  Future<void> _setCache(String table, String key, Map<String, dynamic> data, {Duration? duration}) async {
    if (_database == null) return;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final dataJson = jsonEncode(data);
    
    await _database!.insert(
      table,
      {
        'id': key,
        'data': dataJson,
        'timestamp': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    if (kDebugMode) {
      print('Cached $key in $table');
    }
  }
  
  Future<Map<String, dynamic>?> _getCache(String table, String key, Duration maxAge) async {
    if (_database == null) return null;
    
    final result = await _database!.query(
      table,
      where: 'id = ?',
      whereArgs: [key],
      limit: 1,
    );
    
    if (result.isEmpty) return null;
    
    final row = result.first;
    final timestamp = row['timestamp'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Check if cache is still valid
    if (now - timestamp > maxAge.inMilliseconds) {
      // Cache expired, remove it
      await _database!.delete(table, where: 'id = ?', whereArgs: [key]);
      return null;
    }
    
    final dataJson = row['data'] as String;
    return jsonDecode(dataJson) as Map<String, dynamic>;
  }
  
  Future<void> _clearExpiredCache(String table, Duration maxAge) async {
    if (_database == null) return;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiredThreshold = now - maxAge.inMilliseconds;
    
    await _database!.delete(
      table,
      where: 'timestamp < ?',
      whereArgs: [expiredThreshold],
    );
  }
  
  // Albums caching
  Future<void> cacheAlbums(List<Album> albums) async {
    final data = {'albums': albums.map((a) => a.toJson()).toList()};
    await _setCache('albums_cache', 'all_albums', data, duration: _albumsCacheDuration);
  }
  
  Future<List<Album>?> getCachedAlbums() async {
    final data = await _getCache('albums_cache', 'all_albums', _albumsCacheDuration);
    if (data == null) return null;
    
    final albumsJson = data['albums'] as List;
    return albumsJson.map((json) => Album.fromJson(json)).toList();
  }
  
  // Artists caching
  Future<void> cacheArtists(List<Artist> artists) async {
    final data = {'artists': artists.map((a) => a.toJson()).toList()};
    await _setCache('artists_cache', 'all_artists', data, duration: _artistsCacheDuration);
  }
  
  Future<List<Artist>?> getCachedArtists() async {
    final data = await _getCache('artists_cache', 'all_artists', _artistsCacheDuration);
    if (data == null) return null;
    
    final artistsJson = data['artists'] as List;
    return artistsJson.map((json) => Artist.fromJson(json)).toList();
  }
  
  // Tracks caching
  Future<void> cacheTracks(List<Track> tracks) async {
    final data = {'tracks': tracks.map((t) => t.toJson()).toList()};
    await _setCache('tracks_cache', 'all_tracks', data, duration: _tracksCacheDuration);
  }
  
  Future<List<Track>?> getCachedTracks() async {
    final data = await _getCache('tracks_cache', 'all_tracks', _tracksCacheDuration);
    if (data == null) return null;
    
    final tracksJson = data['tracks'] as List;
    return tracksJson.map((json) => Track.fromJson(json)).toList();
  }
  
  // Playlists caching
  Future<void> cachePlaylists(List<Playlist> playlists) async {
    final data = {'playlists': playlists.map((p) => p.toJson()).toList()};
    await _setCache('playlists_cache', 'all_playlists', data, duration: _playlistsCacheDuration);
  }
  
  Future<List<Playlist>?> getCachedPlaylists() async {
    final data = await _getCache('playlists_cache', 'all_playlists', _playlistsCacheDuration);
    if (data == null) return null;
    
    final playlistsJson = data['playlists'] as List;
    return playlistsJson.map((json) => Playlist.fromJson(json)).toList();
  }
  
  // Album tracks caching
  Future<void> cacheAlbumTracks(String albumId, List<Track> tracks) async {
    final data = {'tracks': tracks.map((t) => t.toJson()).toList()};
    await _setCache('album_tracks_cache', albumId, data, duration: _tracksCacheDuration);
  }
  
  Future<List<Track>?> getCachedAlbumTracks(String albumId) async {
    final data = await _getCache('album_tracks_cache', albumId, _tracksCacheDuration);
    if (data == null) return null;
    
    final tracksJson = data['tracks'] as List;
    return tracksJson.map((json) => Track.fromJson(json)).toList();
  }
  
  // Playlist tracks caching
  Future<void> cachePlaylistTracks(String playlistId, List<Track> tracks) async {
    final data = {'tracks': tracks.map((t) => t.toJson()).toList()};
    await _setCache('playlist_tracks_cache', playlistId, data, duration: _tracksCacheDuration);
  }
  
  Future<List<Track>?> getCachedPlaylistTracks(String playlistId) async {
    final data = await _getCache('playlist_tracks_cache', playlistId, _tracksCacheDuration);
    if (data == null) return null;
    
    final tracksJson = data['tracks'] as List;
    return tracksJson.map((json) => Track.fromJson(json)).toList();
  }
  
  // Favorites caching
  Future<void> cacheFavorites(List<Track> favorites) async {
    final data = {'favorites': favorites.map((t) => t.toJson()).toList()};
    await _setCache('favorites_cache', 'all_favorites', data, duration: _tracksCacheDuration);
  }
  
  Future<List<Track>?> getCachedFavorites() async {
    final data = await _getCache('favorites_cache', 'all_favorites', _tracksCacheDuration);
    if (data == null) return null;
    
    final favoritesJson = data['favorites'] as List;
    return favoritesJson.map((json) => Track.fromJson(json)).toList();
  }
  
  // Preference-based caching for simple data
  Future<void> setCacheTimestamp(String key) async {
    await _prefs?.setInt('cache_timestamp_$key', DateTime.now().millisecondsSinceEpoch);
  }
  
  bool isCacheValid(String key, Duration maxAge) {
    final timestamp = _prefs?.getInt('cache_timestamp_$key');
    if (timestamp == null) return false;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - timestamp) < maxAge.inMilliseconds;
  }
  
  // Clear specific cache
  Future<void> clearAlbumsCache() async {
    await _database?.delete('albums_cache');
  }
  
  Future<void> clearArtistsCache() async {
    await _database?.delete('artists_cache');
  }
  
  Future<void> clearTracksCache() async {
    await _database?.delete('tracks_cache');
  }
  
  Future<void> clearPlaylistsCache() async {
    await _database?.delete('playlists_cache');
  }
  
  Future<void> clearFavoritesCache() async {
    await _database?.delete('favorites_cache');
  }
  
  // Clear all cache
  Future<void> clearAllCache() async {
    if (_database == null) return;
    
    await Future.wait([
      _database!.delete('albums_cache'),
      _database!.delete('artists_cache'),
      _database!.delete('tracks_cache'),
      _database!.delete('playlists_cache'),
      _database!.delete('album_tracks_cache'),
      _database!.delete('playlist_tracks_cache'),
      _database!.delete('favorites_cache'),
    ]);
    
    if (kDebugMode) {
      print('All cache cleared');
    }
  }
  
  // Cleanup expired cache entries
  Future<void> cleanupExpiredCache() async {
    await Future.wait([
      _clearExpiredCache('albums_cache', _albumsCacheDuration),
      _clearExpiredCache('artists_cache', _artistsCacheDuration),
      _clearExpiredCache('tracks_cache', _tracksCacheDuration),
      _clearExpiredCache('playlists_cache', _playlistsCacheDuration),
      _clearExpiredCache('album_tracks_cache', _tracksCacheDuration),
      _clearExpiredCache('playlist_tracks_cache', _tracksCacheDuration),
      _clearExpiredCache('favorites_cache', _tracksCacheDuration),
    ]);
    
    if (kDebugMode) {
      print('Expired cache entries cleaned up');
    }
  }
  
  // Get cache stats
  Future<Map<String, int>> getCacheStats() async {
    if (_database == null) return {};
    
    final stats = <String, int>{};
    
    final tables = [
      'albums_cache',
      'artists_cache', 
      'tracks_cache',
      'playlists_cache',
      'album_tracks_cache',
      'playlist_tracks_cache',
      'favorites_cache',
    ];
    
    for (final table in tables) {
      final result = await _database!.rawQuery('SELECT COUNT(*) as count FROM $table');
      stats[table] = result.first['count'] as int;
    }
    
    return stats;
  }
  
  void dispose() {
    _database?.close();
  }
}
