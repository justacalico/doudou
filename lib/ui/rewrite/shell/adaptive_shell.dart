import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../layouts/desktop_layout.dart';
import '../layouts/mobile_layout.dart';
import 'adaptive_shell_state.dart';

const double kDesktopBreakpoint = 920;

class AdaptiveShell extends StatefulWidget {
  const AdaptiveShell({super.key, required this.useCupertino});

  final bool useCupertino;

  @override
  State<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends State<AdaptiveShell> {
  late final AdaptiveShellState _shellState;

  @override
  void initState() {
    super.initState();
    _shellState = AdaptiveShellState();
  }

  @override
  void dispose() {
    _shellState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdaptiveShellState>.value(
      value: _shellState,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= kDesktopBreakpoint) {
            return DesktopLayout(isCupertino: widget.useCupertino);
          }

          return MobileLayout(isCupertino: widget.useCupertino);
        },
      ),
    );
  }
}
