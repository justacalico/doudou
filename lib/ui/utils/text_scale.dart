import 'package:flutter/widgets.dart';

/// Maximum font scale applied app-wide. Anything higher breaks layouts, but
/// the cap must stay high enough that system accessibility font sizes still
/// take effect for users who rely on them.
const double kMaxAppTextScaleFactor = 1.6;

/// Minimum font scale applied app-wide.
const double kMinAppTextScaleFactor = 1.0;

/// Clamps the ambient [TextScaler] into the range the app layouts support.
TextScaler appTextScaler(TextScaler scaler) => scaler.clamp(
      minScaleFactor: kMinAppTextScaleFactor,
      maxScaleFactor: kMaxAppTextScaleFactor,
    );
