import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/screens/terminal/widgets/input_dialog_content.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required List<String> recent,
    required Future<void> Function(String) onSend,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InputDialogContent(
            onValueChanged: (_) {},
            onSend: onSend,
            recentCommands: recent,
          ),
        ),
      ),
    );
  }

  testWidgets('shows a history button (not the Shift+Enter badge)',
      (tester) async {
    await pump(tester, recent: const [], onSend: (_) async {});
    await tester.pump();
    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(find.text('Shift+Enter: new line'), findsNothing);
  });

  testWidgets('tapping the history button lists recent commands and sends one',
      (tester) async {
    String? sent;
    await pump(
      tester,
      recent: const ['git status', 'ls -la'],
      onSend: (v) async => sent = v,
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();

    expect(find.text('Recent commands'), findsOneWidget);
    expect(find.text('git status'), findsOneWidget);
    expect(find.text('ls -la'), findsOneWidget);

    await tester.tap(find.text('ls -la'));
    await tester.pumpAndSettle();
    expect(sent, 'ls -la');
  });

  testWidgets('empty history shows an empty state', (tester) async {
    await pump(tester, recent: const [], onSend: (_) async {});
    await tester.pump();

    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.text('No recent commands yet'), findsOneWidget);
  });
}
