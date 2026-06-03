import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/providers/file_browser_provider.dart';
import 'package:flutter_muxpod/services/sftp/file_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const visible = FileEntry(
    name: 'README.md',
    fullPath: '/home/me/README.md',
    isDirectory: false,
  );
  const dotfile = FileEntry(
    name: '.claude',
    fullPath: '/home/me/.claude',
    isDirectory: true,
  );

  // NOTE: FileBrowserNotifier.initialize() seeds showHidden from
  // settingsProvider.showHiddenFilesByDefault, but it can't be exercised in a
  // plain container — initialize() builds sshProvider, whose build() starts
  // connectivity monitoring that needs platform channels. So we cover the two
  // halves of that wiring without SSH: the setting round-trips (see
  // settings_show_hidden_test.dart) and the showHidden flag drives visibility
  // and the per-session toggle (below). fileBrowserProvider.build() itself is
  // SSH-free, so the notifier and its state are testable directly.

  group('FileBrowserState.displayEntries honours showHidden', () {
    test('showHidden = true keeps dot-files', () {
      const state = FileBrowserState(entries: [visible, dotfile]);
      final shown = state.copyWith(showHidden: true).displayEntries;
      expect(shown.map((e) => e.name), containsAll(['README.md', '.claude']));
    });

    test('showHidden = false drops dot-files', () {
      const state = FileBrowserState(entries: [visible, dotfile]);
      final shown = state.copyWith(showHidden: false).displayEntries;
      expect(shown.map((e) => e.name), ['README.md']);
    });
  });

  group('FileBrowserNotifier.toggleShowHidden (per-session override)', () {
    test('flips the showHidden flag', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      // build() is SSH-free; default state has showHidden = false.
      expect(c.read(fileBrowserProvider).showHidden, isFalse);

      c.read(fileBrowserProvider.notifier).toggleShowHidden();
      expect(c.read(fileBrowserProvider).showHidden, isTrue);

      c.read(fileBrowserProvider.notifier).toggleShowHidden();
      expect(c.read(fileBrowserProvider).showHidden, isFalse);
    });
  });
}
