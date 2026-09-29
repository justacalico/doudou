import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '/utils/app_l10n.dart';
import 'common_dialog_widget.dart';

/// Wraps the app root and shows a one-time startup dialog for builds produced
/// from a merge request. The ID and URL are baked in via --dart-define, so the
/// prompt survives merging and stays as proof of the build's source.
class DevMergeRequestWrapper extends StatefulWidget {
  const DevMergeRequestWrapper({
    super.key,
    required this.child,
    this.mergeRequestId = const String.fromEnvironment('MERGE_REQUEST_ID'),
    this.mergeRequestUrl = const String.fromEnvironment('MERGE_REQUEST_URL'),
  });

  final Widget child;
  final String mergeRequestId;
  final String mergeRequestUrl;

  @override
  State<DevMergeRequestWrapper> createState() => _DevMergeRequestWrapperState();
}

class _DevMergeRequestWrapperState extends State<DevMergeRequestWrapper> {
  @override
  void initState() {
    super.initState();
    if (widget.mergeRequestId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showDialog());
    }
  }

  void _showDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DevMergeRequestDialog(
        mergeRequestId: widget.mergeRequestId,
        mergeRequestUrl: widget.mergeRequestUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class DevMergeRequestDialog extends StatelessWidget {
  const DevMergeRequestDialog({
    super.key,
    required this.mergeRequestId,
    required this.mergeRequestUrl,
  });

  final String mergeRequestId;
  final String mergeRequestUrl;

  static bool _isOpenableUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUrl = _isOpenableUrl(mergeRequestUrl);
    final l10n = context.l10n;

    return CommonDialog(
      maxWidth: 420,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.merge_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.devMergeRequestTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasUrl
                  ? l10n.devMergeRequestBody(mergeRequestId, mergeRequestUrl)
                  : l10n.devMergeRequestBodyNoUrl(mergeRequestId),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasUrl) ...[
                  TextButton(
                    onPressed: () => unawaited(
                      Clipboard.setData(ClipboardData(text: mergeRequestUrl)),
                    ),
                    child: Text(l10n.devMergeRequestCopy),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => unawaited(
                      launchUrl(
                        Uri.parse(mergeRequestUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(l10n.devMergeRequestOpen),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(l10n.devMergeRequestClose),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
