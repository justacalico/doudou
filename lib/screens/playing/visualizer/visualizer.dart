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
        height: 200,
        child: CustomPaint(
          painter: EmbeddedVisualizerPainter(
            barHeights: _barHeights,
            isPlaying: widget.isPlaying,
            colors: _extractedColors,
            globalPulse: _globalPulse,
          ),
        ),
      ),
    );
  }
}

// Custom painter for the 2D bar visualizer
class EmbeddedVisualizerPainter extends CustomPainter {
  final List<double> barHeights;
  final bool isPlaying;
  final List<Color> colors;
  final double globalPulse;

  EmbeddedVisualizerPainter({
    required this.barHeights,
    required this.isPlaying,
    required this.colors,
    required this.globalPulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = barHeights.length;
    final barWidth = (size.width * 0.8) / barCount;
    final spacing = (size.width * 0.2) / (barCount + 1);
    final maxBarHeight = size.height * 0.8;
    final baseY = size.height * 0.9;

    for (int i = 0; i < barCount; i++) {
      final intensity = barHeights[i];
      final barHeight = intensity * maxBarHeight;
      
      // Calculate bar position
      final x = spacing + (i * (barWidth + spacing));
      final y = baseY - barHeight;
      
      // Create gradient for the bar
      final colorIndex = (i / (barCount / colors.length)).floor() % colors.length;
      final baseColor = colors[colorIndex];
      
      // Enhanced color with intensity
      final hsvColor = HSVColor.fromColor(baseColor);
      final saturation = (isPlaying ? 0.8 + intensity * 0.2 : 0.4).clamp(0.0, 1.0);
      final brightness = (isPlaying ? 0.6 + intensity * 0.4 : 0.4 + intensity * 0.3).clamp(0.0, 1.0);
      final opacity = (isPlaying ? 0.8 + intensity * 0.2 : 0.6).clamp(0.0, 1.0);
      
      final barColor = HSVColor.fromAHSV(opacity, hsvColor.hue, saturation, brightness).toColor();
      
      // Create gradient from bright to darker
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          barColor,
          Color.lerp(barColor, const Color(0xFF000000), 0.3)!,
        ],
      );
      
      // Draw the bar
      final barRect = Rect.fromLTWH(x, y, barWidth * 0.8, barHeight);
      final barPaint = Paint()
        ..shader = gradient.createShader(barRect);
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(2)),
        barPaint,
      );
      
      // Add glow effects for intense bars
      if (isPlaying && intensity > 0.5) {
        // Inner glow
        final glowPaint = Paint()
          ..color = barColor.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        
        canvas.drawRRect(
          RRect.fromRectAndRadius(barRect, const Radius.circular(2)),
          glowPaint,
        );
        
        // Outer glow for very intense bars
        if (intensity > 0.8) {
          final outerGlowPaint = Paint()
            ..color = barColor.withOpacity(0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
          
          canvas.drawRRect(
            RRect.fromRectAndRadius(barRect, const Radius.circular(2)),
            outerGlowPaint,
          );
        }
      }
      
      // Draw reflection effect
      if (isPlaying && intensity > 0.3) {
        final reflectionHeight = barHeight * 0.3;
        final reflectionRect = Rect.fromLTWH(
          x, 
          baseY + 5, 
          barWidth * 0.8, 
          reflectionHeight,
        );
        
        final reflectionGradient = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            barColor.withOpacity(0.3),
            barColor.withOpacity(0.0),
          ],
        );
        
        final reflectionPaint = Paint()
          ..shader = reflectionGradient.createShader(reflectionRect);
        
        canvas.drawRRect(
          RRect.fromRectAndRadius(reflectionRect, const Radius.circular(2)),
          reflectionPaint,
        );
      }
    }
    
    // Add background glow effect
    if (isPlaying) {
      final centerX = size.width / 2;
      final centerY = size.height / 2;
      final glowRadius = size.width * 0.4 * globalPulse;
      
      final backgroundGlow = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            colors[0].withOpacity(0.1 * globalPulse),
            colors[1].withOpacity(0.05 * globalPulse),
            const Color(0x00000000),
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(centerX, centerY), radius: glowRadius));
      
      canvas.drawCircle(Offset(centerX, centerY), glowRadius, backgroundGlow);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
