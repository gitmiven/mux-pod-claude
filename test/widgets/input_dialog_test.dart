import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/screens/terminal/widgets/input_dialog_content.dart';

/// Helper that wraps the dialog content in a testable widget tree.
Widget _buildWidget({
  String initialValue = '',
  required void Function(String) onValueChanged,
  required Future<void> Function(String) onSend,
}) {
  return MaterialApp(
    home: Scaffold(
      body: InputDialogContent(
        initialValue: initialValue,
        onValueChanged: onValueChanged,
        onSend: onSend,
      ),
    ),
  );
}

void main() {
  group('InputDialogContent – Enter key behaviour', () {
    testWidgets('plain Enter calls onSend exactly once', (tester) async {
      int sendCount = 0;
      await tester.pumpWidget(_buildWidget(
        initialValue: 'hello',
        onValueChanged: (_) {},
        onSend: (v) async => sendCount++,
      ));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(sendCount, 1);
    });

    testWidgets('Shift+Enter inserts newline and does not call onSend',
        (tester) async {
      int sendCount = 0;
      String? lastValue;
      await tester.pumpWidget(_buildWidget(
        initialValue: 'hello',
        onValueChanged: (v) => lastValue = v,
        onSend: (v) async => sendCount++,
      ));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(sendCount, 0);
      expect(lastValue, contains('\n'));
    });

    testWidgets(
        'Enter while composing range is active does not call onSend',
        (tester) async {
      int sendCount = 0;
      await tester.pumpWidget(_buildWidget(
        initialValue: '',
        onValueChanged: (_) {},
        onSend: (v) async => sendCount++,
      ));
      await tester.pump();

      // Simulate IME composition: set composing range to a non-collapsed range.
      final TextField textField =
          tester.widget<TextField>(find.byType(TextField));
      final TextEditingController controller = textField.controller!;
      controller.value = const TextEditingValue(
        text: 'あ',
        composing: TextRange(start: 0, end: 1),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(sendCount, 0);
      expect(controller.text, 'あ');
    });
  });

  group('InputDialogContent – soft keyboard (IME action)', () {
    testWidgets('the field requests the send IME action', (tester) async {
      await tester.pumpWidget(_buildWidget(
        onValueChanged: (_) {},
        onSend: (_) async {},
      ));
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textInputAction, TextInputAction.send);
    });

    // Regression: on a phone soft keyboard, Enter emits the IME submit action
    // (not a hardware KeyEvent). Previously the field used the newline action
    // with no onSubmitted, so Enter inserted a newline and never sent.
    testWidgets('soft-keyboard send action calls onSend exactly once',
        (tester) async {
      int sendCount = 0;
      await tester.pumpWidget(_buildWidget(
        initialValue: 'ls -la',
        onValueChanged: (_) {},
        onSend: (v) async => sendCount++,
      ));
      await tester.pumpAndSettle(); // let autofocus connect the input client

      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();

      expect(sendCount, 1);
    });
  });
}
