import 'package:flutter/cupertino.dart';
import 'dart:math';
import 'dart:async';

// Embedded visualizer widget for the now playing screen
class EmbeddedVisualizer extends StatefulWidget {
  final String trackName;
  final String? artistName;
  final bool isPlaying;

  const EmbeddedVisualizer({
    super.key,
    required this.trackName,
    this.artistName,
    required this.isPlaying,
  });

  @override
  State<EmbeddedVisualizer> createState() => _EmbeddedVisualizerState();
}

class _EmbeddedVisualizerState extends State<EmbeddedVisualizer>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _rotationController;
  late Timer _timer;
  List<double> _barHeights = [];
  final int _barCount = 48;
  final Random _random = Random();
  double _globalPulse = 0.0;
  double _rotationOffset = 0.0;
  
  // Color extraction from song info
  List<Color> _extractedColors = [
    const Color(0xFF007AFF), // Default blue
    const Color(0xFF00FF88), // Default green
    const Color(0xFFFF453A), // Default red
    const Color(0xFFFF9F0A), // Default orange
    const Color(0xFFBF5AF2), // Default purple
  ];

  @override
  void initState() {
    super.initState();
    
    // Initialize bar heights
    _barHeights = List.generate(_barCount, (index) => 0.1);
    
    // Create animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    // Extract colors from song info
    _extractColorsFromSong();

    // Start the visualizer animation
    _startVisualizerAnimation();
  }

  void _extractColorsFromSong() {
    // Generate colors based on the track name and artist
    final String colorSeed = '${widget.trackName}${widget.artistName ?? ''}';
    final Random colorRandom = Random(colorSeed.hashCode);
    
    // Generate a color palette based on the song
    final baseHue = colorRandom.nextDouble() * 360;
    _extractedColors = [
      HSVColor.fromAHSV(1.0, baseHue, 0.8, 0.9).toColor(),
      HSVColor.fromAHSV(1.0, (baseHue + 60) % 360, 0.7, 0.8).toColor(),
      HSVColor.fromAHSV(1.0, (baseHue + 120) % 360, 0.9, 0.7).toColor(),
      HSVColor.fromAHSV(1.0, (baseHue + 180) % 360, 0.6, 0.9).toColor(),
      HSVColor.fromAHSV(1.0, (baseHue + 240) % 360, 0.8, 0.8).toColor(),
    ];
    
    if (mounted) {
      setState(() {});
    }
  }

  void _startVisualizerAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (widget.isPlaying && mounted) {
        setState(() {
          for (int i = 0; i < _barCount; i++) {
            // Create wave-like motion for smoother animation
            double time = DateTime.now().millisecondsSinceEpoch / 1000.0;
            double waveOffset = sin(time * 2 + i * 0.2) * 0.3;
            
            // Base intensity with wave motion
            double baseIntensity = 0.4 + _random.nextDouble() * 0.5 + waveOffset;
            
            // Make opposite sides mirror each other for symmetry
            double symmetryFactor = sin((i / _barCount) * 2 * pi) * 0.2;
            
            // Add bass-like emphasis to certain positions
            double bassBoost = sin((i / _barCount) * 4 * pi) * 0.3;
            
            _barHeights[i] = (baseIntensity + symmetryFactor + bassBoost).clamp(0.15, 1.0);
          }
        });
      } else if (mounted) {
        // Gradually reduce bar heights when not playing
        setState(() {
          for (int i = 0; i < _barCount; i++) {
            _barHeights[i] = (_barHeights[i] * 0.92).clamp(0.1, 1.0);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 280,
        height: 280,
        child: CustomPaint(
          painter: EmbeddedVisualizerPainter(
            barHeights: _barHeights,
            isPlaying: widget.isPlaying,
            colors: _extractedColors,
          ),
        ),
      ),
    );
  }
}

// Custom painter for the embedded visualizer
class EmbeddedVisualizerPainter extends CustomPainter {
  final List<double> barHeights;
  final bool isPlaying;
  final List<Color> colors;

  EmbeddedVisualizerPainter({
    required this.barHeights,
    required this.isPlaying,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 20;
    final barCount = barHeights.length;

    // Create segments for the ring
    const double segmentSpacing = 0.02; // Small gap between segments
    final double segmentAngle = (2 * pi / barCount) - segmentSpacing;

    for (int i = 0; i < barCount; i++) {
      final startAngle = (i / barCount) * 2 * pi - pi / 2;
      final intensity = barHeights[i];
      
      // Calculate ring thickness based on intensity
      final baseThickness = isPlaying ? 8.0 : 4.0;
      final maxThickness = isPlaying ? 20.0 : 8.0;
      final ringThickness = baseThickness + (intensity * (maxThickness - baseThickness));
      
      // Create dynamic color based on position and extracted colors
      final colorIndex = i % colors.length;
      final baseColor = colors[colorIndex];
      final hsvColor = HSVColor.fromColor(baseColor);
      
      final saturation = isPlaying ? 0.9 : 0.4;
      final brightness = isPlaying ? 0.7 + intensity * 0.3 : 0.4 + intensity * 0.2;
      final opacity = isPlaying ? 0.8 + intensity * 0.2 : 0.5 + intensity * 0.3;
      
      final segmentColor = HSVColor.fromAHSV(
        opacity, 
        hsvColor.hue, 
        saturation, 
        brightness
      ).toColor();

      // Create paint for the ring segment
      final segmentPaint = Paint()
        ..color = segmentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringThickness
        ..strokeCap = StrokeCap.round;

      // Draw the ring segment as an arc
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        rect,
        startAngle,
        segmentAngle,
        false,
        segmentPaint,
      );

      // Add glow effect for high intensity segments when playing
      if (isPlaying && intensity > 0.7) {
        final glowPaint = Paint()
          ..color = segmentColor.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringThickness + 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
          
        canvas.drawArc(
          rect,
          startAngle,
          segmentAngle,
          false,
          glowPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
