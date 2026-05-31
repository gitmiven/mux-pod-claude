import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/widgets/special_keys_bar.dart';

void main() {
  Future<({List<String> special, List<String> sent})> pumpBar(
    WidgetTester tester, {
    List<String> recent = const [],
  }) async {
    final special = <String>[];
    final sent = <String>[];
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SpecialKeysBar(
              hapticFeedback: false,
              onKeyPressed: (_) {},
              onSpecialKeyPressed: special.add,
              recentCommands: recent,
              onSendCommand: sent.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return (special: special, sent: sent);
  }

  group('arrow re-layout', () {
    testWidgets('Up is in the modifier row; Left/Down/Right in the arrow row',
        (tester) async {
      await pumpBar(tester);
      // one of each arrow, no duplicate Up
      expect(find.byIcon(Icons.arrow_drop_up), findsOneWidget); // Up (bar 2)
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget); // Down (bar 3)
      expect(find.byIcon(Icons.arrow_left), findsOneWidget);
      expect(find.byIcon(Icons.arrow_right), findsOneWidget);
    });

    testWidgets('Up is positioned exactly above Down', (tester) async {
      await pumpBar(tester);
      final up = tester.getCenter(find.byIcon(Icons.arrow_drop_up));
      final down = tester.getCenter(find.byIcon(Icons.arrow_drop_down));
      expect((up.dx - down.dx).abs(), lessThan(0.5), reason: 'Up over Down');
      expect(up.dy, lessThan(down.dy), reason: 'Up is on the row above');
    });

    testWidgets('tapping arrows still sends the right keys', (tester) async {
      final r = await pumpBar(tester);
      await tester.tap(find.byIcon(Icons.arrow_drop_up));
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.tap(find.byIcon(Icons.arrow_left));
      await tester.tap(find.byIcon(Icons.arrow_right));
      expect(r.special, ['Up', 'Down', 'Left', 'Right']);
    });
  });

  group('bar history button', () {
    testWidgets('opens the picker and sends a selected command', (tester) async {
      final r = await pumpBar(tester, recent: const ['ls -la', 'git status']);
      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      expect(find.text('Recent commands'), findsOneWidget);
      expect(find.text('ls -la'), findsOneWidget);

      await tester.tap(find.text('git status'));
      await tester.pumpAndSettle();
      expect(r.sent, ['git status']);
    });

    testWidgets('empty history shows the empty state', (tester) async {
      await pumpBar(tester, recent: const []);
      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();
      expect(find.text('No recent commands yet'), findsOneWidget);
    });
  });
}
