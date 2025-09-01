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
  late Timer _timer;
  List<double> _barHeights = [];
  final int _barCount = 48; // Slightly fewer for smaller space
  final Random _random = Random();
  
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
    final radius = min(size.width, size.height) / 2;
    final innerRadius = radius * 0.3;
    final barCount = barHeights.length;

    // Draw background glow effect
    if (isPlaying) {
      final glowPaint = Paint()
        ..color = colors[0].withOpacity(0.15)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius + 10, glowPaint);
    }

    // Draw inner black circle for contrast
    final innerCirclePaint = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius, innerCirclePaint);

    // Draw subtle inner ring
    final innerRingPaint = Paint()
      ..color = isPlaying 
          ? colors[1].withOpacity(0.4)
          : const Color(0xFF8E8E93).withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, innerRadius, innerRingPaint);

    // Draw animated bars extending outward
    for (int i = 0; i < barCount; i++) {
      final angle = (i / barCount) * 2 * pi - pi / 2;
      final intensity = barHeights[i];
      final barLength = intensity * 30; // Shorter bars for smaller space
      
      // Calculate positions
      final startRadius = innerRadius + 8;
      final endRadius = startRadius + barLength;
      
      final startX = center.dx + cos(angle) * startRadius;
      final startY = center.dy + sin(angle) * startRadius;
      final endX = center.dx + cos(angle) * endRadius;
      final endY = center.dy + sin(angle) * endRadius;

      // Create dynamic color based on position and extracted colors
      final colorIndex = i % colors.length;
      final baseColor = colors[colorIndex];
      final hsvColor = HSVColor.fromColor(baseColor);
      
      final saturation = isPlaying ? 0.9 : 0.3;
      final brightness = isPlaying ? 0.6 + intensity * 0.4 : 0.3 + intensity * 0.2;
      
      final barColor = HSVColor.fromAHSV(
        1.0, 
        hsvColor.hue, 
        saturation, 
        brightness
      ).toColor();

      // Add glow effect for playing state
      if (isPlaying && intensity > 0.5) {
        final glowPaint = Paint()
          ..color = barColor.withOpacity(0.4)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
          
        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), glowPaint);
      }

      // Draw the main bar
      final barPaint = Paint()
        ..color = barColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), barPaint);
    }

    // Draw center indicator
    if (isPlaying) {
      // Animated center point with glow using extracted colors
      final centerGlowPaint = Paint()
        ..color = colors[0].withOpacity(0.5)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(center, 6, centerGlowPaint);
      
      final centerPaint = Paint()
        ..color = colors[0]
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 3, centerPaint);
    } else {
      // Simple center point when paused
      final centerPaint = Paint()
        ..color = const Color(0xFF8E8E93).withOpacity(0.6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 2, centerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
