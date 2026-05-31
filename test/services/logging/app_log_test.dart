import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/logging/app_log.dart';

void main() {
  final captured = <String>[];

  setUp(() {
    captured.clear();
    AppLog.sink = captured.add;
    AppLog.level = LogLevel.debug;
  });

  tearDown(() {
    AppLog.resetForTesting();
  });

  group('AppLog level gating', () {
    test('level none suppresses everything (release default behaviour)', () {
      AppLog.level = LogLevel.none;
      AppLog.d('d');
      AppLog.i('i');
      AppLog.w('w');
      AppLog.e('e');
      expect(captured, isEmpty);
    });

    test('debug level emits all levels', () {
      AppLog.level = LogLevel.debug;
      AppLog.d('d');
      AppLog.w('w');
      AppLog.e('e');
      expect(captured.length, 3);
    });

    test('warning level suppresses debug/info, emits warning/error', () {
      AppLog.level = LogLevel.warning;
      AppLog.d('d');
      AppLog.i('i');
      AppLog.w('w');
      AppLog.e('e');
      expect(captured.length, 2);
      expect(captured.any((l) => l.contains('w')), isTrue);
      expect(captured.any((l) => l.contains('e')), isTrue);
      expect(captured.any((l) => l.contains('d')), isFalse);
    });
  });

  group('AppLog formatting', () {
    test('includes level label and tag', () {
      AppLog.d('hello', tag: 'Net');
      expect(captured.single, contains('DEBUG'));
      expect(captured.single, contains('[Net]'));
      expect(captured.single, contains('hello'));
    });

    test('omits tag bracket when no tag given', () {
      AppLog.i('plain');
      expect(captured.single, isNot(contains('[')));
      expect(captured.single, contains('plain'));
    });

    test('error logs the error object and stack trace on separate lines', () {
      final st = StackTrace.current;
      AppLog.e('boom', tag: 'X', error: StateError('bad'), stackTrace: st);
      final joined = captured.join('\n');
      expect(joined, contains('boom'));
      expect(joined, contains('bad'));
      expect(joined, contains(st.toString().split('\n').first));
    });
  });

  group('AppLog robustness', () {
    test('never throws even if the sink throws', () {
      AppLog.sink = (_) => throw StateError('sink failed');
      expect(() => AppLog.d('x'), returnsNormally);
      expect(() => AppLog.e('x', error: 'e'), returnsNormally);
    });
  });
}
