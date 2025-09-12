import 'package:flutter/foundation.dart';
import '../../models/jellyfin_models.dart';
import '../jellyfin_service.dart';

/// Handles radio mode functionality for endless playback by finding similar tracks
class AudioRadioMode {
  final JellyfinService _jellyfinService;
  
  AudioRadioMode(this._jellyfinService);
  
  /// Get similar tracks for radio mode based on current track
  Future<List<Track>> getSimilarTracks(Track currentTrack, List<Track> recentPlaylist, {int limit = 10}) async {
    try {
      // Get all tracks from the service
      final allTracks = await _jellyfinService.getAllTracks();
      
      // Filter out tracks we've already played recently (last 20 tracks)
      final recentTrackIds = recentPlaylist.take(20).map((t) => t.id).toSet();
      final availableTracks = allTracks.where((track) => 
        track.id != currentTrack.id && !recentTrackIds.contains(track.id)
      ).toList();

      // Priority matching: same artist tracks first
      final sameArtistTracks = availableTracks.where((track) => 
        track.artistName == currentTrack.artistName && track.artistName != null
      ).toList();

      // Secondary matching: same album tracks
      final sameAlbumTracks = availableTracks.where((track) => 
        track.artistName != currentTrack.artistName &&
        track.albumName == currentTrack.albumName && track.albumName != null
      ).toList();

      // Tertiary matching: tracks from same album ID
      final similarTracks = availableTracks.where((track) => 
        track.artistName != currentTrack.artistName &&
        track.albumName != currentTrack.albumName &&
        track.albumId == currentTrack.albumId && track.albumId != null
      ).toList();

      // Shuffle each category to avoid predictable ordering
      sameArtistTracks.shuffle();
      sameAlbumTracks.shuffle();
      similarTracks.shuffle();

      // Combine results with weighted selection
      final result = <Track>[];
      
      // Add up to 50% same artist tracks
      final sameArtistCount = (limit * 0.5).round();
      result.addAll(sameArtistTracks.take(sameArtistCount));
      
      // Add up to 30% same album tracks
      final sameAlbumCount = ((limit - result.length) * 0.6).round();
      result.addAll(sameAlbumTracks.take(sameAlbumCount));
      
      // Fill remaining with similar tracks
      final remainingCount = limit - result.length;
      result.addAll(similarTracks.take(remainingCount));

      // If we still don't have enough, add random tracks
      if (result.length < limit) {
        final remainingAvailable = availableTracks.where((track) => 
          !result.any((r) => r.id == track.id)
        ).toList();
        remainingAvailable.shuffle();
        result.addAll(remainingAvailable.take(limit - result.length));
      }

      if (kDebugMode) {
        print('Generated ${result.length} similar tracks for radio mode');
        print('Same artist: ${sameArtistTracks.length}, Same album: ${sameAlbumTracks.length}, Similar: ${similarTracks.length}');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting similar tracks for radio mode: $e');
      }
      return [];
    }
  }
}
