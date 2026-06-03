import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/terminal/keyboard_scroll.dart';

void main() {
  group('shouldScrollOnKeyboardShow', () {
    test('rising edge (hidden -> shown) triggers a scroll', () {
      expect(
        shouldScrollOnKeyboardShow(
          prevInset: 0,
          newInset: 320,
          isScrollMode: false,
        ),
        isTrue,
      );
    });

    test('no change while shown does not re-trigger', () {
      expect(
        shouldScrollOnKeyboardShow(
          prevInset: 320,
          newInset: 320,
          isScrollMode: false,
        ),
        isFalse,
      );
    });

    test('falling edge (shown -> hidden) does not trigger', () {
      expect(
        shouldScrollOnKeyboardShow(
          prevInset: 320,
          newInset: 0,
          isScrollMode: false,
        ),
        isFalse,
      );
    });

    test('stays hidden (e.g. rotation with no keyboard) does not trigger', () {
      expect(
        shouldScrollOnKeyboardShow(
          prevInset: 0,
          newInset: 0,
          isScrollMode: false,
        ),
        isFalse,
      );
    });

    test('scroll mode suppresses the jump even on a show edge', () {
      expect(
        shouldScrollOnKeyboardShow(
          prevInset: 0,
          newInset: 320,
          isScrollMode: true,
        ),
        isFalse,
      );
    });

    test('small insets below threshold (nav/gesture bar) do not count as shown',
        () {
      expect(
        shouldScrollOnKeyboardShow(
          prevInset: 0,
          newInset: 40,
          isScrollMode: false,
        ),
        isFalse,
      );
    });

    test('custom threshold is respected', () {
      expect(
        shouldScrollOnKeyboardShow(
          prevInset: 0,
          newInset: 120,
          isScrollMode: false,
          threshold: 200,
        ),
        isFalse,
      );
      expect(
        shouldScrollOnKeyboardShow(
          prevInset: 0,
          newInset: 250,
          isScrollMode: false,
          threshold: 200,
        ),
        isTrue,
      );
    });
  });
}
