import 'package:flutter/cupertino.dart';
import 'dart:math';
import 'dart:async';

class MusicVisualizerScreen extends StatefulWidget {
  final String trackName;
  final String? artistName;
  final String? imageUrl;
  final bool isPlaying;

  const MusicVisualizerScreen({
    super.key,
    required this.trackName,
    this.artistName,
    this.imageUrl,
    required this.isPlaying,
  });

  @override
  State<MusicVisualizerScreen> createState() => _MusicVisualizerScreenState();
}

class _MusicVisualizerScreenState extends State<MusicVisualizerScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Timer _timer;
  List<double> _barHeights = [];
  final int _barCount = 32;
  final Random _random = Random();

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

    // Start the visualizer animation
    _startVisualizerAnimation();
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
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      child: SafeArea(
        child: Stack(
          children: [
            // Background gradient with deeper blacks for OLED
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    const Color(0xFF0a0a0a),
                    const Color(0xFF000000),
                    const Color(0xFF000000),
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
              ),
            ),
            
            // Main content
            Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                        child: const Icon(
                          CupertinoIcons.xmark,
                          color: Color(0xFFFFFFFF),
                          size: 28,
                        ),
                      ),
                      const Text(
                        'Visualizer',
                        style: TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 28), // Balance the close button
                    ],
                  ),
                ),
                
                // Visualizer area
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Circular visualizer with increased size
                        SizedBox(
                          width: 320,
                          height: 320,
                          child: CustomPaint(
                            painter: CircularVisualizerPainter(
                              barHeights: _barHeights,
                              isPlaying: widget.isPlaying,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Track info
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Column(
                            children: [
                              Text(
                                widget.trackName,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFFFFF),
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.artistName != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  widget.artistName!,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: CupertinoColors.systemGrey2,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Playback status indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: widget.isPlaying 
                                ? const Color(0xFF30D158).withOpacity(0.2)
                                : const Color(0xFF8E8E93).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: widget.isPlaying 
                                  ? const Color(0xFF30D158)
                                  : const Color(0xFF8E8E93),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.isPlaying 
                                    ? CupertinoIcons.play_fill
                                    : CupertinoIcons.pause_fill,
                                color: widget.isPlaying 
                                    ? const Color(0xFF30D158)
                                    : const Color(0xFF8E8E93),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.isPlaying ? 'Playing' : 'Paused',
                                style: TextStyle(
                                  color: widget.isPlaying 
                                      ? const Color(0xFF30D158)
                                      : const Color(0xFF8E8E93),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Bottom tip
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Tap anywhere to return',
                    style: TextStyle(
                      color: CupertinoColors.systemGrey2.withOpacity(0.8),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            
            // Tap to close overlay
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.translucent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CircularVisualizerPainter extends CustomPainter {
  final List<double> barHeights;
  final bool isPlaying;

  CircularVisualizerPainter({
    required this.barHeights,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final innerRadius = radius * 0.25;
    final barCount = barHeights.length;

    // Draw background glow effect
    if (isPlaying) {
      final glowPaint = Paint()
        ..color = const Color(0xFF007AFF).withOpacity(0.1)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius + 20, glowPaint);
    }

    // Draw the vibrant gradient ring
    final ringWidth = 8.0;
    final ringRadius = radius - 30;
    
    // Create gradient colors for the ring
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round;

    // Draw gradient ring segments
    for (int i = 0; i < 360; i += 2) {
      final angle = (i * pi) / 180;
      final intensity = barHeights[(i ~/ (360 / barCount)) % barCount];
      
      // Create rainbow gradient effect
      final hue = (i + (isPlaying ? DateTime.now().millisecondsSinceEpoch / 20 : 0)) % 360;
      final saturation = isPlaying ? 0.8 + intensity * 0.2 : 0.3;
      final brightness = isPlaying ? 0.7 + intensity * 0.3 : 0.4;
      
      final color = HSVColor.fromAHSV(1.0, hue.toDouble(), saturation, brightness).toColor();
      ringPaint.color = color;
      
      final startAngle = angle - 0.02;
      final endAngle = angle + 0.02;
      
      final startX = center.dx + cos(startAngle) * ringRadius;
      final startY = center.dy + sin(startAngle) * ringRadius;
      final endX = center.dx + cos(endAngle) * ringRadius;
      final endY = center.dy + sin(endAngle) * ringRadius;
      
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), ringPaint);
    }

    // Draw inner black circle for OLED contrast
    final innerCirclePaint = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius, innerCirclePaint);

    // Draw subtle inner ring
    final innerRingPaint = Paint()
      ..color = isPlaying 
          ? const Color(0xFFFFFFFF).withOpacity(0.2)
          : const Color(0xFF8E8E93).withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, innerRadius, innerRingPaint);

    // Draw animated bars extending outward
    for (int i = 0; i < barCount; i++) {
      final angle = (i / barCount) * 2 * pi - pi / 2;
      final intensity = barHeights[i];
      final barLength = intensity * 40; // Longer bars for better effect
      
      // Calculate positions
      final startRadius = ringRadius + 15;
      final endRadius = startRadius + barLength;
      
      final startX = center.dx + cos(angle) * startRadius;
      final startY = center.dy + sin(angle) * startRadius;
      final endX = center.dx + cos(angle) * endRadius;
      final endY = center.dy + sin(angle) * endRadius;

      // Create dynamic color based on position and intensity
      final hue = (i * (360 / barCount) + (isPlaying ? DateTime.now().millisecondsSinceEpoch / 30 : 0)) % 360;
      final saturation = isPlaying ? 0.9 : 0.3;
      final brightness = isPlaying ? 0.6 + intensity * 0.4 : 0.3 + intensity * 0.2;
      
      final barColor = HSVColor.fromAHSV(1.0, hue.toDouble(), saturation, brightness).toColor();

      // Add glow effect for playing state
      if (isPlaying && intensity > 0.5) {
        final glowPaint = Paint()
          ..color = barColor.withOpacity(0.3)
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
          
        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), glowPaint);
      }

      // Draw the main bar
      final barPaint = Paint()
        ..color = barColor
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), barPaint);
    }

    // Draw center indicator
    if (isPlaying) {
      // Animated center point with glow
      final centerGlowPaint = Paint()
        ..color = const Color(0xFFFFFFFF).withOpacity(0.6)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(center, 8, centerGlowPaint);
      
      final centerPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 4, centerPaint);
    } else {
      // Simple center point when paused
      final centerPaint = Paint()
        ..color = const Color(0xFF8E8E93).withOpacity(0.6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 3, centerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
