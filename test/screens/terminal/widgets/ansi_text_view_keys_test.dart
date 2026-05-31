import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_muxpod/screens/terminal/widgets/ansi_text_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Pumps AnsiTextView and returns the list of KeyInputEvents it emits.
  Future<List<KeyInputEvent>> pumpView(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final events = <KeyInputEvent>[];
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AnsiTextView(
              text: 'hello world',
              paneWidth: 80,
              paneHeight: 24,
              onKeyInput: events.add,
            ),
          ),
        ),
      ),
    );
    // Not pumpAndSettle: the cursor-blink animation repeats forever.
    await tester.pump(); // run post-frame autofocus
    await tester.pump(const Duration(milliseconds: 50)); // settle async settings load
    return events;
  }

  group('AnsiTextView hardware key handling', () {
    testWidgets('Escape → tmux Escape (special, ESC byte)', (tester) async {
      final events = await pumpView(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(events, isNotEmpty);
      expect(events.last.tmuxKeyName, 'Escape');
      expect(events.last.isSpecialKey, isTrue);
      expect(events.last.data, '\x1b');
    });

    testWidgets('Enter → tmux Enter (CR)', (tester) async {
      final events = await pumpView(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(events.last.tmuxKeyName, 'Enter');
      expect(events.last.data, '\r');
    });

    testWidgets('Backspace → tmux BSpace (DEL byte)', (tester) async {
      final events = await pumpView(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(events.last.tmuxKeyName, 'BSpace');
      expect(events.last.data, '\x7f');
    });

    testWidgets('Tab → tmux Tab', (tester) async {
      final events = await pumpView(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(events.last.tmuxKeyName, 'Tab');
      expect(events.last.data, '\t');
    });

    testWidgets('arrow keys → Up/Down/Left/Right special keys', (tester) async {
      final events = await pumpView(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      final names = events.map((e) => e.tmuxKeyName).toList();
      expect(names, containsAllInOrder(['Up', 'Down', 'Left', 'Right']));
    });

    testWidgets('modifier-only key presses do not emit input', (tester) async {
      final events = await pumpView(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(events, isEmpty); // pressing Ctrl alone sends nothing
    });
  });
}
