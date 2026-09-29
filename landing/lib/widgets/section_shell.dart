import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// Page-level section wrapper: centred 1200 px column, responsive gutters,
/// optional tinted band.
class SectionShell extends StatelessWidget {
  const SectionShell({
    super.key,
    required this.child,
    this.banded = false,
    this.paddingTop = Tk.space4xl,
    this.paddingBottom = Tk.space4xl,
  });

  final Widget child;
  final bool banded;
  final double paddingTop;
  final double paddingBottom;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Container(
      width: double.infinity,
      color: banded ? Tk.paper2 : Tk.paper,
      padding: EdgeInsets.only(top: paddingTop, bottom: paddingBottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Tk.pagePadding(width)),
            child: child,
          ),
        ),
      ),
    );
  }
}
