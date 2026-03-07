import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/ui/constants/doudou_design.dart';
import '/ui/screens/Search/search_screen_controller.dart';
import '../../../navigator.dart';

class SearchItem extends StatelessWidget {
  const SearchItem({
    super.key,
    required this.queryString,
    required this.isHistoryString,
  });

  final String queryString;
  final bool isHistoryString;

  @override
  Widget build(BuildContext context) {
    final searchScreenController = Get.find<SearchScreenController>();
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(kDoudouRadiusIconBox),
      child: InkWell(
        borderRadius: BorderRadius.circular(kDoudouRadiusIconBox),
        onTap: () {
          ScreenNavigationSetup.pushContentRoute(
              ScreenNavigationSetup.searchResultScreen,
              arguments: queryString);
          searchScreenController.addToHistryQueryList(queryString);
          searchScreenController.hideSuggestions();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kDoudouSurfaceHover,
                  borderRadius:
                      BorderRadius.circular(kDoudouRadiusIconBox),
                ),
                child: Icon(
                  isHistoryString ? Icons.history : Icons.search,
                  size: 20,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  queryString,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isHistoryString)
                IconButton(
                  icon: Icon(Icons.clear, size: 20, color: iconColor),
                  onPressed: () {
                    searchScreenController.removeQueryFromHistory(queryString);
                  },
                  style: IconButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(36, 36),
                  ),
                ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.north_west, size: 20, color: iconColor),
                onPressed: () {
                  searchScreenController.suggestionInput(queryString);
                },
                style: IconButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(36, 36),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
