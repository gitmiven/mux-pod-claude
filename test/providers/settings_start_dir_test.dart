import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_muxpod/providers/settings_provider.dart';
import 'package:flutter_muxpod/services/file_browser/file_browser_start.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> drain() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<ProviderContainer> freshContainer() async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(settingsProvider);
    await drain();
    return c;
  }

  group('AppSettings.fileBrowserStartDir', () {
    test('defaults to the Claude Code folder', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await freshContainer();
      expect(
        c.read(settingsProvider).fileBrowserStartDir,
        kFileBrowserStartClaudeCode,
      );
    });

    test('set persists and round-trips through prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await freshContainer();

      await c
          .read(settingsProvider.notifier)
          .setFileBrowserStartDir(kFileBrowserStartLastVisited);
      expect(
        c.read(settingsProvider).fileBrowserStartDir,
        kFileBrowserStartLastVisited,
      );

      final c2 = await freshContainer();
      expect(
        c2.read(settingsProvider).fileBrowserStartDir,
        kFileBrowserStartLastVisited,
      );
    });

    test('an unknown value normalises to the Claude Code folder', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await freshContainer();
      await c.read(settingsProvider.notifier).setFileBrowserStartDir('bogus');
      expect(
        c.read(settingsProvider).fileBrowserStartDir,
        kFileBrowserStartClaudeCode,
      );
    });
  });
}
