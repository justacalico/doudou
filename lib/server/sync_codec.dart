import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Converts values stored in Hive boxes to and from JSON safe wire values.
///
/// Hive values in this app are maps/lists of strings, numbers and bools, but
/// this codec also survives Uint8List blobs and maps with non string keys.
/// Anything else is stringified so a weird value can never break a sync run.
const String _b64Marker = '\$b64';
const String _strMarker = '\$str';

Object? toWireValue(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is Uint8List) {
    return {_b64Marker: base64Encode(value)};
  }
  if (value is List<int>) {
    return {_b64Marker: base64Encode(value)};
  }
  if (value is Map) {
    final out = <String, Object?>{};
    value.forEach((k, v) {
      out[k.toString()] = toWireValue(v);
    });
    return out;
  }
  if (value is Iterable) {
    return value.map(toWireValue).toList();
  }
  return {_strMarker: value.toString()};
}

Object? fromWireValue(Object? value) {
  if (value is Map) {
    if (value.length == 1 && value.containsKey(_b64Marker)) {
      final encoded = value[_b64Marker];
      if (encoded is String) {
        try {
          return base64Decode(encoded);
        } catch (_) {
          return value;
        }
      }
    }
    if (value.length == 1 && value.containsKey(_strMarker)) {
      return value[_strMarker]?.toString();
    }
    final out = <String, Object?>{};
    value.forEach((k, v) {
      out[k.toString()] = fromWireValue(v);
    });
    return out;
  }
  if (value is List) {
    return value.map(fromWireValue).toList();
  }
  return value;
}

/// Deterministic JSON encoding (map keys sorted) used for hashing.
String canonicalJson(Object? value) {
  final buffer = StringBuffer();
  _writeCanonical(value, buffer);
  return buffer.toString();
}

void _writeCanonical(Object? value, StringBuffer out) {
  if (value == null || value is num || value is bool || value is String) {
    out.write(jsonEncode(value));
    return;
  }
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    out.write('{');
    for (var i = 0; i < keys.length; i++) {
      if (i > 0) out.write(',');
      out
        ..write(jsonEncode(keys[i]))
        ..write(':')
        ..write(canonicalJson(value[keys[i]]));
    }
    out.write('}');
    return;
  }
  if (value is Iterable) {
    out.write('[');
    var i = 0;
    for (final item in value) {
      if (i++ > 0) out.write(',');
      out.write(canonicalJson(item));
    }
    out.write(']');
    return;
  }
  out.write(jsonEncode(toWireValue(value)));
}

/// Stable content hash of a box value, independent of map iteration order.
String valueHash(Object? value) =>
    sha256.convert(utf8.encode(canonicalJson(toWireValue(value)))).toString();
