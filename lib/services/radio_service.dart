import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';

import '../utils/helper.dart';
import '../utils/queue_shuffler.dart';
import 'music_service.dart';

/// Builds YouTube Music style radio queues that branch out instead of looping.
///
/// A plain single-seed radio (the `RDAMVM<videoId>` playlist) is fairly
/// deterministic, so after the first page we rotate through a growing pool of
/// seeds: the initial song plus songs that have already been recommended.
/// Each continuation page is fetched from a different seed, the results are
/// merged, shuffled, and filtered against everything already served. This
/// mirrors how YouTube Music keeps radio fresh by blending multiple related
/// signals rather than following one playlist forever.
class RadioService {
  RadioService({MusicServices? musicServices})
      : _musicServices = musicServices ?? Get.find<MusicServices>();

  final MusicServices _musicServices;
  final Random _random = Random();

  static const _initialLimit = 24;
  static const _continuationLimit = 25;
  static const _maxSeedAttempts = 3;
  static const _seedPoolMaxSize = 50;
  static const _newSeedsPerPage = 5;

  final List<String> _seedPool = [];
  int _seedCursor = 0;
  final Set<String> _servedIds = {};
  final Map<String, dynamic> _continuations = {};
  String? _playlistSeedId;

  /// True when the current radio was started from a playlist id rather than a
  /// single song. Playlist radios are passed through directly because they
  /// already encode a mix.
  bool get isPlaylistBased => _playlistSeedId != null;

  /// The last continuation token that was used, mostly for diagnostics.
  String? get lastContinuationToken {
    if (_playlistSeedId != null) return _continuations[_playlistSeedId];
    if (_seedPool.isEmpty) return null;
    return _continuations[_seedPool.last];
  }

  /// Starts a fresh song-based radio. [seedId] is the initial seed and
  /// [excludeIds] are ids that should never be returned (e.g. the seed itself).
  void initFromSeed(String seedId, {Set<String>? excludeIds}) {
    _playlistSeedId = null;
    _seedPool.clear();
    _continuations.clear();
    _servedIds.clear();
    if (excludeIds != null) _servedIds.addAll(excludeIds);
    _seedPool.add(seedId);
    _seedCursor = 0;
  }

  /// Starts a fresh playlist-based radio.
  void initFromPlaylist(String playlistId, {Set<String>? excludeIds}) {
    _playlistSeedId = playlistId;
    _seedPool.clear();
    _continuations.clear();
    _servedIds.clear();
    if (excludeIds != null) _servedIds.addAll(excludeIds);
    _seedCursor = 0;
  }

  /// Marks ids as already served so they are not returned again.
  void markServed(Iterable<String> ids) {
    _servedIds.addAll(ids.where((id) => id.isNotEmpty));
  }

  /// Fetches the first page of the radio.
  Future<List<MediaItem>> fetchInitial({int? limit}) async {
    if (_playlistSeedId != null) {
      return _fetchPlaylistRadio(limit: limit);
    }
    if (_seedPool.isEmpty) return [];
    return _fetchFromSeed(_seedPool.first, limit: limit);
  }

  /// Fetches the next page, rotating through seeds and deduplicating against
  /// everything already served.
  Future<List<MediaItem>> fetchMore({int? limit, Set<String>? excludeIds}) async {
    if (_playlistSeedId != null) {
      return _fetchPlaylistRadio(limit: limit, excludeIds: excludeIds);
    }
    return _fetchMultiSeed(limit: limit, excludeIds: excludeIds);
  }

  Future<List<MediaItem>> _fetchPlaylistRadio(
      {int? limit, Set<String>? excludeIds}) async {
    final playlistSeedId = _playlistSeedId;
    if (playlistSeedId == null) return [];
    try {
      final content = await _musicServices.getWatchPlaylist(
          playlistId: playlistSeedId,
          radio: true,
          limit: limit ?? _continuationLimit,
          additionalParamsNext: _continuations[playlistSeedId]);
      _continuations[playlistSeedId] = content['additionalParamsForNext'];
      final tracks = List<MediaItem>.from(content['tracks'] ?? []);
      final fresh = _filterFresh(tracks, excludeIds: excludeIds);
      _servedIds.addAll(fresh.map((t) => t.id));
      return fresh;
    } catch (e, st) {
      printWarning(
          '[RECOVERABLE][opId=radio.playlist] Playlist radio fetch failed: $e\n$st');
      return [];
    }
  }

  Future<List<MediaItem>> _fetchFromSeed(String seedId, {int? limit}) async {
    try {
      final content = await _musicServices.getWatchPlaylist(
          videoId: seedId,
          radio: true,
          limit: limit ?? _initialLimit,
          additionalParamsNext: _continuations[seedId]);
      _continuations[seedId] = content['additionalParamsForNext'];
      final tracks = List<MediaItem>.from(content['tracks'] ?? []);
      return _filterFresh(tracks);
    } catch (e, st) {
      printWarning(
          '[RECOVERABLE][opId=radio.seed] Radio fetch failed for seed $seedId: $e\n$st');
      return [];
    }
  }

  Future<List<MediaItem>> _fetchMultiSeed(
      {int? limit, Set<String>? excludeIds}) async {
    final excluded = {..._servedIds, ...(excludeIds ?? {})};
    final target = limit ?? _continuationLimit;
    final merged = <MediaItem>[];
    final seen = <String>{};

    for (var attempt = 0;
        attempt < _maxSeedAttempts && _seedPool.isNotEmpty;
        attempt++) {
      final seedId = _nextSeed();
      final tracks = await _fetchFromSeed(seedId, limit: target);
      final fresh = tracks.where((t) {
        if (t.id.isEmpty) return false;
        if (excluded.contains(t.id)) return false;
        return seen.add(t.id);
      }).toList();
      merged.addAll(fresh);
      if (merged.length >= target) break;
    }

    final result = merged.take(target).toList();
    _servedIds.addAll(result.map((t) => t.id));
    _addSeeds(result.map((t) => t.id));
    return shuffledSongs(result, random: _random);
  }

  String _nextSeed() {
    final seedId = _seedPool[_seedCursor % _seedPool.length];
    _seedCursor++;
    return seedId;
  }

  void _addSeeds(Iterable<String> ids) {
    final newSeeds = ids.where((id) => id.isNotEmpty && !_seedPool.contains(id));
    for (final id in newSeeds.take(_newSeedsPerPage)) {
      _seedPool.add(id);
    }
    if (_seedPool.length > _seedPoolMaxSize) {
      _seedPool.removeRange(0, _seedPool.length - _seedPoolMaxSize);
      _seedCursor %= _seedPool.length;
    }
  }

  List<MediaItem> _filterFresh(List<MediaItem> tracks,
      {Set<String>? excludeIds}) {
    final excluded = {..._servedIds, ...(excludeIds ?? {})};
    final seen = <String>{};
    return tracks.where((t) {
      if (t.id.isEmpty) return false;
      if (excluded.contains(t.id)) return false;
      return seen.add(t.id);
    }).toList();
  }
}
