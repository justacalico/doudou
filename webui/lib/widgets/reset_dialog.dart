import 'package:flutter/material.dart';

import '../api.dart';

/// Reset database flow: two confirmations with the server password entered
/// in each. Resolves true only once the database was actually wiped.
class ResetDialog extends StatefulWidget {
  const ResetDialog({super.key, required this.api});

  final WebuiApi api;

  static Future<bool> show(BuildContext context, WebuiApi api) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => ResetDialog(api: api),
      ) ??
      false;

  @override
  State<ResetDialog> createState() => _ResetDialogState();
}

class _ResetDialogState extends State<ResetDialog> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  int _step = 0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_first.text.isEmpty) {
      setState(() => _error = 'Enter your password');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.login(_first.text);
      setState(() => _step = 1);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_second.text != _first.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.resetDatabase(_second.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final stepTwo = _step == 1;
    return AlertDialog(
      title: Text(stepTwo ? 'Confirm reset' : 'Reset database'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            stepTwo
                ? 'This wipes every synced box and all hosted backends. '
                    'Connected clients delete the same data on their next '
                    'pull and it cannot be undone.'
                : 'Resetting removes all synced library data and hosted '
                    'backends from this server. Enter your password to '
                    'continue.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: stepTwo ? _second : _first,
            obscureText: true,
            autofocus: true,
            enabled: !_busy,
            onSubmitted: (_) => stepTwo ? _reset() : _continue(),
            decoration: InputDecoration(
              labelText:
                  stepTwo ? 'Enter your password again' : 'Password',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: error)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: stepTwo
              ? FilledButton.styleFrom(
                  backgroundColor: error, foregroundColor: Colors.white)
              : null,
          onPressed: _busy ? null : (stepTwo ? _reset : _continue),
          child: Text(stepTwo ? 'Reset database' : 'Continue'),
        ),
      ],
    );
  }
}
