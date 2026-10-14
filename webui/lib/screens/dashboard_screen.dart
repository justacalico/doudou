import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../platform/platform.dart';
import '../models.dart';
import '../widgets/backend_dialog.dart';
import '../widgets/password_dialog.dart';

/// The server dashboard: hosted backends, backup/restore and a live log
/// tail, plus account actions in the app bar.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.api, this.onLoggedOut});

  final WebuiApi api;
  final VoidCallback? onLoggedOut;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<HostedBackend> _backends = [];
  List<SyncBox> _boxes = [];
  final List<LogEntry> _logs = [];
  final _logScroll = ScrollController();
  Timer? _logTimer;
  int _lastLogSeq = 0;
  bool _logsPaused = false;
  bool _busy = false;
  String? _notice;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
    _logTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollLogs());
  }

  @override
  void dispose() {
    _logTimer?.cancel();
    _logScroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final results =
          await Future.wait([widget.api.backends(), widget.api.boxes()]);
      if (mounted) {
        setState(() {
          _backends = results[0] as List<HostedBackend>;
          _boxes = results[1] as List<SyncBox>;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (e.isAuthError) {
        widget.onLoggedOut?.call();
        return;
      }
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _pollLogs() async {
    if (_logsPaused || !mounted) return;
    try {
      final page = await widget.api.logs(_lastLogSeq);
      if (!mounted || page.entries.isEmpty) {
        _lastLogSeq = page.latest;
        return;
      }
      final atBottom = !_logScroll.hasClients ||
          _logScroll.position.pixels >=
              _logScroll.position.maxScrollExtent - 40;
      setState(() {
        _logs.addAll(page.entries);
        if (_logs.length > 2000) {
          _logs.removeRange(0, _logs.length - 2000);
        }
        _lastLogSeq = page.latest;
      });
      if (atBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_logScroll.hasClients) {
            _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
          }
        });
      }
    } on ApiException catch (e) {
      if (e.isAuthError) widget.onLoggedOut?.call();
    } catch (_) {}
  }

  Future<void> _mutate(Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _notice = null;
      _error = null;
    });
    try {
      final done = await action();
      if (mounted) setState(() => _notice = done);
    } on ApiException catch (e) {
      if (e.isAuthError) {
        widget.onLoggedOut?.call();
        return;
      }
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _refresh();
  }

  Future<void> _addBackend() async {
    final backend = await BackendDialog.show(context);
    if (backend == null) return;
    await _mutate(() async {
      await widget.api.createBackend(backend);
      return 'Added ${backend.name}';
    });
  }

  Future<void> _editBackend(HostedBackend backend) async {
    final updated = await BackendDialog.show(context, existing: backend);
    if (updated == null) return;
    await _mutate(() async {
      await widget.api.updateBackend(updated);
      return 'Saved ${updated.name}';
    });
  }

  Future<void> _deleteBackend(HostedBackend backend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove backend'),
        content: Text('Remove ${backend.name}? Clients lose it on their '
            'next sync.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _mutate(() async {
      await widget.api.deleteBackend(backend.id!);
      return 'Removed ${backend.name}';
    });
  }

  Future<void> _import() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import backup'),
        content: const Text('Importing replaces the matching server '
            'databases with the backup contents.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Pick file'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final bytes = await pickHmbFile();
    if (bytes == null || !mounted) return;
    await _mutate(() async {
      final res = await widget.api.importHmb(bytes);
      return 'Imported ${res.imported.length} boxes'
          '${res.skipped.isEmpty ? '' : ', skipped ${res.skipped.length} files'}';
    });
  }

  Widget _section(Widget title, List<Widget> children,
      [List<Widget> actions = const []]) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: DefaultTextStyle(
                    style: theme.textTheme.titleMedium!, child: title)),
                ...actions,
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(String type) => switch (type) {
        'youtubeMusic' => Icons.play_circle_outline,
        'jellyfin' => Icons.video_library_outlined,
        'plex' => Icons.movie_outlined,
        _ => Icons.dns_outlined,
      };

  Widget _backendsCard() => _section(
        const Text('Backends'),
        [
          if (_backends.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No backends yet. Backends added here show up on '
                  'every client connected to this server.'),
            )
          else
            for (final backend in _backends)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(_typeIcon(backend.type)),
                title: Text(backend.name),
                subtitle: Text(
                  '${HostedBackend.typeLabel(backend.type)}'
                  '${backend.serverUrl != null ? ' · ${backend.serverUrl}' : ''}',
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Edit',
                      onPressed: _busy ? null : () => _editBackend(backend),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: 'Remove',
                      onPressed: _busy ? null : () => _deleteBackend(backend),
                    ),
                  ],
                ),
              ),
        ],
        [
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _addBackend,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
          ),
        ],
      );

  Widget _boxesCard() => _section(
        const Text('Database'),
        [
          if (_boxes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No synced boxes yet.'),
            )
          else
            for (final box in _boxes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(box.name)),
                    Text('${box.keys} keys · rev ${box.rev}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
        ],
      );

  Widget _backupCard() => _section(
        const Text('Backup'),
        [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _busy
                    ? null
                    : () => _mutate(() async {
                          await widget.api.downloadBackup();
                          return 'Backup downloaded';
                        }),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Download .hmb'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _import,
                icon: const Icon(Icons.upload_outlined, size: 18),
                label: const Text('Import .hmb'),
              ),
            ],
          ),
        ],
      );

  Color _levelColor(String level) => switch (level) {
        'error' => Theme.of(context).colorScheme.error,
        'warn' => Colors.orange,
        _ => Theme.of(context).colorScheme.onSurfaceVariant,
      };

  String _formatTs(int ts) {
    final t = DateTime.fromMillisecondsSinceEpoch(ts);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  Widget _logsCard() => _section(
        const Text('Logs'),
        [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: _logs.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Nothing logged yet.'),
                  )
                : ListView.builder(
                    controller: _logScroll,
                    shrinkWrap: true,
                    itemCount: _logs.length,
                    itemBuilder: (context, i) {
                      final entry = _logs[i];
                      return Text(
                        '${_formatTs(entry.ts)}  ${entry.message}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: _levelColor(entry.level),
                        ),
                      );
                    },
                  ),
          ),
        ],
        [
          IconButton(
            icon: Icon(_logsPaused ? Icons.play_arrow : Icons.pause,
                size: 20),
            tooltip: _logsPaused ? 'Resume' : 'Pause',
            onPressed: () => setState(() => _logsPaused = !_logsPaused),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doudou server'),
        actions: [
          IconButton(
            icon: const Icon(Icons.key_outlined),
            tooltip: 'Change password',
            onPressed: () => PasswordDialog.show(context, widget.api),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () async {
              await widget.api.logout();
              widget.onLoggedOut?.call();
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_notice!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary)),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
              _backendsCard(),
              const SizedBox(height: 16),
              _backupCard(),
              const SizedBox(height: 16),
              _boxesCard(),
              const SizedBox(height: 16),
              _logsCard(),
            ],
          ),
        ),
      ),
    );
  }
}
