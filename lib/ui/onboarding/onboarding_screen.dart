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

/// Returns current theme selection for comparison: 'system' | 'light' | 'dark' | 'oled'.
String _effectiveThemeSelection(AppState appState) {
  if (appState.themeMode == ThemeMode.dark && appState.oledDarkModeEnabled) {
    return 'oled';
  }
  switch (appState.themeMode) {
    case ThemeMode.system:
      return 'system';
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
  }
}

/// Preset accent colors for onboarding (matches settings picker).
const List<Color> _kOnboardingAccentPresets = [
  Colors.purple,
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.red,
  Colors.teal,
];

/// Full-screen onboarding: welcome, then steps for language, theme, accent colour, then Get Started.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0; // 0 = language, 1 = theme, 2 = accent colour

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context);
    final isNarrow = MediaQuery.sizeOf(context).width < 400;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                    l10n.onboardingWelcome,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: DesktopTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.onboardingDescription,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: DesktopTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // Step content
                  if (_step == 0) _buildLanguageStep(context, appState, l10n),
                  if (_step == 1) _buildThemeStep(context, appState, l10n),
                  if (_step == 2) _buildAccentStep(context, appState, l10n, isDark),
                  const SizedBox(height: 40),
                  // Primary action
                  FilledButton(
                    onPressed: () async {
                      if (_step < 2) {
                        setState(() => _step++);
                      } else {
                        await appState.setOnboardingCompleted();
                      }
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
                    child: Text(_step < 2 ? l10n.onboardingContinue : l10n.getStarted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageStep(BuildContext context, AppState appState, AppLocalizations l10n) {
    final currentLocale = appState.locale;
    return _section(
      title: l10n.language,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppDialogOption(
            label: l10n.systemDefault,
            selected: currentLocale == null,
            onTap: () => appState.setLocale(null),
          ),
          ...AppLocalizations.supportedLocales.map(
            (locale) => AppDialogOption(
              label: _languageNameForLocale(locale),
              selected: currentLocale == locale,
              onTap: () => appState.setLocale(locale),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeStep(BuildContext context, AppState appState, AppLocalizations l10n) {
    final current = _effectiveThemeSelection(appState);
    return _section(
      title: l10n.theme,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppDialogOption(
            label: l10n.systemDefault,
            selected: current == 'system',
            onTap: () {
              appState.setThemeMode(ThemeMode.system);
              appState.toggleOledDarkMode(false);
            },
          ),
          AppDialogOption(
            label: l10n.light,
            selected: current == 'light',
            onTap: () {
              appState.setThemeMode(ThemeMode.light);
              appState.toggleOledDarkMode(false);
            },
          ),
          AppDialogOption(
            label: l10n.dark,
            selected: current == 'dark',
            onTap: () {
              appState.setThemeMode(ThemeMode.dark);
              appState.toggleOledDarkMode(false);
            },
          ),
          AppDialogOption(
            label: 'OLED',
            selected: current == 'oled',
            onTap: () {
              appState.setThemeMode(ThemeMode.dark);
              appState.toggleOledDarkMode(true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAccentStep(BuildContext context, AppState appState, AppLocalizations l10n, bool isDark) {
    const swatchSize = 52.0;
    const spacing = 16.0;
    const ringWidth = 2.5;
    final currentColor = appState.accentColor;

    return _section(
      title: l10n.chooseAccentColor,
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: 1,
        children: _kOnboardingAccentPresets.map((color) {
          final selected = color.value == currentColor.value;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => appState.setAccentColor(color),
              borderRadius: BorderRadius.circular(swatchSize / 2 + ringWidth),
              child: Center(
                child: Container(
                  width: swatchSize,
                  height: swatchSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(
                      color: selected
                          ? (isDark ? Colors.white : Theme.of(context).colorScheme.primary)
                          : DesktopTheme.glassBorder,
                      width: selected ? ringWidth : 1,
                    ),
                    boxShadow: [
                      if (selected)
                        BoxShadow(
                          color: (isDark ? Colors.white : Theme.of(context).colorScheme.primary)
                              .withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                    ],
                  ),
                  child: selected
                      ? Center(
                          child: Icon(
                            Icons.check_rounded,
                            color: color.computeLuminance() > 0.4 ? Colors.black87 : Colors.white,
                            size: 26,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: DesktopTheme.textSecondary,
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
            child: child,
          ),
        ),
      ],
    );
  }
}
