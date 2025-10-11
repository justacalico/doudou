// Stub implementation for non-web platforms
// This file provides empty stubs for dart:js functionality when not on web

class JsObject {
  static jsify(Map<String, dynamic> map) => _JsObjectStub();
  callMethod(String method, [List? args]) => null;
}

class _JsObjectStub {
  callMethod(String method, [List? args]) => null;
}

// Global context stub
class Context {
  operator [](String key) => _JsObjectStub();
  operator []=(String key, dynamic value) {}
}

final context = Context();