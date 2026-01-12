import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Response from the OpenLyst API for the latest version
class UpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final bool updateAvailable;
  final String? releaseDate;
  final String? changelog;
  final Map<String, String>? downloadLinks;

  UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.updateAvailable,
    this.releaseDate,
    this.changelog,
    this.downloadLinks,
  });
}

/// Service to check for app updates using the OpenLyst API
class UpdateService {
  static const String _baseUrl = 'https://openlyst.ink/api/v1';
  static const String _appSlug = 'doudou';

  /// Check if an update is available
  static Future<UpdateInfo> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(
        Uri.parse('$_baseUrl/apps/$_appSlug/latest'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Doudou/$currentVersion',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['success'] == true && json['data'] != null) {
          final data = json['data'];
          final latestVersion = data['version'] as String? ?? currentVersion;
          final releaseDate = data['date'] as String?;
          final changelog = data['localizedDescription'] as String?;

          // Parse download links from platformInstall
          Map<String, String>? downloadLinks;
          if (data['platformInstall'] != null) {
            downloadLinks = {};
            final platformInstall = data['platformInstall'] as Map<String, dynamic>;
            for (final entry in platformInstall.entries) {
              if (entry.value is String) {
                downloadLinks[entry.key] = entry.value as String;
              }
            }
          }

          final updateAvailable = _isNewerVersion(latestVersion, currentVersion);

          return UpdateInfo(
            latestVersion: latestVersion,
            currentVersion: currentVersion,
            updateAvailable: updateAvailable,
            releaseDate: releaseDate,
            changelog: changelog,
            downloadLinks: downloadLinks,
          );
        }
      }

      // If API call fails, return current info with no update
      return UpdateInfo(
        latestVersion: currentVersion,
        currentVersion: currentVersion,
        updateAvailable: false,
      );
    } catch (e) {
      // On error, return current version info
      final packageInfo = await PackageInfo.fromPlatform();
      return UpdateInfo(
        latestVersion: packageInfo.version,
        currentVersion: packageInfo.version,
        updateAvailable: false,
      );
    }
  }

  /// Compare version strings to determine if latest is newer than current
  /// Supports semver format: major.minor.patch
  static bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      // Pad with zeros if needed
      while (latestParts.length < 3) {
        latestParts.add(0);
      }
      while (currentParts.length < 3) {
        currentParts.add(0);
      }

      // Compare major, minor, patch
      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }

      return false; // Same version
    } catch (e) {
      return false;
    }
  }
}
