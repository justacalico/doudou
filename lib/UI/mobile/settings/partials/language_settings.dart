import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/app_state.dart';
import '../../../../l10n/app_localizations.dart';

/// A widget that displays language selection settings.
/// This can be used in both mobile (Cupertino) and desktop (Material) settings screens.
class LanguageSettingsSection extends StatelessWidget {
  const LanguageSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.12),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _buildSectionHeader(l10n.language),
                _buildLanguageTile(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageTile(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context);

    // Get current language display name
    final currentLocale = appState.locale;
    final currentLanguage = currentLocale != null
        ? _getLanguageName(currentLocale)
        : l10n.systemLanguage;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _showLanguageSelector(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                CupertinoIcons.globe,
                color: Color(0xFF8B5CF6),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.selectLanguage,
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currentLanguage,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: Colors.white.withOpacity(0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    final appState = context.read<AppState>();
    final l10n = AppLocalizations.of(context);

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: Text(l10n.selectLanguage),
          actions: [
            // System language option
            CupertinoActionSheetAction(
              onPressed: () {
                appState.setLocale(null);
                Navigator.pop(context);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.systemLanguage),
                  if (appState.locale == null) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      CupertinoIcons.checkmark,
                      color: Color(0xFFEC4899),
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
            // Supported languages from AppLocalizations
            ...AppLocalizations.supportedLocales.map((locale) {
              final isSelected =
                  appState.locale?.languageCode == locale.languageCode &&
                  (appState.locale?.countryCode == locale.countryCode ||
                      (appState.locale?.countryCode == null &&
                          locale.countryCode == null));

              return CupertinoActionSheetAction(
                onPressed: () {
                  appState.setLocale(locale);
                  Navigator.pop(context);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_getLanguageName(locale)),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        CupertinoIcons.checkmark,
                        color: Color(0xFFEC4899),
                        size: 20,
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        );
      },
    );
  }

  /// Get the display name for a locale
  String _getLanguageName(Locale locale) {
    // Map of language codes to their native names
    const languageNames = {
      'en': 'English',
      'es': 'Español',
      'fr': 'Français',
      'de': 'Deutsch',
      'it': 'Italiano',
      'pt': 'Português',
      'ru': 'Русский',
      'zh': '中文',
      'ja': '日本語',
      'ko': '한국어',
      'ar': 'العربية',
      'hi': 'हिन्दी',
      'nl': 'Nederlands',
      'pl': 'Polski',
      'tr': 'Türkçe',
      'vi': 'Tiếng Việt',
      'th': 'ไทย',
      'id': 'Indonesia',
      'ms': 'Melayu',
      'uk': 'Українська',
      'cs': 'Čeština',
      'sv': 'Svenska',
      'da': 'Dansk',
      'fi': 'Suomi',
      'no': 'Norsk',
      'he': 'עברית',
      'el': 'Ελληνικά',
      'ro': 'Română',
      'hu': 'Magyar',
      'sk': 'Slovenčina',
      'bg': 'Български',
      'hr': 'Hrvatski',
      'sr': 'Српски',
      'sl': 'Slovenščina',
      'et': 'Eesti',
      'lv': 'Latviešu',
      'lt': 'Lietuvių',
    };

    final baseName = languageNames[locale.languageCode] ?? locale.languageCode;

    // Add country code if present for disambiguation
    if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
      return '$baseName (${locale.countryCode})';
    }

    return baseName;
  }
}
