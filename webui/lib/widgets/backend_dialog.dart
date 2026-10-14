import 'package:flutter/material.dart';

import '../models.dart';

/// Add or edit a hosted backend. Returns the filled in [HostedBackend] or
/// null when cancelled. For edits [existing] pre-fills every field.
class BackendDialog extends StatefulWidget {
  const BackendDialog({super.key, this.existing});

  final HostedBackend? existing;

  static Future<HostedBackend?> show(BuildContext context,
          {HostedBackend? existing}) =>
      showDialog<HostedBackend>(
        context: context,
        builder: (_) => BackendDialog(existing: existing),
      );

  @override
  State<BackendDialog> createState() => _BackendDialogState();
}

class _BackendDialogState extends State<BackendDialog> {
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late String _type;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _url = TextEditingController(text: existing?.serverUrl ?? '');
    _username = TextEditingController(text: existing?.username ?? '');
    _password = TextEditingController(text: existing?.password ?? '');
    _type = existing?.type ?? HostedBackend.types.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    if (_type != 'youtubeMusic' && _url.text.trim().isEmpty) {
      setState(() => _error = 'Server URL is required');
      return;
    }
    String? clean(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    Navigator.of(context).pop(HostedBackend(
      id: widget.existing?.id,
      name: name,
      type: _type,
      serverUrl: clean(_url),
      username: clean(_username),
      password: _password.text.isEmpty ? null : _password.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? 'Edit backend' : 'Add backend'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final type in HostedBackend.types)
                  DropdownMenuItem(
                    value: type,
                    child: Text(HostedBackend.typeLabel(type)),
                  ),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            if (_type != 'youtubeMusic') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'https://music.example.com',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _username,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(editing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
