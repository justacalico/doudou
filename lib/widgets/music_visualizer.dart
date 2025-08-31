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
    _timer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (widget.isPlaying && mounted) {
        setState(() {
          for (int i = 0; i < _barCount; i++) {
            // Create more dynamic movement with some bars being more active
            double baseIntensity = 0.3 + _random.nextDouble() * 0.7;
            
            // Make center bars generally more active
            double centerBoost = 1.0 - (i - _barCount / 2).abs() / (_barCount / 2);
            centerBoost = centerBoost * 0.3 + 0.7; // Scale between 0.7 and 1.0
            
            // Add some randomness for a more natural feel
            double randomFactor = 0.7 + _random.nextDouble() * 0.6;
            
            _barHeights[i] = (baseIntensity * centerBoost * randomFactor).clamp(0.1, 1.0);
          }
        });
      } else if (mounted) {
        // Gradually reduce bar heights when not playing
        setState(() {
          for (int i = 0; i < _barCount; i++) {
            _barHeights[i] = (_barHeights[i] * 0.95).clamp(0.05, 1.0);
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
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    const Color(0xFF1a1a2e).withOpacity(0.3),
                    const Color(0xFF000000),
                  ],
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
                        // Circular visualizer
                        Container(
                          width: 280,
                          height: 280,
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
    final innerRadius = radius * 0.3;
    final barCount = barHeights.length;

    // Draw outer circle (subtle border)
    final borderPaint = Paint()
      ..color = const Color(0xFF8E8E93).withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius - 10, borderPaint);

    // Draw inner circle
    final innerCirclePaint = Paint()
      ..color = const Color(0xFF1C1C1E).withOpacity(0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius, innerCirclePaint);

    // Draw bars
    for (int i = 0; i < barCount; i++) {
      final angle = (i / barCount) * 2 * pi - pi / 2; // Start from top
      final barHeight = barHeights[i] * (radius - innerRadius - 20);
      
      // Calculate positions
      final startRadius = innerRadius + 10;
      final endRadius = startRadius + barHeight;
      
      final startX = center.dx + cos(angle) * startRadius;
      final startY = center.dy + sin(angle) * startRadius;
      final endX = center.dx + cos(angle) * endRadius;
      final endY = center.dy + sin(angle) * endRadius;

      // Calculate bar color based on height (intensity)
      double intensity = barHeights[i];
      Color barColor;
      
      if (isPlaying) {
        if (intensity > 0.7) {
          barColor = Color.lerp(
            const Color(0xFF30D158), 
            const Color(0xFFFFFFFF), 
            (intensity - 0.7) / 0.3
          )!;
        } else if (intensity > 0.4) {
          barColor = Color.lerp(
            const Color(0xFF007AFF), 
            const Color(0xFF30D158), 
            (intensity - 0.4) / 0.3
          )!;
        } else {
          barColor = Color.lerp(
            const Color(0xFF007AFF).withOpacity(0.6), 
            const Color(0xFF007AFF), 
            intensity / 0.4
          )!;
        }
      } else {
        barColor = const Color(0xFF8E8E93).withOpacity(0.3 + intensity * 0.3);
      }

      // Draw the bar
      final barPaint = Paint()
        ..color = barColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        barPaint,
      );
    }

    // Draw center point
    final centerPaint = Paint()
      ..color = isPlaying 
          ? const Color(0xFFFFFFFF).withOpacity(0.8)
          : const Color(0xFF8E8E93).withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
