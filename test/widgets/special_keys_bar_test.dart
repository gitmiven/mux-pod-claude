import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/widgets/special_keys_bar.dart';

void main() {
  // Pumps SpecialKeysBar with spy callbacks; returns the recorded keys.
  Future<({List<String> literal, List<String> special})> pumpBar(
    WidgetTester tester,
  ) async {
    final literal = <String>[];
    final special = <String>[];
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpecialKeysBar(
            hapticFeedback: false,
            onKeyPressed: literal.add,
            onSpecialKeyPressed: special.add,
          ),
        ),
      ),
    );
    await tester.pump();
    return (literal: literal, special: special);
  }

  group('SpecialKeysBar special keys', () {
    testWidgets('ESC sends Escape, TAB sends Tab', (tester) async {
      final r = await pumpBar(tester);
      await tester.tap(find.text('ESC'));
      await tester.tap(find.text('TAB'));
      await tester.pump();
      expect(r.special, ['Escape', 'Tab']);
    });

    testWidgets('arrow buttons send Up/Down/Left/Right', (tester) async {
      final r = await pumpBar(tester);
      await tester.tap(find.byIcon(Icons.arrow_drop_up));
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.tap(find.byIcon(Icons.arrow_left));
      await tester.tap(find.byIcon(Icons.arrow_right));
      await tester.pump();
      expect(r.special, ['Up', 'Down', 'Left', 'Right']);
    });

    testWidgets('literal keys go through onKeyPressed', (tester) async {
      final r = await pumpBar(tester);
      await tester.tap(find.text('/'));
      await tester.pump();
      expect(r.literal, contains('/'));
    });
  });

  group('SpecialKeysBar modifiers', () {
    testWidgets('CTRL then ESC sends C-Escape and consumes the modifier',
        (tester) async {
      final r = await pumpBar(tester);
      await tester.tap(find.text('CTRL'));
      await tester.pump();
      await tester.tap(find.text('ESC'));
      await tester.pump();
      expect(r.special, ['C-Escape']);

      // Modifier is one-shot: the next ESC is unmodified.
      await tester.tap(find.text('ESC'));
      await tester.pump();
      expect(r.special, ['C-Escape', 'Escape']);
    });

    testWidgets('CTRL+ALT stack in S-C-M order (C-M-Escape)', (tester) async {
      final r = await pumpBar(tester);
      await tester.tap(find.text('CTRL'));
      await tester.tap(find.text('ALT'));
      await tester.pump();
      await tester.tap(find.text('ESC'));
      await tester.pump();
      expect(r.special, ['C-M-Escape']);
    });

    testWidgets('SHIFT + TAB is the special case BTab (back-tab)',
        (tester) async {
      final r = await pumpBar(tester);
      await tester.tap(find.text('SHIFT'));
      await tester.pump();
      await tester.tap(find.text('TAB'));
      await tester.pump();
      expect(r.special, ['BTab']);
    });

    testWidgets('SHIFT + ESC sends S-Escape', (tester) async {
      final r = await pumpBar(tester);
      await tester.tap(find.text('SHIFT'));
      await tester.pump();
      await tester.tap(find.text('ESC'));
      await tester.pump();
      expect(r.special, ['S-Escape']);
    });
  });
}
