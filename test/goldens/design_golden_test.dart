import 'package:doudou/ui/design/doudou_colors.dart';
import 'package:doudou/ui/design/doudou_theme.dart';
import 'package:doudou/ui/design/doudou_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_helpers.dart';

Widget _swatch(String name, Color color) {
  return Padding(
    padding: const EdgeInsets.all(6),
    child: Column(
      children: [
        Container(
          width: 120,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: DoudouRadii.r8,
            border: Border.all(color: Colors.white24),
          ),
        ),
        const SizedBox(height: 4),
        Text(name, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );
}

Widget _colorGrid(DoudouColors colors) {
  final entries = <String, Color>{
    'appBackground': colors.appBackground,
    'raisedBackground': colors.raisedBackground,
    'surfaceBase': colors.surfaceBase,
    'surfaceElevated': colors.surfaceElevated,
    'surfaceOverlay': colors.surfaceOverlay,
    'surfaceModal': colors.surfaceModal,
    'surfaceSelected': colors.surfaceSelected,
    'stateHover': colors.stateHover,
    'statePressed': colors.statePressed,
    'borderSubtle': colors.borderSubtle,
    'borderStrong': colors.borderStrong,
    'textPrimary': colors.textPrimary,
    'textSecondary': colors.textSecondary,
    'textTertiary': colors.textTertiary,
    'textDisabled': colors.textDisabled,
    'accentPrimary': colors.accentPrimary,
    'accentMuted': colors.accentMuted,
    'onAccent': colors.onAccent,
    'success': colors.success,
    'warning': colors.warning,
    'error': colors.error,
    'artworkScrimTop': colors.artworkScrimTop,
    'artworkScrimBottom': colors.artworkScrimBottom,
    'playerBackdropLow': colors.playerBackdropLow,
    'playerBackdropHigh': colors.playerBackdropHigh,
  };
  return Wrap(
    children: entries.entries.map((e) => _swatch(e.key, e.value)).toList(),
  );
}

Widget _typeScale() {
  final styles = <String, TextStyle>{
    'display': DoudouType.display,
    'hero': DoudouType.hero,
    'pageTitle': DoudouType.pageTitle,
    'sectionTitle': DoudouType.sectionTitle,
    'bodyStrong': DoudouType.bodyStrong,
    'body': DoudouType.body,
    'meta': DoudouType.meta,
    'caption': DoudouType.caption,
    'controlLabel': DoudouType.controlLabel,
    'navLabel': DoudouType.navLabel,
    'overline': DoudouType.overline,
  };
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: styles.entries
        .map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('${e.key}: The quick brown fox 0123',
                style: e.value.copyWith(fontFamily: 'Inter')),
          ),
        )
        .toList(),
  );
}

void main() {
  group('design system goldens', () {
    testWidgets('dark color palette', (tester) async {
      final colors = goldenTheme().extension<DoudouColors>()!;
      await pumpGolden(
        tester,
        SingleChildScrollView(child: _colorGrid(colors)),
        size: const Size(900, 600),
      );
      await expectGolden(tester, 'design_colors_dark');
    });

    testWidgets('light color palette', (tester) async {
      final theme = goldenTheme(brightness: Brightness.light);
      final colors = theme.extension<DoudouColors>()!;
      await pumpGolden(
        tester,
        SingleChildScrollView(child: _colorGrid(colors)),
        theme: theme,
        size: const Size(900, 600),
      );
      await expectGolden(tester, 'design_colors_light');
    });

    testWidgets('oled color palette', (tester) async {
      final theme = goldenOledTheme();
      final colors = theme.extension<DoudouColors>()!;
      await pumpGolden(
        tester,
        SingleChildScrollView(child: _colorGrid(colors)),
        theme: theme,
        size: const Size(900, 600),
      );
      await expectGolden(tester, 'design_colors_oled');
    });

    testWidgets('typography scale', (tester) async {
      await pumpGolden(
        tester,
        SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(24), child: _typeScale()),
        ),
        size: const Size(900, 700),
      );
      await expectGolden(tester, 'design_typography');
    });

    testWidgets('typography scale light', (tester) async {
      await pumpGolden(
        tester,
        SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(24), child: _typeScale()),
        ),
        theme: goldenTheme(brightness: Brightness.light),
        size: const Size(900, 700),
      );
      await expectGolden(tester, 'design_typography_light');
    });
  });
}
