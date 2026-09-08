import 'package:flutter/material.dart';

import '/ui/constants/doudou_design.dart';
import '/utils/app_l10n.dart';

/// Empty state shown on the home tab when the library has no content.
/// [hasServer] decides whether the action sends the user to browse the
/// configured server or to add one first.
class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    super.key,
    required this.hasServer,
    required this.onAction,
  });

  final bool hasServer;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: kDoudouSurfaceHover,
              borderRadius: BorderRadius.circular(kDoudouRadiusIconBox),
            ),
            child: Icon(
              Icons.library_music_outlined,
              size: 36,
              color: onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.addMusicToLibraryHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(color: onSurface),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAction,
            icon: Icon(
              hasServer ? Icons.explore_outlined : Icons.add,
              size: 18,
            ),
            label: Text(
              hasServer ? context.l10n.browseLibrary : context.l10n.addServer,
            ),
          ),
        ],
      ),
    );
  }
}
