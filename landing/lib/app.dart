import 'package:flutter/material.dart';

import 'landing_page.dart';
import 'theme/app_theme.dart';

class DoudouSite extends StatelessWidget {
  const DoudouSite({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doudou',
      debugShowCheckedModeBanner: false,
      theme: buildSiteTheme(),
      home: const LandingPage(),
    );
  }
}
