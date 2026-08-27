import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final projectRoot = Directory.current.path;

  test('AGENTS.md exists and is not empty', () {
    final file = File('$projectRoot/AGENTS.md');
    expect(file.existsSync(), isTrue);
    expect(file.readAsStringSync().trim().isNotEmpty, isTrue);
  });

  test('claude.md references AGENTS.md', () {
    final file = File('$projectRoot/claude.md');
    expect(file.existsSync(), isTrue);
    expect(file.readAsStringSync().trim(), 'agents.md');
  });
}
