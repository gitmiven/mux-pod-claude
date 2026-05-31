import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/sftp/file_entry.dart';
import 'package:flutter_muxpod/screens/file_browser/widgets/file_action_menu.dart';

void main() {
  const file = FileEntry(
    name: 'pic.png',
    fullPath: '/home/user/pic.png',
    isDirectory: false,
    size: 1024,
  );
  const dir = FileEntry(
    name: 'docs',
    fullPath: '/home/user/docs',
    isDirectory: true,
  );

  // Pumps a button that opens the menu for [entry] with [viewerLabel].
  Future<void> openMenu(
    WidgetTester tester,
    FileEntry entry, {
    String? viewerLabel,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  FileActionMenu.show(context, entry, viewerLabel: viewerLabel),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows "Open with <viewer>" when a viewer is configured',
      (tester) async {
    await openMenu(tester, file, viewerLabel: 'Image');
    expect(find.text('Open with Image'), findsOneWidget);
    // ...above Rename/Delete, which remain.
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('hides the viewer item when no viewer is configured',
      (tester) async {
    await openMenu(tester, file, viewerLabel: null);
    expect(find.textContaining('Open with'), findsNothing);
    expect(find.text('Rename'), findsOneWidget);
  });

  testWidgets('never shows the viewer item for a directory', (tester) async {
    await openMenu(tester, dir, viewerLabel: 'Image');
    expect(find.textContaining('Open with'), findsNothing);
    expect(find.text('Open'), findsOneWidget); // directories keep plain Open
  });

  testWidgets('selecting the viewer item returns FileAction.openInViewer',
      (tester) async {
    FileAction? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await FileActionMenu.show(context, file,
                    viewerLabel: 'Markdown');
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open with Markdown'));
    await tester.pumpAndSettle();
    expect(result, FileAction.openInViewer);
  });
}
