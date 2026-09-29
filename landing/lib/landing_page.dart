import 'package:flutter/material.dart';

import 'theme/tokens.dart';
import 'widgets/backend_strip.dart';
import 'widgets/download_section.dart';
import 'widgets/faq_section.dart';
import 'widgets/feature_bento.dart';
import 'widgets/hero_section.dart';
import 'widgets/showcase_section.dart';
import 'widgets/site_footer.dart';
import 'widgets/site_nav.dart';
import 'widgets/spec_sheet.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _scroll = ScrollController();
  final _downloadKey = GlobalKey();
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final scrolled = _scroll.offset > 8;
      if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToDownload() {
    final ctx = _downloadKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: Tk.durLong,
      curve: Tk.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tk.paper,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scroll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HeroSection(onDownload: _scrollToDownload),
                const BackendStrip(),
                const ShowcaseSection(
                  title: 'Your server, on every screen.',
                  body:
                      'Point Doudou at Subsonic, Jellyfin, Plex, or YouTube '
                      'Music and the same library follows you from the desk '
                      'to the car to the sofa. The layout adapts to the '
                      'screen; nothing gets cut.',
                  asset: 'assets/screens/desktop.png',
                  alt: 'Doudou library view on desktop',
                ),
                const ShowcaseSection(
                  title: 'It looks like your music.',
                  body:
                      'Colours come from whatever is playing, so a quiet '
                      'record looks quiet and a loud one does not. Synced '
                      'lyrics and a proper queue ride along.',
                  asset: 'assets/screens/albums.png',
                  alt: 'Doudou album grid on Android',
                  flip: true,
                  banded: true,
                  phone: true,
                ),
                const FeatureBento(),
                const SpecSheet(),
                DownloadSection(key: _downloadKey),
                const FaqSection(),
                const SiteFooter(),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: SiteNav(
                scrolled: _scrolled,
                onDownload: _scrollToDownload,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
