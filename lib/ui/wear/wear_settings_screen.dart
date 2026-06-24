import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wearable_rotary/wearable_rotary.dart';

import '../../services/wear_comm_service.dart';

/// Settings screen for Wear OS. Allows changing theme and active server.
/// Simple scrollable list optimized for rotary input.
class WearSettingsScreen extends StatefulWidget {
  const WearSettingsScreen({super.key});

  @override
  State<WearSettingsScreen> createState() => _WearSettingsScreenState();
}

class _WearSettingsScreenState extends State<WearSettingsScreen> {
  final _comm = Get.find<WearCommService>();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Rotary input for scrolling
    rotaryEvents.listen((event) {
      if (!_scrollController.hasClients) return;
      final direction = event.direction == RotaryDirection.clockwise ? 40.0 : -40.0;
      _scrollController.animateTo(
        (_scrollController.offset + direction).clamp(
          0,
          _scrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _buildSectionHeader('Theme'),
            _buildThemeOptions(),
            const SizedBox(height: 12),
            _buildSectionHeader('Server'),
            Obx(() => _buildServerList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildThemeOptions() {
    const themes = ['dark', 'oled', 'light'];
    const themeIcons = {
      'dark': Icons.dark_mode,
      'oled': Icons.contrast,
      'light': Icons.light_mode,
    };

    return Obx(() => Column(
          children: themes.map((t) {
            final isActive = _comm.themeType.value == t;
            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Icon(themeIcons[t]!, size: 20),
              title: Text(
                t[0].toUpperCase() + t.substring(1),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              trailing: isActive
                  ? Icon(Icons.check,
                      size: 16, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () => _comm.setTheme(t),
            );
          }).toList(),
        ));
  }

  Widget _buildServerList() {
    final servers = _comm.servers;
    if (servers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No servers configured',
          style: Theme.of(context).textTheme.titleSmall,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: servers.map((s) {
        final id = s['id'] as int? ?? 0;
        final name = s['name']?.toString() ?? 'Unknown';
        final type = s['type']?.toString() ?? '';
        final isActive = id == _comm.activeServerId.value;

        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: Text(
            name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            type,
            style: Theme.of(context).textTheme.titleSmall,
            maxLines: 1,
          ),
          trailing: isActive
              ? Icon(Icons.check,
                  size: 16, color: Theme.of(context).colorScheme.primary)
              : null,
          onTap: () => _comm.setServer(id),
        );
      }).toList(),
    );
  }
}
