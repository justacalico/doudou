part of 'settings_screen_controller.dart';

mixin _SettingsServerMixin on _SettingsScreenControllerBase {
  void addServerWithCredentials(
    ServerType type, {
    String? serverUrl,
    String? username,
    String? password,
  }) {
    String name;
    if (type == ServerType.youtubeMusic) {
      name = _serverTypeLabel(type);
    } else {
      name = serverUrl?.trim().isNotEmpty == true
          ? (serverUrl!
              .replaceFirst(RegExp(r'^https?://'), '')
              .split('/')
              .first)
          : _serverTypeLabel(type);
      final existingOfType = servers.where((s) => s.type == type).length;
      if (existingOfType > 0) name = '$name #${existingOfType + 1}';
    }
    final server = SettingsServer(
      id: DateTime.now().millisecondsSinceEpoch,
      name: name,
      type: type,
      isDefault: false,
      serverUrl: serverUrl?.trim().isEmpty == true ? null : serverUrl?.trim(),
      username: username?.trim().isEmpty == true ? null : username?.trim(),
      password: password?.trim().isEmpty == true ? null : password?.trim(),
    );
    servers.add(server);
    _persistServers();
  }

  void updateServer(
    int id, {
    String? serverUrl,
    String? username,
    String? password,
  }) {
    final idx = servers.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    final s = servers[idx];
    if (s.isDefault || s.isRemote) return;
    servers[idx] = s.copyWith(
      serverUrl: serverUrl ?? s.serverUrl,
      username: username ?? s.username,
      password:
          password != null ? (password.isEmpty ? null : password) : s.password,
    );
    _persistServers();
  }

  void removeServer(int id) {
    if (id == SettingsServer.defaultServerId) return;
    if (allServers.any((s) => s.id == id && s.isRemote)) return;
    servers.removeWhere((s) => s.id == id);
    if (activeServerId.value == id) {
      if (servers.isEmpty) {
        activeServerId.value = null;
      } else {
        final nonDefault =
            servers.firstWhereOrNull((server) => !server.isDefault);
        activeServerId.value = (nonDefault ?? servers.first).id;
      }
    }
    _persistServers();
    _onActiveServerChanged();
  }

  void setActiveServer(int id) {
    if (!allServers.any((s) => s.id == id)) return;
    if (activeServerId.value == id) return;
    activeServerId.value = id;
    setBox.put('activeServerId', id);
    _onActiveServerChanged();
  }

  /// Called when the hosted backend list changes. Cached backends may hold
  /// stale credentials, and the active server may have vanished.
  void onRemoteServersChanged() {
    invalidateBackendCache();
    ensureActiveServerValid();
  }

  /// Picks a fallback when the active server no longer exists, for example
  /// after the sync server removed the remote entry that was selected.
  void ensureActiveServerValid() {
    final id = activeServerId.value;
    if (id != null && allServers.any((s) => s.id == id)) return;
    final nonDefault = servers.firstWhereOrNull((server) => !server.isDefault);
    final next = nonDefault ?? (servers.isEmpty ? null : servers.first);
    if (next == null) {
      if (id == null) return;
      activeServerId.value = null;
      setBox.delete('activeServerId');
    } else {
      activeServerId.value = next.id;
      setBox.put('activeServerId', next.id);
    }
    _onActiveServerChanged();
  }

  String _serverTypeLabel(ServerType type) {
    switch (type) {
      case ServerType.youtubeMusic:
        return AppLocalizations.of(Get.context!)!.youtubeMusic;
      case ServerType.subsonic:
        return AppLocalizations.of(Get.context!)!.subsonic;
      case ServerType.jellyfin:
        return AppLocalizations.of(Get.context!)!.jellyfin;
      case ServerType.plex:
        return AppLocalizations.of(Get.context!)!.plex;
    }
  }

  void invalidateBackendCache() {
    _cachedBackend = null;
    _cachedBackendServerId = null;
    _serverBackendCache.clear();
  }
}
