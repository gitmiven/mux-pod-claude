import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_muxpod/services/file_browser/file_browser_start.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('startPathCandidates', () {
    test('last-visited mode tries the remembered path first, then CWD', () {
      expect(
        startPathCandidates(
          mode: kFileBrowserStartLastVisited,
          lastPath: '/var/www',
          claudeCodePath: '/home/me',
        ),
        ['/var/www', '/home/me'],
      );
    });

    test('last-visited mode with no remembered path falls back to CWD', () {
      expect(
        startPathCandidates(
          mode: kFileBrowserStartLastVisited,
          lastPath: null,
          claudeCodePath: '/home/me',
        ),
        ['/home/me'],
      );
      expect(
        startPathCandidates(
          mode: kFileBrowserStartLastVisited,
          lastPath: '',
          claudeCodePath: '/home/me',
        ),
        ['/home/me'],
      );
    });

    test('claude-code mode ignores the remembered path (CWD only)', () {
      expect(
        startPathCandidates(
          mode: kFileBrowserStartClaudeCode,
          lastPath: '/var/www',
          claudeCodePath: '/home/me',
        ),
        ['/home/me'],
      );
    });

    test('no usable paths yields an empty list (caller uses home)', () {
      expect(
        startPathCandidates(
          mode: kFileBrowserStartLastVisited,
          lastPath: null,
          claudeCodePath: null,
        ),
        isEmpty,
      );
    });
  });

  group('LastPathStore', () {
    test('round-trips a path per connection', () async {
      SharedPreferences.setMockInitialValues({});
      final store = LastPathStore();

      await store.set('conn-a', '/var/www');
      await store.set('conn-b', '/etc');

      expect(await store.get('conn-a'), '/var/www');
      expect(await store.get('conn-b'), '/etc');
      // connections don't cross
      expect(await store.get('conn-c'), isNull);
    });

    test('persists across a new store instance', () async {
      SharedPreferences.setMockInitialValues({});
      await LastPathStore().set('conn-a', '/srv');
      expect(await LastPathStore().get('conn-a'), '/srv');
    });

    test('set overwrites the remembered path', () async {
      SharedPreferences.setMockInitialValues({});
      final store = LastPathStore();
      await store.set('conn-a', '/one');
      await store.set('conn-a', '/two');
      expect(await store.get('conn-a'), '/two');
    });

    test('ignores empty connection id or path', () async {
      SharedPreferences.setMockInitialValues({});
      final store = LastPathStore();
      await store.set('', '/x');
      await store.set('conn-a', '');
      expect(await store.get('conn-a'), isNull);
    });
  });
}
