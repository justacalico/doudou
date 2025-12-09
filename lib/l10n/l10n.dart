import 'package:flutter/widgets.dart';
import 'app_localizations.dart';

/// Extension on BuildContext to easily access AppLocalizations.
/// 
/// Usage:
/// ```dart
/// // Instead of:
/// final l10n = AppLocalizations.of(context);
/// 
/// // You can use:
/// final l10n = context.l10n;
/// ```
extension AppLocalizationsX on BuildContext {
  /// Get the AppLocalizations instance for the current context.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
