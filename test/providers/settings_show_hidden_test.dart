import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_muxpod/providers/settings_provider.dart';

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

  group('AppSettings.showHiddenFilesByDefault', () {
    test('defaults to false', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await freshContainer();
      expect(c.read(settingsProvider).showHiddenFilesByDefault, isFalse);
    });

    test('set persists and round-trips through prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await freshContainer();

      await c
          .read(settingsProvider.notifier)
          .setShowHiddenFilesByDefault(true);
      expect(c.read(settingsProvider).showHiddenFilesByDefault, isTrue);

      final c2 = await freshContainer();
      expect(c2.read(settingsProvider).showHiddenFilesByDefault, isTrue);
    });
  });
}
