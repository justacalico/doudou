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
  final int _barCount = 32;
  final Random _random = Random();
  double _globalPulse = 0.0;
  
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
          double time = DateTime.now().millisecondsSinceEpoch / 1000.0;
          
          // Global pulse effect
          _globalPulse = sin(time * 2.5) * 0.3 + 0.7;
          
          for (int i = 0; i < _barCount; i++) {
            // Create wave-like motion with symmetry
            double waveOffset = sin(time * 3 + i * 0.4) * 0.6;
            double symmetryWave = sin(time * 2 + (_barCount - 1 - i) * 0.4) * 0.4;
            
            // Random variation for liveliness
            double randomOffset = _random.nextDouble() * 0.3;
            
            // Bass emphasis on center bars
            double centerDistance = ((i - _barCount / 2).abs() / (_barCount / 2));
            double bassBoost = (1 - centerDistance) * sin(time * 4) * 0.5;
            
            // High frequency emphasis on outer bars
            double trebleBoost = centerDistance * cos(time * 6 + i * 0.2) * 0.4;
            
            // Combine all effects
            double intensity = 0.1 + randomOffset + waveOffset + symmetryWave + bassBoost + trebleBoost;
            
            _barHeights[i] = intensity.clamp(0.05, 1.8);
          }
        });
      } else if (mounted) {
        // Gradually reduce effects when not playing
        setState(() {
          _globalPulse = (_globalPulse * 0.95).clamp(0.4, 1.0);
          
          for (int i = 0; i < _barCount; i++) {
            _barHeights[i] = (_barHeights[i] * 0.9).clamp(0.05, 1.0);
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

// Custom painter for the 3D embedded visualizer
class EmbeddedVisualizerPainter extends CustomPainter {
  final List<double> barHeights;
  final List<double> barDepths;
  final List<double> barRotations;
  final bool isPlaying;
  final List<Color> colors;
  final double globalPulse;
  final double rotationOffset;
  final double perspectiveAngle;
  final double cameraY;

  EmbeddedVisualizerPainter({
    required this.barHeights,
    required this.barDepths,
    required this.barRotations,
    required this.isPlaying,
    required this.colors,
    required this.globalPulse,
    required this.rotationOffset,
    required this.perspectiveAngle,
    required this.cameraY,
  });

  // 3D transformation helper
  Offset project3D(double x, double y, double z, Size size, double perspective) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    // Apply camera position
    y += cameraY;
    
    // Apply perspective transformation
    final projectedX = centerX + (x * perspective) / (z + 300);
    final projectedY = centerY + (y * perspective) / (z + 300);
    
    return Offset(projectedX, projectedY);
  }

  // Create gradient for 3D effect
  LinearGradient create3DGradient(Color baseColor, double intensity, double depth) {
    final lightColor = Color.lerp(baseColor, const Color(0xFFFFFFFF), 0.3 * intensity)!;
    final darkColor = Color.lerp(baseColor, const Color(0xFF000000), 0.4 * (1 - depth))!;
    
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [lightColor, baseColor, darkColor],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = min(size.width, size.height) / 3;
    final barCount = barHeights.length;
    
    // Apply global pulse and perspective
    final radius = baseRadius * globalPulse;
    final perspective = 200 + (50 * globalPulse);
    
    // Create list of 3D bars with depth sorting
    List<Map<String, dynamic>> bars3D = [];
    
    for (int i = 0; i < barCount; i++) {
      final angle = (i / barCount) * 2 * pi + rotationOffset;
      final intensity = barHeights[i];
      final depth = barDepths[i];
      
      // Base position on circle
      final x = cos(angle) * radius;
      final y = sin(angle) * radius;
      final z = depth * 100 - 50; // Z depth for 3D effect
      
      // Individual bar rotation
      final barAngle = angle + barRotations[i] + perspectiveAngle;
      
      // Calculate 3D positions for the bar
      final barWidth = isPlaying ? 8 + intensity * 12 : 4 + intensity * 6;
      final barHeight = isPlaying ? 20 + intensity * 80 : 10 + intensity * 40;
      
      // Color for this bar
      final colorIndex = i % colors.length;
      final baseColor = colors[colorIndex];
      
      bars3D.add({
        'index': i,
        'x': x,
        'y': y,
        'z': z,
        'angle': barAngle,
        'width': barWidth,
        'height': barHeight,
        'intensity': intensity,
        'depth': depth,
        'color': baseColor,
      });
    }
    
    // Sort bars by Z-depth (back to front)
    bars3D.sort((a, b) => a['z'].compareTo(b['z']));
    
    // Draw each 3D bar
    for (var bar in bars3D) {
      _draw3DBar(canvas, size, bar, perspective);
    }
    
    // Add central glow effect
    if (isPlaying) {
      _drawCentralGlow(canvas, center, radius, globalPulse);
    }
  }

  void _draw3DBar(Canvas canvas, Size size, Map<String, dynamic> bar, double perspective) {
    final x = bar['x'];
    final y = bar['y'];
    final z = bar['z'];
    final width = bar['width'];
    final height = bar['height'];
    final intensity = bar['intensity'];
    final depth = bar['depth'];
    final baseColor = bar['color'];
    
    // Calculate 3D positions for bar corners
    final bottomLeft = project3D(x - width/2, y + height/2, z, size, perspective);
    final bottomRight = project3D(x + width/2, y + height/2, z, size, perspective);
    final topLeft = project3D(x - width/2, y - height/2, z, size, perspective);
    final topRight = project3D(x + width/2, y - height/2, z, size, perspective);
    
    // Back face (slightly behind)
    final backZ = z - 20 * depth;
    final backBottomLeft = project3D(x - width/2, y + height/2, backZ, size, perspective);
    final backBottomRight = project3D(x + width/2, y + height/2, backZ, size, perspective);
    final backTopLeft = project3D(x - width/2, y - height/2, backZ, size, perspective);
    final backTopRight = project3D(x + width/2, y - height/2, backZ, size, perspective);
    
    // Create dynamic color with 3D lighting
    final hsvColor = HSVColor.fromColor(baseColor);
    final saturation = (isPlaying ? 0.8 + intensity * 0.2 : 0.4).clamp(0.0, 1.0);
    final brightness = (isPlaying ? 0.5 + intensity * 0.4 : 0.3 + intensity * 0.2).clamp(0.0, 1.0);
    final opacity = (isPlaying ? 0.8 + intensity * 0.2 : 0.5 + intensity * 0.2).clamp(0.0, 1.0);
    
    final frontColor = HSVColor.fromAHSV(opacity, hsvColor.hue, saturation, brightness).toColor();
    final sideColor = HSVColor.fromAHSV(opacity * 0.7, hsvColor.hue, saturation, brightness * 0.7).toColor();
    final backColor = HSVColor.fromAHSV(opacity * 0.5, hsvColor.hue, saturation, brightness * 0.5).toColor();
    
    // Draw back face
    final backPath = Path()
      ..moveTo(backBottomLeft.dx, backBottomLeft.dy)
      ..lineTo(backBottomRight.dx, backBottomRight.dy)
      ..lineTo(backTopRight.dx, backTopRight.dy)
      ..lineTo(backTopLeft.dx, backTopLeft.dy)
      ..close();
    
    canvas.drawPath(backPath, Paint()
      ..color = backColor
      ..style = PaintingStyle.fill);
    
    // Draw connecting sides (left and right)
    final leftSidePath = Path()
      ..moveTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(backBottomLeft.dx, backBottomLeft.dy)
      ..lineTo(backTopLeft.dx, backTopLeft.dy)
      ..lineTo(topLeft.dx, topLeft.dy)
      ..close();
    
    canvas.drawPath(leftSidePath, Paint()
      ..color = sideColor
      ..style = PaintingStyle.fill);
    
    final rightSidePath = Path()
      ..moveTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(backBottomRight.dx, backBottomRight.dy)
      ..lineTo(backTopRight.dx, backTopRight.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..close();
    
    canvas.drawPath(rightSidePath, Paint()
      ..color = sideColor
      ..style = PaintingStyle.fill);
    
    // Draw top connecting face
    final topSidePath = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(backTopRight.dx, backTopRight.dy)
      ..lineTo(backTopLeft.dx, backTopLeft.dy)
      ..close();
    
    canvas.drawPath(topSidePath, Paint()
      ..color = Color.lerp(frontColor, sideColor, 0.3)!
      ..style = PaintingStyle.fill);
    
    // Draw front face (brightest)
    final frontPath = Path()
      ..moveTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(topLeft.dx, topLeft.dy)
      ..close();
    
    canvas.drawPath(frontPath, Paint()
      ..color = frontColor
      ..style = PaintingStyle.fill);
    
    // Add glow effects for intense bars
    if (isPlaying && intensity > 0.6) {
      // Front face glow
      canvas.drawPath(frontPath, Paint()
        ..color = frontColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (2 + intensity * 3).toDouble()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      
      // Intense glow for very high intensity
      if (intensity > 0.8) {
        canvas.drawPath(frontPath, Paint()
          ..color = frontColor.withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (4 + intensity * 6).toDouble()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      }
    }
  }

  void _drawCentralGlow(Canvas canvas, Offset center, double radius, double pulse) {
    // Central pulsing glow
    final glowRadius = radius * 0.3 * pulse;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          colors[0].withOpacity(0.3 * pulse),
          colors[1].withOpacity(0.2 * pulse),
          colors[2].withOpacity(0.1 * pulse),
          const Color(0x00000000), // Transparent
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));
    
    canvas.drawCircle(center, glowRadius, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
