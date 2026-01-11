import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

/// Apple Music-style section header with optional "See All" button
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  final String seeAllText;

  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.seeAllText = 'See All',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingL,
        AppTheme.spacingXL,
        AppTheme.spacingL,
        AppTheme.spacingM,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: AppTheme.fontSizeTitle2,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary(context),
              letterSpacing: -0.5,
              decoration: TextDecoration.none,
            ),
          ),
          if (onSeeAll != null)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: onSeeAll,
              child: Text(
                seeAllText,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  color: AppTheme.accentPink,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sliver version of section header
class SliverSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  final String seeAllText;

  const SliverSectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.seeAllText = 'See All',
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SectionHeader(
        title: title,
        onSeeAll: onSeeAll,
        seeAllText: seeAllText,
      ),
    );
  }
}
