import 'package:flutter/cupertino.dart';
import 'dart:math';
import 'dart:async';
import 'dart:ui' as ui;

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
  late AnimationController _depthController;
  late Timer _timer;
  List<double> _barHeights = [];
  List<double> _barDepths = [];
  List<double> _barRotations = [];
  final int _barCount = 64;
  final Random _random = Random();
  double _globalPulse = 0.0;
  double _rotationOffset = 0.0;
  double _perspectiveAngle = 0.0;
  double _cameraY = 0.0;
  
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
    
    // Initialize 3D bar properties
    _barHeights = List.generate(_barCount, (index) => 0.1);
    _barDepths = List.generate(_barCount, (index) => 0.1);
    _barRotations = List.generate(_barCount, (index) => 0.0);
    
    // Create animation controllers
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();

    _depthController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();

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
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (widget.isPlaying && mounted) {
        setState(() {
          double time = DateTime.now().millisecondsSinceEpoch / 1000.0;
          
          // Global pulse effect
          _globalPulse = sin(time * 2.5) * 0.4 + 0.7;
          
          // 3D rotation and camera effects
          _rotationOffset = time * 0.3;
          _perspectiveAngle = sin(time * 0.8) * 0.2;
          _cameraY = sin(time * 0.5) * 20;
          
          for (int i = 0; i < _barCount; i++) {
            // Enhanced wave patterns for 3D effect
            double waveOffset = sin(time * 3 + i * 0.15) * 0.5;
            double secondaryWave = cos(time * 1.8 + i * 0.2) * 0.3;
            
            // Dynamic height with more variation
            double baseIntensity = 0.2 + _random.nextDouble() * 0.7 + waveOffset + secondaryWave;
            
            // 3D depth variation
            double depthWave = sin(time * 2.2 + i * 0.25) * 0.6;
            double depthIntensity = 0.3 + _random.nextDouble() * 0.4 + depthWave;
            
            // Individual bar rotation
            double rotationSpeed = 0.02 + (i % 5) * 0.01;
            _barRotations[i] = (_barRotations[i] + rotationSpeed) % (2 * pi);
            
            // Bass-like emphasis with 3D stretching
            double bassBoost = sin((i / _barCount) * 6 * pi + time * 0.9) * 0.5;
            double trebleBoost = cos((i / _barCount) * 8 * pi + time * 1.3) * 0.3;
            
            // Spiral effect
            double spiralFactor = sin((i / _barCount) * 4 * pi + time * 1.5) * 0.4;
            
            _barHeights[i] = (baseIntensity + bassBoost + trebleBoost + spiralFactor).clamp(0.1, 2.0);
            _barDepths[i] = (depthIntensity + spiralFactor * 0.5).clamp(0.1, 1.5);
          }
        });
      } else if (mounted) {
        // Gradually reduce effects when not playing
        setState(() {
          _globalPulse = (_globalPulse * 0.95).clamp(0.4, 1.0);
          _rotationOffset *= 0.98;
          _perspectiveAngle *= 0.95;
          _cameraY *= 0.9;
          
          for (int i = 0; i < _barCount; i++) {
            _barHeights[i] = (_barHeights[i] * 0.92).clamp(0.1, 1.0);
            _barDepths[i] = (_barDepths[i] * 0.92).clamp(0.1, 1.0);
            _barRotations[i] = (_barRotations[i] * 0.98) % (2 * pi);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _animationController.dispose();
    _rotationController.dispose();
    _depthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 320,
        height: 320,
        child: CustomPaint(
          painter: EmbeddedVisualizerPainter(
            barHeights: _barHeights,
            barDepths: _barDepths,
            barRotations: _barRotations,
            isPlaying: widget.isPlaying,
            colors: _extractedColors,
            globalPulse: _globalPulse,
            rotationOffset: _rotationOffset,
            perspectiveAngle: _perspectiveAngle,
            cameraY: _cameraY,
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
  final double globalPulse;
  final double rotationOffset;

  EmbeddedVisualizerPainter({
    required this.barHeights,
    required this.isPlaying,
    required this.colors,
    required this.globalPulse,
    required this.rotationOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = min(size.width, size.height) / 2 - 20;
    final barCount = barHeights.length;

    // Apply global pulse to the entire ring
    final radius = baseRadius * globalPulse;

    // Create segments for the ring with enhanced effects
    const double segmentSpacing = 0.03;
    final double segmentAngle = (2 * pi / barCount) - segmentSpacing;

    for (int i = 0; i < barCount; i++) {
      // Add rotation offset for spinning effect
      final startAngle = (i / barCount) * 2 * pi - pi / 2 + rotationOffset;
      final intensity = barHeights[i];
      
      // Dynamic radius stretching - some segments extend further out
      final stretchMultiplier = 0.8 + (intensity * 0.4);
      final segmentRadius = radius * stretchMultiplier;
      
      // Enhanced thickness variation
      final baseThickness = isPlaying ? 6.0 : 3.0;
      final maxThickness = isPlaying ? 25.0 : 10.0;
      final ringThickness = baseThickness + (intensity * (maxThickness - baseThickness));
      
      // Create dynamic color with enhanced effects
      final colorIndex = i % colors.length;
      final baseColor = colors[colorIndex];
      final hsvColor = HSVColor.fromColor(baseColor);
      
      // Enhanced color dynamics
      final saturation = (isPlaying ? 0.85 + (intensity * 0.15) : 0.3).clamp(0.0, 1.0);
      final brightness = (isPlaying ? 0.6 + intensity * 0.4 : 0.3 + intensity * 0.2).clamp(0.0, 1.0);
      final opacity = (isPlaying ? 0.7 + intensity * 0.3 : 0.4 + intensity * 0.2).clamp(0.0, 1.0);
      
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

      // Draw the main ring segment with dynamic radius
      final rect = Rect.fromCircle(center: center, radius: segmentRadius);
      canvas.drawArc(
        rect,
        startAngle,
        segmentAngle,
        false,
        segmentPaint,
      );

      // Enhanced glow effects
      if (isPlaying && intensity > 0.6) {
        // Inner glow
        final innerGlowPaint = Paint()
          ..color = segmentColor.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringThickness + 6
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
          
        canvas.drawArc(
          rect,
          startAngle,
          segmentAngle,
          false,
          innerGlowPaint,
        );
        
        // Outer glow for very intense segments
        if (intensity > 0.8) {
          final outerGlowPaint = Paint()
            ..color = segmentColor.withOpacity(0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = ringThickness + 12
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
            
          canvas.drawArc(
            rect,
            startAngle,
            segmentAngle,
            false,
            outerGlowPaint,
          );
        }
      }
      
      // Add trailing effects for high-intensity segments
      if (isPlaying && intensity > 0.7) {
        final trailPaint = Paint()
          ..color = segmentColor.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringThickness * 0.6
          ..strokeCap = StrokeCap.round;
          
        // Draw trailing arc
        final trailAngle = startAngle - (segmentAngle * 0.5);
        canvas.drawArc(
          rect,
          trailAngle,
          segmentAngle * 0.3,
          false,
          trailPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
