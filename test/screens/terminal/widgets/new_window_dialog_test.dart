import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/screens/terminal/widgets/new_window_dialog.dart';

void main() {
  // Opens NewWindowDialog via showDialog and returns the captured pop result.
  Future<String?> openDialog(
    WidgetTester tester, {
    List<String> existing = const [],
  }) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) =>
                      NewWindowDialog(existingWindowNames: existing),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result; // populated after the dialog closes
  }

  group('NewWindowDialog validation', () {
    testWidgets('rejects names with shell/special characters', (tester) async {
      await openDialog(tester);
      await tester.enterText(find.byType(TextFormField), 'bad;name');
      await tester.tap(find.text('Create'));
      await tester.pump();
      expect(find.text('Only letters, numbers, - and _ allowed'), findsOneWidget);
      // Dialog stays open (not submitted).
      expect(find.byType(NewWindowDialog), findsOneWidget);
    });

    testWidgets('rejects a duplicate window name', (tester) async {
      await openDialog(tester, existing: ['build']);
      await tester.enterText(find.byType(TextFormField), 'build');
      await tester.tap(find.text('Create'));
      await tester.pump();
      expect(find.text('Window "build" already exists'), findsOneWidget);
    });

    testWidgets('accepts a valid name and pops it', (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) =>
                        const NewWindowDialog(existingWindowNames: ['build']),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'deploy-2');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.byType(NewWindowDialog), findsNothing); // closed
      expect(result, 'deploy-2');
    });
  });
}
