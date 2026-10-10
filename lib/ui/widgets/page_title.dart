import 'package:flutter/material.dart';

/// Shared large page header, placed at the top-left of every main page.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
    );
  }
}
