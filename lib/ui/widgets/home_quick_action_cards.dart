import 'package:flutter/material.dart';

import '/ui/constants/doudou_design.dart';
import '/utils/app_l10n.dart';

class HomeQuickActionCards extends StatelessWidget {
  const HomeQuickActionCards({
    super.key,
    required this.isYouTubeMusic,
    required this.shuffleCount,
    required this.favoriteCount,
    required this.downloadCount,
    required this.onStartSupermix,
    required this.onShuffleAll,
    required this.onShuffleFavorites,
    required this.onShuffleDownloads,
  });

  final bool isYouTubeMusic;
  final int shuffleCount;
  final int favoriteCount;
  final int downloadCount;
  final VoidCallback onStartSupermix;
  final VoidCallback onShuffleAll;
  final VoidCallback onShuffleFavorites;
  final VoidCallback onShuffleDownloads;

  @override
  Widget build(BuildContext context) {
    final cards = <_HomeQuickActionCard>[];

    if (isYouTubeMusic) {
      cards.add(
        _HomeQuickActionCard(
          icon: Icons.auto_awesome,
          label: context.l10n.supermix,
          subtitle: context.l10n.supermixSubtitle,
          onTap: onStartSupermix,
        ),
      );
    } else if (shuffleCount > 0) {
      cards.add(
        _HomeQuickActionCard(
          icon: Icons.shuffle,
          label: context.l10n.shuffleAll,
          subtitle: '$shuffleCount ${context.l10n.songsCount}',
          onTap: onShuffleAll,
        ),
      );
    }

    if (favoriteCount > 0) {
      cards.add(
        _HomeQuickActionCard(
          icon: Icons.favorite,
          label: context.l10n.favorites,
          subtitle: context.l10n.shuffleFavorites,
          onTap: onShuffleFavorites,
        ),
      );
    }

    if (downloadCount > 0) {
      cards.add(
        _HomeQuickActionCard(
          icon: Icons.download,
          label: context.l10n.downloads,
          subtitle: '$downloadCount ${context.l10n.songsCount}',
          onTap: onShuffleDownloads,
        ),
      );
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 24) / cards.length;
        final compact = cardWidth < 180;
        return Row(
          children: List.generate(cards.length * 2 - 1, (index) {
            if (index.isEven) {
              final card = cards[index ~/ 2];
              return Expanded(
                child: _HomeQuickActionCard(
                  icon: card.icon,
                  label: card.label,
                  subtitle: card.subtitle,
                  compact: compact,
                  onTap: card.onTap,
                ),
              );
            } else {
              return const SizedBox(width: 12);
            }
          }),
        );
      },
    );
  }
}

class _HomeQuickActionCard extends StatelessWidget {
  const _HomeQuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.compact = false,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceVariant = onSurface.withValues(alpha: 0.7);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(kDoudouRadiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(kDoudouRadiusCard),
        onTap: onTap,
        child: Container(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 12)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: kDoudouSurface,
            borderRadius: BorderRadius.circular(kDoudouRadiusCard),
            border: Border.all(color: theme.dividerColor, width: 1),
          ),
          child: compact
              ? Center(
                  child: Tooltip(
                    message: label,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kDoudouSurfaceHover,
                        borderRadius:
                            BorderRadius.circular(kDoudouRadiusIconBox),
                      ),
                      child: Icon(icon, color: onSurface, size: 24),
                    ),
                  ),
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kDoudouSurfaceHover,
                        borderRadius:
                            BorderRadius.circular(kDoudouRadiusIconBox),
                      ),
                      child: Icon(icon, color: onSurface, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
