import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../services/vr_scene_manager.dart';

/// VR 3D Environment Renderer
/// 
/// Renders a 360-degree 3D scene with head tracking support
class VR3DEnvironment extends StatefulWidget {
  final VRSceneManager sceneManager;
  final String? albumArtUrl;
  final Widget? controlsOverlay;
  final bool isLeftEye;
  
  const VR3DEnvironment({
    super.key,
    required this.sceneManager,
    this.albumArtUrl,
    this.controlsOverlay,
    this.isLeftEye = true,
  });

  @override
  State<VR3DEnvironment> createState() => _VR3DEnvironmentState();
}

class _VR3DEnvironmentState extends State<VR3DEnvironment> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return CustomPaint(
          painter: VR3DPainter(
            sceneManager: widget.sceneManager,
            albumArtUrl: widget.albumArtUrl,
            isLeftEye: widget.isLeftEye,
            animationValue: _animationController.value,
          ),
          child: widget.controlsOverlay,
        );
      },
    );
  }
}

/// Custom painter for 3D VR scene
class VR3DPainter extends CustomPainter {
  final VRSceneManager sceneManager;
  final String? albumArtUrl;
  final bool isLeftEye;
  final double animationValue;
  
  VR3DPainter({
    required this.sceneManager,
    this.albumArtUrl,
    required this.isLeftEye,
    required this.animationValue,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Get view matrix for current orientation
    final matrices = sceneManager.getStereoscopicViewMatrices();
    final viewMatrix = isLeftEye ? matrices['left']! : matrices['right']!;
    
    // Draw background gradient (space-like)
    _drawBackground(canvas, size);
    
    // Draw 360-degree environment sphere
    _draw360Sphere(canvas, size, center, viewMatrix);
    
    // Draw floating particles
    _drawParticles(canvas, size, center, viewMatrix);
    
    // Draw UI panels in 3D space
    _drawUIPanels(canvas, size, center, viewMatrix);
  }
  
  void _drawBackground(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        const Color(0xFF1a0033), // Deep purple
        const Color(0xFF000000), // Black
      ],
    );
    
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
    
