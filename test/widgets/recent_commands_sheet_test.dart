import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/widgets/recent_commands_sheet.dart';

void main() {
  Future<void> pumpOpener(
    WidgetTester tester, {
    List<String> fallback = const [],
    Future<List<String>> Function()? load,
    required void Function(String) onSelected,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showRecentCommandsSheet(
                context,
                fallback: fallback,
                load: load,
                onSelected: onSelected,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('async load shows the loaded list; tapping selects', (tester) async {
    String? sel;
    await pumpOpener(
      tester,
      fallback: const ['fallback-cmd'],
      load: () async => ['claude-1', 'claude-2'],
      onSelected: (c) => sel = c,
    );
    await tester.tap(find.text('open'));
    await tester.pump(); // sheet opens, loader in flight
    await tester.pumpAndSettle(); // loader resolves

    expect(find.text('claude-1'), findsOneWidget);
    expect(find.text('fallback-cmd'), findsNothing);

    await tester.tap(find.text('claude-2'));
    await tester.pumpAndSettle();
    expect(sel, 'claude-2');
  });

  testWidgets('empty load result falls back to the fallback list',
      (tester) async {
    await pumpOpener(
      tester,
      fallback: const ['app-history-cmd'],
      load: () async => <String>[],
      onSelected: (_) {},
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('app-history-cmd'), findsOneWidget);
  });

  testWidgets('no loader shows the fallback list directly', (tester) async {
    await pumpOpener(
      tester,
      fallback: const ['only-cmd'],
      load: null,
      onSelected: (_) {},
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('only-cmd'), findsOneWidget);
  });
}
