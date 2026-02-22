import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/providers/app_state.dart';
import 'package:doudou/ui/theme.dart';
import 'package:doudou/ui/widgets/apple_dialog.dart';

/// Display names for [AppLocalizations.supportedLocales] (used in onboarding and settings).
const Map<String, String> _onboardingLanguageNames = {
  'en': 'English',
  'ru': 'Русский',
  'zh': '中文',
};

String _languageNameForLocale(Locale locale) {
  return _onboardingLanguageNames[locale.languageCode] ?? locale.languageCode;
}

/// Full-screen onboarding: welcome, short app description, language picker (iOS/macOS style), Get Started.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentLocale = appState.locale;
    final isNarrow = MediaQuery.sizeOf(context).width < 400;

    return Scaffold(
      backgroundColor: DesktopTheme.backgroundDeep,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 24 : 48,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.music_note_rounded,
                    size: 72,
                    color: DesktopTheme.accentPrimary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to Doudou',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: DesktopTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Play your music with ease and style. Connect to Jellyfin, Plex, Subsonic, or use local files and YouTube Music.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: DesktopTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // Language section (iOS/macOS setup style)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'Language',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: DesktopTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: DesktopTheme.backgroundTertiary.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: DesktopTheme.glassBorder,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppleDialogOption(
                            label: 'System default',
                            selected: currentLocale == null,
                            onTap: () => appState.setLocale(null),
                          ),
                          ...AppLocalizations.supportedLocales.map(
                            (locale) => AppleDialogOption(
                              label: _languageNameForLocale(locale),
                              selected: currentLocale == locale,
                              onTap: () => appState.setLocale(locale),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  FilledButton(
                    onPressed: () async {
                      await appState.setOnboardingCompleted();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: DesktopTheme.accentPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    child: const Text('Get Started'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
