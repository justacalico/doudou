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

/// App-wide navigation: main page index and detail overlay stack.
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  ValueNotifier<int> selectedPageIndex = ValueNotifier<int>(0);

  ValueNotifier<List<DetailPageData>> detailPageStack =
      ValueNotifier<List<DetailPageData>>([]);

  void navigateToMainPage(int index) {
    detailPageStack.value = [];
    selectedPageIndex.value = index;
  }

  void selectPage(int index) {
    detailPageStack.value = [];
    selectedPageIndex.value = index;
  }

  void navigateToAlbum(Album album) {
    final newStack = List<DetailPageData>.from(detailPageStack.value);
    newStack.add(DetailPageData(type: DetailPageType.album, data: album));
    detailPageStack.value = newStack;
  }

  void navigateToArtist(Artist artist) {
    final newStack = List<DetailPageData>.from(detailPageStack.value);
    newStack.add(DetailPageData(type: DetailPageType.artist, data: artist));
    detailPageStack.value = newStack;
  }

  void navigateToPlaylist(Playlist playlist) {
    final newStack = List<DetailPageData>.from(detailPageStack.value);
    newStack.add(DetailPageData(type: DetailPageType.playlist, data: playlist));
    detailPageStack.value = newStack;
  }

  void goBack() {
    if (detailPageStack.value.isNotEmpty) {
      final newStack = List<DetailPageData>.from(detailPageStack.value);
      newStack.removeLast();
      detailPageStack.value = newStack;
    }
  }

  bool get canGoBack => detailPageStack.value.isNotEmpty;

  DetailPageData? get currentDetailPage =>
      detailPageStack.value.isNotEmpty ? detailPageStack.value.last : null;
}
