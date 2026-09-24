enum AudioOutputKind {
  speaker,
  earpiece,
  wired,
  bluetooth,
  airplay,
  usb,
  hdmi,
  cast,
  other,
}

AudioOutputKind _kindFromName(String? name) {
  return AudioOutputKind.values.asNameMap()[name] ?? AudioOutputKind.other;
}

/// One selectable audio output route as reported by the platform.
///
/// `selectable` is false for routes the OS does not let the app switch to
/// directly (iOS only allows the built-in receiver/speaker override, anything
/// else has to go through the system route picker).
class AudioOutputDevice {
  const AudioOutputDevice({
    required this.id,
    required this.name,
    this.kind = AudioOutputKind.other,
    this.selected = false,
    this.selectable = true,
  });

  factory AudioOutputDevice.fromMap(Map<dynamic, dynamic> map) {
    return AudioOutputDevice(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      kind: _kindFromName(map['kind'] as String?),
      selected: map['selected'] as bool? ?? false,
      selectable: map['selectable'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final AudioOutputKind kind;
  final bool selected;
  final bool selectable;

  @override
  bool operator ==(Object other) =>
      other is AudioOutputDevice &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.selected == selected &&
      other.selectable == selectable;

  @override
  int get hashCode => Object.hash(id, name, kind, selected, selectable);
}
