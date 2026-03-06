import 'package:flutter/widgets.dart';

enum DoudouLayoutClass {
  compactPhone,
  largePhone,
  tabletPortrait,
  tabletLandscape,
  compactDesktop,
  fullDesktop,
}

class DoudouLayoutInfo {
  const DoudouLayoutInfo({
    required this.size,
    required this.padding,
    required this.layoutClass,
  });

  final Size size;
  final EdgeInsets padding;
  final DoudouLayoutClass layoutClass;

  bool get isPhone =>
      layoutClass == DoudouLayoutClass.compactPhone ||
      layoutClass == DoudouLayoutClass.largePhone;

  bool get isTablet =>
      layoutClass == DoudouLayoutClass.tabletPortrait ||
      layoutClass == DoudouLayoutClass.tabletLandscape;

  bool get isDesktop =>
      layoutClass == DoudouLayoutClass.compactDesktop ||
      layoutClass == DoudouLayoutClass.fullDesktop;

  bool get useBottomNav => isPhone;

  double get contentMaxWidth {
    if (isDesktop) return 1100;
    if (isTablet) return 920;
    return double.infinity;
  }

  EdgeInsets get contentPadding {
    if (isDesktop) {
      return const EdgeInsets.symmetric(horizontal: 28, vertical: 20);
    }
    if (layoutClass == DoudouLayoutClass.tabletLandscape) {
      return const EdgeInsets.symmetric(horizontal: 22, vertical: 18);
    }
    if (layoutClass == DoudouLayoutClass.tabletPortrait) {
      return const EdgeInsets.symmetric(horizontal: 18, vertical: 16);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 14);
  }

  double get miniPlayerHeight {
    switch (layoutClass) {
      case DoudouLayoutClass.compactPhone:
      case DoudouLayoutClass.largePhone:
        return 72;
      case DoudouLayoutClass.tabletPortrait:
      case DoudouLayoutClass.tabletLandscape:
        return 76;
      case DoudouLayoutClass.compactDesktop:
      case DoudouLayoutClass.fullDesktop:
        return 92;
    }
  }
}

class DoudouLayout {
  const DoudouLayout._();

  static DoudouLayoutInfo of(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final w = size.width;
    final h = size.height;
    final isLandscape = w > h;

    final cls = _classify(w, isLandscape);
    return DoudouLayoutInfo(size: size, padding: mq.padding, layoutClass: cls);
  }

  static DoudouLayoutClass _classify(double width, bool isLandscape) {
    if (width < 420) return DoudouLayoutClass.compactPhone;
    if (width < 520) return DoudouLayoutClass.largePhone;
    if (width < 840) {
      return isLandscape
          ? DoudouLayoutClass.tabletLandscape
          : DoudouLayoutClass.tabletPortrait;
    }
    if (width < 1024) return DoudouLayoutClass.tabletLandscape;
    if (width < 1400) return DoudouLayoutClass.compactDesktop;
    return DoudouLayoutClass.fullDesktop;
  }
}

