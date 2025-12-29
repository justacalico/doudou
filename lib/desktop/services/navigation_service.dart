import 'package:flutter/material.dart';
import '../../models/jellyfin_models.dart';

/// Types of detail pages that can be shown
enum DetailPageType { album, artist, playlist }

/// Detail page data
class DetailPageData {
  final DetailPageType type;
  final dynamic data; // Album, Artist, or Playlist

  const DetailPageData({required this.type, required this.data});
}

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  ValueNotifier<int> selectedPageIndex = ValueNotifier<int>(0);
  
  /// Stack of detail pages (for back navigation)
  ValueNotifier<List<DetailPageData>> detailPageStack = ValueNotifier<List<DetailPageData>>([]);

  void navigateToMainPage(int index) {
    // Clear detail stack when navigating to main page
    detailPageStack.value = [];
    selectedPageIndex.value = index;
  }

  void selectPage(int index) {
    // Clear detail stack when selecting a main page
    detailPageStack.value = [];
    selectedPageIndex.value = index;
  }

  /// Navigate to album details
  void navigateToAlbum(Album album) {
    final newStack = List<DetailPageData>.from(detailPageStack.value);
    newStack.add(DetailPageData(type: DetailPageType.album, data: album));
    detailPageStack.value = newStack;
  }

  /// Navigate to artist details
  void navigateToArtist(Artist artist) {
    final newStack = List<DetailPageData>.from(detailPageStack.value);
    newStack.add(DetailPageData(type: DetailPageType.artist, data: artist));
    detailPageStack.value = newStack;
  }

  /// Navigate to playlist details
  void navigateToPlaylist(Playlist playlist) {
    final newStack = List<DetailPageData>.from(detailPageStack.value);
    newStack.add(DetailPageData(type: DetailPageType.playlist, data: playlist));
    detailPageStack.value = newStack;
  }

  /// Go back to previous page
  void goBack() {
    if (detailPageStack.value.isNotEmpty) {
      final newStack = List<DetailPageData>.from(detailPageStack.value);
      newStack.removeLast();
      detailPageStack.value = newStack;
    }
  }

  /// Check if we can go back
  bool get canGoBack => detailPageStack.value.isNotEmpty;

  /// Get current detail page (top of stack)
  DetailPageData? get currentDetailPage => 
      detailPageStack.value.isNotEmpty ? detailPageStack.value.last : null;
}