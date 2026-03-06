import 'package:flutter/animation.dart';

class DoudouMotion {
  const DoudouMotion._();

  static const Duration hover = Duration(milliseconds: 90);
  static const Duration press = Duration(milliseconds: 70);
  static const Duration selection = Duration(milliseconds: 140);
  static const Duration contentSwap = Duration(milliseconds: 180);
  static const Duration panel = Duration(milliseconds: 260);
  static const Duration routePush = Duration(milliseconds: 220);
  static const Duration theme = Duration(milliseconds: 260);

  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve decel = Cubic(0.0, 0.0, 0.0, 1.0);
}

