import 'package:flutter/material.dart';

enum AppShellSection {
  home,
  tracks,
  albums,
  artists,
  playlists,
  downloads,
  favorites,
  settings,
}

class AdaptiveShellState extends ChangeNotifier {
  AdaptiveShellState();

  final PageStorageBucket pageStorageBucket = PageStorageBucket();

  AppShellSection _selectedSection = AppShellSection.home;
  String _trackSearchQuery = '';
  String _albumSearchQuery = '';
  String _artistSearchQuery = '';
  String _playlistSearchQuery = '';

  AppShellSection get selectedSection => _selectedSection;
  String get trackSearchQuery => _trackSearchQuery;
  String get albumSearchQuery => _albumSearchQuery;
  String get artistSearchQuery => _artistSearchQuery;
  String get playlistSearchQuery => _playlistSearchQuery;

  void selectSection(AppShellSection section) {
    if (_selectedSection == section) {
      return;
    }
    _selectedSection = section;
    notifyListeners();
  }

  void setTrackSearchQuery(String query) {
    if (_trackSearchQuery == query) {
      return;
    }
    _trackSearchQuery = query;
    notifyListeners();
  }

  void setAlbumSearchQuery(String query) {
    if (_albumSearchQuery == query) {
      return;
    }
    _albumSearchQuery = query;
    notifyListeners();
  }

  void setArtistSearchQuery(String query) {
    if (_artistSearchQuery == query) {
      return;
    }
    _artistSearchQuery = query;
    notifyListeners();
  }

  void setPlaylistSearchQuery(String query) {
    if (_playlistSearchQuery == query) {
      return;
    }
    _playlistSearchQuery = query;
    notifyListeners();
  }

  int sectionToIndex(AppShellSection section) {
    return AppShellSection.values.indexOf(section);
  }

  AppShellSection indexToSection(int index) {
    if (index < 0 || index >= AppShellSection.values.length) {
      return _selectedSection;
    }
    return AppShellSection.values[index];
  }
}
