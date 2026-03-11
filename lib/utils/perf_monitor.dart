import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class PerfMonitorController {
  PerfMonitorController({ValueNotifier<bool>? enabled})
      : enabled = enabled ?? ValueNotifier<bool>(false);

  final ValueNotifier<bool> enabled;

  static PerfMonitorController devDefault() {
    return PerfMonitorController(
      enabled: ValueNotifier<bool>(kDebugMode),
    );
  }

  void dispose() {
    enabled.dispose();
  }
}

class PerfMonitor extends StatefulWidget {
  const PerfMonitor({
    super.key,
    required this.controller,
    required this.child,
  });

  final PerfMonitorController controller;
  final Widget child;

  @override
  State<PerfMonitor> createState() => _PerfMonitorState();
}

class _PerfMonitorState extends State<PerfMonitor> {
  StreamSubscription<List<FrameTiming>>? _sub;

  @override
  void initState() {
    super.initState();
    widget.controller.enabled.addListener(_onEnabledChanged);
    _onEnabledChanged();
  }

  @override
  void didUpdateWidget(covariant PerfMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.enabled.removeListener(_onEnabledChanged);
      widget.controller.enabled.addListener(_onEnabledChanged);
      _onEnabledChanged();
    }
  }

  void _onEnabledChanged() {
    if (!kDebugMode) return;
    final enabled = widget.controller.enabled.value;
    _sub?.cancel();
    _sub = null;
    if (!enabled) return;

    // Keep this lightweight: aggregate + occasional logs only.
    _sub = _frameTimings().listen((timings) {
      if (!mounted) return;
      final stats = _summarize(timings);
      if (stats == null) return;

      // Log only when we exceed a budget to avoid spamming.
      if (stats.buildMsP95 > 10 || stats.rasterMsP95 > 10 || stats.totalMsP95 > 16.7) {
        debugPrint(
          '[perf] frames=${stats.count} p95 build=${stats.buildMsP95.toStringAsFixed(1)}ms '
          'raster=${stats.rasterMsP95.toStringAsFixed(1)}ms total=${stats.totalMsP95.toStringAsFixed(1)}ms '
          'max=${stats.totalMsMax.toStringAsFixed(1)}ms',
        );
      }
    });
  }

  Stream<List<FrameTiming>> _frameTimings() async* {
    final controller = StreamController<List<FrameTiming>>(sync: true);
    void onTimings(List<FrameTiming> t) => controller.add(t);
    SchedulerBinding.instance.addTimingsCallback(onTimings);
    try {
      yield* controller.stream;
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(onTimings);
      await controller.close();
    }
  }

  _FrameStats? _summarize(List<FrameTiming> timings) {
    if (timings.isEmpty) return null;
    final build = <double>[];
    final raster = <double>[];
    final total = <double>[];
    var maxTotal = 0.0;

    for (final t in timings) {
      final b = t.buildDuration.inMicroseconds / 1000.0;
      final r = t.rasterDuration.inMicroseconds / 1000.0;
      final all = b + r;
      build.add(b);
      raster.add(r);
      total.add(all);
      if (all > maxTotal) maxTotal = all;
    }

    build.sort();
    raster.sort();
    total.sort();
    double p95(List<double> v) => v[(v.length * 0.95).clamp(0, v.length - 1).toInt()];

    return _FrameStats(
      count: timings.length,
      buildMsP95: p95(build),
      rasterMsP95: p95(raster),
      totalMsP95: p95(total),
      totalMsMax: maxTotal,
    );
  }

  @override
  void dispose() {
    widget.controller.enabled.removeListener(_onEnabledChanged);
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return widget.child;
    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.enabled,
      builder: (context, enabled, child) {
        if (!enabled) return child!;
        return Stack(
          children: [
            child!,
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                child: SizedBox(
                  height: 180,
                  child: PerformanceOverlay.allEnabled(),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _FrameStats {
  const _FrameStats({
    required this.count,
    required this.buildMsP95,
    required this.rasterMsP95,
    required this.totalMsP95,
    required this.totalMsMax,
  });

  final int count;
  final double buildMsP95;
  final double rasterMsP95;
  final double totalMsP95;
  final double totalMsMax;
}