    // Draw stars
    _drawStars(canvas, size);
  }
  
  void _drawStars(Canvas canvas, Size size) {
    final random = math.Random(42); // Fixed seed for consistent stars
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < 100; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final brightness = random.nextDouble();
      
      paint.color = Colors.white.withOpacity(brightness * 0.8);
      canvas.drawCircle(Offset(x, y), 1 + brightness, paint);
    }
  }
  
  void _draw360Sphere(Canvas canvas, Size size, Offset center, vector.Matrix4 viewMatrix) {
    // Draw multiple rings to simulate a 360-degree sphere
    final yaw = sceneManager.yaw;
    final pitch = sceneManager.pitch;
    
    // Draw several concentric rings that represent the panoramic view
    for (int ring = 0; ring < 8; ring++) {
      final ringRadius = 100.0 + (ring * 40.0);
      final ringOpacity = 1.0 - (ring * 0.1);
      
      _drawPanoramicRing(
        canvas,
        center,
        ringRadius,
        yaw,
        pitch,
        ringOpacity,
      );
    }
  }
  
  void _drawPanoramicRing(
    Canvas canvas,
    Offset center,
    double radius,
    double yaw,
    double pitch,
    double opacity,
  ) {
    const segments = 60;
    final path = Path();
    
    for (int i = 0; i <= segments; i++) {
      final angle = (i / segments) * 2 * math.pi + yaw;
      
      // Apply pitch to create 3D effect
      final y = math.sin(pitch) * radius * 0.5;
      final adjustedRadius = radius * math.cos(pitch);
      
      final x = center.dx + math.cos(angle) * adjustedRadius;
      final yPos = center.dy + y + math.sin(angle) * adjustedRadius * 0.3;
      
      if (i == 0) {
        path.moveTo(x, yPos);
      } else {
        path.lineTo(x, yPos);
      }
    }
    
    // Draw gradient along the ring
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.purple.withOpacity(opacity * 0.3);
    
    canvas.drawPath(path, paint);
  }
  
  void _drawParticles(Canvas canvas, Size size, Offset center, vector.Matrix4 viewMatrix) {
    final particleCount = 50;
    final random = math.Random(12);
    
    for (int i = 0; i < particleCount; i++) {
      // Create particles in 3D space around the user
      final theta = random.nextDouble() * 2 * math.pi;
      final phi = (random.nextDouble() - 0.5) * math.pi;
      final distance = 200.0 + random.nextDouble() * 300.0;
      
      // Convert spherical to Cartesian coordinates
      final x = distance * math.cos(phi) * math.cos(theta);
      final y = distance * math.sin(phi);
      final z = distance * math.cos(phi) * math.sin(theta);
      
      // Apply view transformation
      final point = vector.Vector4(x, y, z, 1.0);
      final transformed = viewMatrix * point;
      
      // Project to 2D
      if (transformed.z < 0) continue; // Behind camera
      
      final screenX = center.dx + transformed.x * 2;
      final screenY = center.dy + transformed.y * 2;
      
      // Particle size based on distance
      final size = 3.0 / (1.0 + transformed.z / 100.0);
      
      // Pulsating effect
      final pulse = math.sin(animationValue * 2 * math.pi + i) * 0.5 + 0.5;
      
      final paint = Paint()
        ..color = Colors.purple.withOpacity(0.6 * pulse)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(screenX, screenY), size, paint);
    }
  }
  
  void _drawUIPanels(Canvas canvas, Size size, Offset center, vector.Matrix4 viewMatrix) {
    // Draw floating UI panel in front of user
    final panelWidth = 300.0;
    final panelHeight = 100.0;
    
    // Position panel in front of user
    final panelDistance = 500.0;
    final panelPosition = vector.Vector4(0, 0, -panelDistance, 1.0);
    final transformed = viewMatrix * panelPosition;
    
    if (transformed.z < 0) {
      final panelX = center.dx + transformed.x * 2 - panelWidth / 2;
      final panelY = center.dy + transformed.y * 2 - panelHeight / 2;
      
      // Draw semi-transparent panel background
      final panelRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(panelX, panelY, panelWidth, panelHeight),
        const Radius.circular(20),
      );
      
      final panelPaint = Paint()
        ..color = Colors.black.withOpacity(0.5)
        ..style = PaintingStyle.fill;
      
      canvas.drawRRect(panelRect, panelPaint);
      
      // Draw border
      final borderPaint = Paint()
        ..color = Colors.purple.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      
      canvas.drawRRect(panelRect, borderPaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant VR3DPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.albumArtUrl != albumArtUrl;
  }
}

/// Helper class for 3D sphere mesh generation
class SphereMesh {
  final List<vector.Vector3> vertices = [];
  final List<List<int>> faces = [];
  
  SphereMesh({required double radius, int segments = 32, int rings = 16}) {
    _generateSphere(radius, segments, rings);
  }
  
  void _generateSphere(double radius, int segments, int rings) {
    // Generate vertices
    for (int ring = 0; ring <= rings; ring++) {
      final phi = (ring / rings) * math.pi;
      for (int segment = 0; segment <= segments; segment++) {
        final theta = (segment / segments) * 2 * math.pi;
        
        final x = radius * math.sin(phi) * math.cos(theta);
        final y = radius * math.cos(phi);
        final z = radius * math.sin(phi) * math.sin(theta);
        
        vertices.add(vector.Vector3(x, y, z));
      }
    }
    
    // Generate faces (triangles)
    for (int ring = 0; ring < rings; ring++) {
      for (int segment = 0; segment < segments; segment++) {
        final current = ring * (segments + 1) + segment;
        final next = current + segments + 1;
        
        faces.add([current, next, current + 1]);
        faces.add([current + 1, next, next + 1]);
      }
    }
  }
}
