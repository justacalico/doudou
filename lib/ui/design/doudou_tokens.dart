import 'package:flutter/widgets.dart';

class DoudouSpace {
  const DoudouSpace._();

  static const double s2 = 2;
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
}

class DoudouRadii {
  const DoudouRadii._();

  static const BorderRadius r8 = BorderRadius.all(Radius.circular(8));
  static const BorderRadius r10 = BorderRadius.all(Radius.circular(10));
  static const BorderRadius r12 = BorderRadius.all(Radius.circular(12));
  static const BorderRadius r16 = BorderRadius.all(Radius.circular(16));
  static const BorderRadius r20 = BorderRadius.all(Radius.circular(20));
  static const BorderRadius r24 = BorderRadius.all(Radius.circular(24));
}

class DoudouIconSize {
  const DoudouIconSize._();

  static const double nav = 20;
  static const double inline = 18;
  static const double action = 20;
  static const double transport = 22;
  static const double transportHero = 32;
}

class DoudouType {
  const DoudouType._();

  static TextStyle _base({
    required double size,
    required FontWeight weight,
    double height = 1.2,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static final TextStyle display = _base(
    size: 34,
    weight: FontWeight.w700,
    height: 1.05,
    letterSpacing: -0.4,
  );

  static final TextStyle hero = _base(
    size: 28,
    weight: FontWeight.w700,
    height: 1.08,
    letterSpacing: -0.2,
  );

  static final TextStyle pageTitle = _base(
    size: 20,
    weight: FontWeight.w700,
    height: 1.15,
  );

  static final TextStyle sectionTitle = _base(
    size: 15,
    weight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.1,
  );

  static final TextStyle bodyStrong = _base(
    size: 14,
    weight: FontWeight.w600,
    height: 1.25,
  );

  static final TextStyle body = _base(
    size: 14,
    weight: FontWeight.w400,
    height: 1.25,
  );

  static final TextStyle meta = _base(
    size: 12,
    weight: FontWeight.w500,
    height: 1.2,
  );

  static final TextStyle caption = _base(
    size: 11,
    weight: FontWeight.w500,
    height: 1.2,
  );

  static final TextStyle controlLabel = _base(
    size: 12,
    weight: FontWeight.w600,
    height: 1.1,
    letterSpacing: 0.1,
  );

  static final TextStyle navLabel = _base(
    size: 12,
    weight: FontWeight.w600,
    height: 1.1,
    letterSpacing: 0.1,
  );

  static final TextStyle overline = _base(
    size: 10,
    weight: FontWeight.w600,
    height: 1.1,
    letterSpacing: 0.8,
  );
}

