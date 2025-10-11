// Stub implementation for non-web platforms
// This file provides empty stubs for dart:js functionality when not on web

class JsObject {
  static jsify(Map<String, dynamic> map) => null;
}

// Global context stub
class Context {
  operator [](String key) => null;
  operator []=(String key, dynamic value) {}
}

final context = Context();