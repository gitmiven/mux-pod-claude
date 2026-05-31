import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/terminal/shell_history.dart';

void main() {
  group('parseBashHistory', () {
    test('newest first, deduped, skips blanks/comments', () {
      const content = 'ls\n'
          '# a comment\n'
          'git status\n'
          '\n'
          'ls\n'; // newest "ls" duplicate
      // file order oldest→newest: ls, git status, ls → newest-first unique:
      expect(parseBashHistory(content), ['ls', 'git status']);
    });

    test('caps the result', () {
      final content = List.generate(10, (i) => 'cmd$i').join('\n');
      final out = parseBashHistory(content, cap: 3);
      expect(out, ['cmd9', 'cmd8', 'cmd7']); // newest first
    });

    test('empty content yields empty', () {
      expect(parseBashHistory('   \n\n'), isEmpty);
    });
  });

  group('parseZshHistory', () {
    test('extracts commands from extended entries, newest first', () {
      const content = ': 1700000000:0;ls -la\n'
          ': 1700000005:0;git push\n'
          ': 1700000009:0;ls -la\n'; // newest dup
      expect(parseZshHistory(content), ['ls -la', 'git push']);
    });

    test('accepts plain (non-extended) lines too', () {
      const content = 'echo hi\n: 1700000000:3;make build\n';
      expect(parseZshHistory(content), ['make build', 'echo hi']);
    });

    test('skips blanks', () {
      expect(parseZshHistory('\n\n'), isEmpty);
    });
  });
}
