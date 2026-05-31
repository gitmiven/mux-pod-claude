import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/widgets/key_bar_config.dart';
import 'package:flutter_muxpod/widgets/special_keys_bar.dart';

void main() {
  // Pumps SpecialKeysBar with spy callbacks; returns the recorded keys.
  Future<({List<String> literal, List<String> special})> pumpBar(
    WidgetTester tester,
  ) async {
    final literal = <String>[];
    final special = <String>[];
    // 10 F-keys are Expanded, so they fit any width; pump wide (like the sibling
    // SpecialKeysBar test) so the pre-existing fixed-width arrow row also lays out.
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SpecialKeysBar(
              hapticFeedback: false,
              onKeyPressed: literal.add,
              onSpecialKeyPressed: special.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return (literal: literal, special: special);
  }

  group('KeyBarConfig.functionKeys (data model)', () {
    test('has exactly F1..F10 with matching tmux key names', () {
      final buttons = KeyBarConfig.functionKeys.buttons;
      expect(buttons.length, 10);
      for (var i = 0; i < 10; i++) {
        expect(buttons[i].label, 'F${i + 1}');
        expect(buttons[i].tmuxKey, 'F${i + 1}');
      }
    });

    test('a custom configuration drives the bar (variability)', () async {
      // SC-003: the bar renders whatever config it is given, no re-wiring.
      const custom = KeyBarConfig(
        name: 'demo',
        buttons: [KeyBarButton('PgUp', 'PPage')],
      );
      const bar = SpecialKeysBar(
        onKeyPressed: _noop,
        onSpecialKeyPressed: _noop,
        variableKeyBar: custom,
      );
      expect(bar.variableKeyBar, same(custom));
    });
  });

  group('function key bar (the default variable bar)', () {
    testWidgets('renders all 10 F-keys above the special-key rows',
        (tester) async {
      await pumpBar(tester);
      for (var i = 1; i <= 10; i++) {
        expect(find.text('F$i'), findsOneWidget);
      }
    });

    testWidgets('tapping F1 and F5 sends the matching function keys',
        (tester) async {
      final r = await pumpBar(tester);
      await tester.tap(find.text('F1'));
      await tester.tap(find.text('F5'));
      await tester.tap(find.text('F10'));
      expect(r.special, ['F1', 'F5', 'F10']);
    });

    testWidgets('SHIFT + F1 composes to S-F1 and consumes the modifier',
        (tester) async {
      final r = await pumpBar(tester);
      await tester.tap(find.text('SHIFT'));
      await tester.pump();
      await tester.tap(find.text('F1'));
      // modifier consumed → next F1 is plain
      await tester.tap(find.text('F1'));
      expect(r.special, ['S-F1', 'F1']);
    });

    testWidgets('passing null hides the bar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpecialKeysBar(
              hapticFeedback: false,
              onKeyPressed: _noop,
              onSpecialKeyPressed: _noop,
              variableKeyBar: null,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('F1'), findsNothing);
      // the existing rows are still there
      expect(find.text('ESC'), findsOneWidget);
    });
  });
}

void _noop(String _) {}
