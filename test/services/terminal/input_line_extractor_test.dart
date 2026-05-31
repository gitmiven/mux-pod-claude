import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/terminal/input_line_extractor.dart';

void main() {
  String e(String s) => InputLineExtractor.extract(s);

  group('InputLineExtractor.extract', () {
    test('strips a Claude-style input box (│ > )', () {
      expect(e('│ > git comm'), 'git comm');
      expect(e('│ > git comm        │'), 'git comm'); // trailing border
    });

    test('strips a box continuation line (no >)', () {
      expect(e('│   more text          │'), 'more text');
    });

    test('strips a shell prompt ending in \$ / # / >', () {
      expect(e(r'me@host:~/proj$ ls -la'), 'ls -la');
      expect(e('# rm -rf build'), 'rm -rf build');
      expect(e('> continued cmd'), 'continued cmd');
    });

    test('strips ANSI escapes before the prompt/box', () {
      expect(e('\x1b[32m\$\x1b[0m ls'), 'ls');
      expect(e('\x1b[34m│\x1b[0m > hello'), 'hello');
    });

    test('falls back to the trimmed raw line when no decoration', () {
      expect(e('just some text'), 'just some text');
      expect(e('   padded   '), 'padded');
    });

    test('empty / prompt-only lines yield empty', () {
      expect(e(''), '');
      expect(e(r'me@host:~$ '), '');
      expect(e('│ > │'), '');
    });
  });
}
