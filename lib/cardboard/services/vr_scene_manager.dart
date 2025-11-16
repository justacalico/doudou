import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';

/// VR Scene Manager
/// 
/// Manages the 3D scene state including camera orientation, 
/// head tracking, and scene object transformations
class VRSceneManager {
  // Camera orientation (rotation in radians)
  double _yaw = 0.0;   // Left-right rotation
  double _pitch = 0.0; // Up-down rotation
  double _roll = 0.0;  // Tilt rotation
  
  // Gyroscope integration for smooth head tracking
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  
  // Calibration offset
  double _calibrationYaw = 0.0;
  double _calibrationPitch = 0.0;
  
  // Sensitivity settings
  double sensitivity = 1.0;
  
  // Scene state
  final List<VRObject> _objects = [];
  
  // Getters
  double get yaw => _yaw;
  double get pitch => _pitch;
  double get roll => _roll;
  List<VRObject> get objects => _objects;
  
  /// Initialize the VR scene manager
  void initialize() {
    _setupGyroscope();
  }
  
  /// Setup gyroscope for head tracking
  void _setupGyroscope() {
    _gyroSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      // Integrate gyroscope data for rotation
      // Gyroscope gives angular velocity in rad/s
      const double dt = 0.02; // Approximate update rate
      
      _yaw += event.z * dt * sensitivity;
      _pitch += event.x * dt * sensitivity;
      _roll += event.y * dt * sensitivity;
      
      // Clamp pitch to prevent gimbal lock
      _pitch = _pitch.clamp(-math.pi / 2, math.pi / 2);
      
      // Normalize yaw to -π to π
      while (_yaw > math.pi) _yaw -= 2 * math.pi;
      while (_yaw < -math.pi) _yaw += 2 * math.pi;
    });
  }
  
  /// Calibrate the current orientation as forward
  void calibrate() {
    _calibrationYaw = _yaw;
    _calibrationPitch = _pitch;
  }
  
  /// Reset orientation to default
  void reset() {
    _yaw = 0.0;
    _pitch = 0.0;
    _roll = 0.0;
    _calibrationYaw = 0.0;
    _calibrationPitch = 0.0;
  }
  
  /// Get the view matrix for rendering
  vector.Matrix4 getViewMatrix() {
    // Apply calibration offset
    final adjustedYaw = _yaw - _calibrationYaw;
    final adjustedPitch = _pitch - _calibrationPitch;
    
    // Create rotation matrix
    final matrix = vector.Matrix4.identity();
    matrix.rotateY(-adjustedYaw);
    matrix.rotateX(-adjustedPitch);
    matrix.rotateZ(_roll);
    
    return matrix;
  }
  
  /// Get stereoscopic view matrices for left and right eyes
  Map<String, vector.Matrix4> getStereoscopicViewMatrices({
    double ipd = 0.064, // Interpupillary distance in meters (average ~64mm)
  }) {
    final baseMatrix = getViewMatrix();
    
    // Left eye (translate left)
    final leftMatrix = baseMatrix.clone();
    leftMatrix.translate(-ipd / 2, 0.0, 0.0);
    
    // Right eye (translate right)
    final rightMatrix = baseMatrix.clone();
    rightMatrix.translate(ipd / 2, 0.0, 0.0);
    
    return {
      'left': leftMatrix,
      'right': rightMatrix,
    };
  }
  
  /// Add an object to the scene
  void addObject(VRObject object) {
    _objects.add(object);
  }
  
  /// Remove an object from the scene
  void removeObject(VRObject object) {
    _objects.remove(object);
  }
  
  /// Clear all objects
  void clearObjects() {
    _objects.clear();
  }
  
  /// Dispose resources
  void dispose() {
    _gyroSubscription?.cancel();
  }
}

/// VR Object base class
abstract class VRObject {
  vector.Vector3 position;
  vector.Vector3 rotation;
  vector.Vector3 scale;
  
  VRObject({
    vector.Vector3? position,
    vector.Vector3? rotation,
    vector.Vector3? scale,
  })  : position = position ?? vector.Vector3.zero(),
        rotation = rotation ?? vector.Vector3.zero(),
        scale = scale ?? vector.Vector3(1.0, 1.0, 1.0);
  
  /// Get the transformation matrix for this object
  vector.Matrix4 getTransformMatrix() {
    final matrix = vector.Matrix4.identity();
    matrix.translate(position);
    matrix.rotateX(rotation.x);
    matrix.rotateY(rotation.y);
    matrix.rotateZ(rotation.z);
    matrix.scale(scale);
    return matrix;
  }
}

/// Sphere object for 360-degree panoramic images
class VRSphere extends VRObject {
  final double radius;
  final Color color;
  final String? imageUrl;
  
  VRSphere({
    required this.radius,
    this.color = Colors.white,
    this.imageUrl,
    super.position,
    super.rotation,
    super.scale,
  });
}

/// Plane object for UI panels
class VRPlane extends VRObject {
  final double width;
  final double height;
  final Widget? content;
  final Color color;
  
  VRPlane({
    required this.width,
    required this.height,
    this.content,
    this.color = Colors.white,
    super.position,
    super.rotation,
    super.scale,
  });
}

/// Particle system for visual effects
class VRParticleSystem extends VRObject {
  final int particleCount;
  final Color color;
  final double size;
  
  VRParticleSystem({
    required this.particleCount,
    this.color = Colors.purple,
    this.size = 0.1,
    super.position,
    super.rotation,
    super.scale,
  });
}
