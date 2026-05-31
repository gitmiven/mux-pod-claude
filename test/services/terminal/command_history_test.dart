import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_muxpod/services/terminal/command_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('addCommandToHistory', () {
    test('adds to the front', () {
      expect(addCommandToHistory(const [], 'ls'), ['ls']);
      expect(addCommandToHistory(const ['a'], 'b'), ['b', 'a']);
    });

    test('dedups and moves an existing command to the front', () {
      expect(addCommandToHistory(const ['a', 'b', 'c'], 'c'), ['c', 'a', 'b']);
      expect(addCommandToHistory(const ['a', 'b'], 'a'), ['a', 'b']);
    });

    test('ignores empty / whitespace-only commands (same list)', () {
      const h = ['a'];
      expect(identical(addCommandToHistory(h, ''), h), isTrue);
      expect(identical(addCommandToHistory(h, '   '), h), isTrue);
    });

    test('trims the stored command', () {
      expect(addCommandToHistory(const [], '  ls -la  '), ['ls -la']);
    });

    test('caps the list, dropping the oldest', () {
      var h = <String>[];
      for (var i = 0; i < 60; i++) {
        h = addCommandToHistory(h, 'cmd$i', cap: 50);
      }
      expect(h.length, 50);
      expect(h.first, 'cmd59'); // newest
      expect(h.contains('cmd9'), isFalse); // oldest dropped
    });
  });

  group('commandHistoryProvider', () {
    Future<void> drain() async {
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('records sends and round-trips through prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(commandHistoryProvider);
      await drain();

      await c.read(commandHistoryProvider.notifier).add('ls');
      await c.read(commandHistoryProvider.notifier).add('git status');
      await c.read(commandHistoryProvider.notifier).add('ls'); // moves to front
      expect(c.read(commandHistoryProvider), ['ls', 'git status']);

      // New container reads the persisted history.
      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      c2.read(commandHistoryProvider);
      await drain();
      expect(c2.read(commandHistoryProvider), ['ls', 'git status']);
    });
  });
}
