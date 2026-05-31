import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_muxpod/providers/settings_provider.dart';
import 'package:flutter_muxpod/services/viewer/file_viewer_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Lets the provider's async _loadSettings()/save complete.
  Future<void> drain() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<ProviderContainer> freshContainer() async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(settingsProvider); // trigger build() → _loadSettings()
    await drain();
    return c;
  }

  group('AppSettings.fileViewers', () {
    test('defaults are present on first run', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await freshContainer();
      expect(c.read(settingsProvider).fileViewers, kDefaultFileViewers);
    });

    test('setFileViewer persists and round-trips through prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await freshContainer();

      await c
          .read(settingsProvider.notifier)
          .setFileViewer('PNG', FileViewerType.text); // key normalised to 'png'
      expect(c.read(settingsProvider).fileViewers['png'], 'text');

      // A brand-new container must read the persisted value back.
      final c2 = await freshContainer();
      expect(c2.read(settingsProvider).fileViewers['png'], 'text');
    });

    test('removeFileViewer deletes a mapping', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await freshContainer();

      await c.read(settingsProvider.notifier).removeFileViewer('md');
      expect(c.read(settingsProvider).fileViewers.containsKey('md'), isFalse);
    });

    test('an unrecognised viewer type is dropped on save', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await freshContainer();

      await c
          .read(settingsProvider.notifier)
          .setFileViewers({'png': 'image', 'foo': 'bogus'});
      final fv = c.read(settingsProvider).fileViewers;
      expect(fv['png'], 'image');
      expect(fv.containsKey('foo'), isFalse);
    });
  });
}
