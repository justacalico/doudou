import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../playback_test_main.dart';

/// Playback test page: select a configured provider and run a test play.
/// Logs (app + player/MPV) are shown in the UI and in the console.
class PlaybackTestPage extends StatefulWidget {
  const PlaybackTestPage({super.key});

  @override
  State<PlaybackTestPage> createState() => _PlaybackTestPageState();
}

class _PlaybackTestPageState extends State<PlaybackTestPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaybackTestState>().loadServers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playback Test (non-YT-Music)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<PlaybackTestState>().loadServers();
            },
            tooltip: 'Reload servers',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Consumer<PlaybackTestState>(
          builder: (context, state, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Select a provider already set up in the main app, then tap Test to play one track. '
                  'Use this to debug non–YouTube Music playback (e.g. Jellyfin, Navidrome, Plex) on Linux.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Map<String, String>>(
                  value: state.selectedServer,
                  decoration: const InputDecoration(
                    labelText: 'Provider',
                    border: OutlineInputBorder(),
                  ),
                  items: state.servers
                      .map((s) => DropdownMenuItem<Map<String, String>>(
                            value: s,
                            child: Text(_serverLabel(s)),
                          ))
                      .toList(),
                  onChanged: state.loading
                      ? null
                      : (v) {
                          state.selectedServer = v;
                        },
                ),
                const SizedBox(height: 12),
                if (state.status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      state.status,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: state.loading || state.selectedServer == null
                          ? null
                          : () async {
                              await state.testPlayback(state.selectedServer!);
                            },
                      icon: state.loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(state.loading ? 'Testing…' : 'Test play'),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: state.loading ? null : () => state.clearLogs(),
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear logs'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Logs (also in console; [Playback] and MPV/player messages appear there)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade900
                          : Colors.grey.shade100,
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: state.logs.length,
                      itemBuilder: (context, index) {
                        return SelectableText(
                          state.logs[index],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _serverLabel(Map<String, String> s) {
  final type = s['type'] ?? '?';
  final name = s['displayName'];
  final url = s['url'] ?? '';
  if (name != null && name.isNotEmpty) return '$type: $name';
  if (url.isNotEmpty) return '$type: $url';
  return type;
}
