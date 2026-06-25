import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wearable_rotary/wearable_rotary.dart';

import '../../services/wear_comm_service.dart';

/// Settings screen for Wear OS. Allows changing active server and shows about info.
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
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildSectionHeader('Server'),
                  Obx(() => _buildServerList()),
                  const SizedBox(height: 12),
                  _buildSectionHeader('About'),
                  _buildAboutSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.arrow_back, size: 20),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Settings',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
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

  Widget _buildAboutSection() {
    return Obx(() {
      final name = 'Doudou';
      final version = _comm.appVersion.value;
      final build = _comm.appBuildNumber.value;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (name.isNotEmpty)
              Text(
                name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            if (version.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Version $version${build.isNotEmpty ? ' ($build)' : ''}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.phone_android,
                    size: 14, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'More settings are available on your phone',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
