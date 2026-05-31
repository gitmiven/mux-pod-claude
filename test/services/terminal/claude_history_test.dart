import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/terminal/claude_history.dart';

void main() {
  String line(String display, int ts, String project) =>
      jsonEncode({'display': display, 'timestamp': ts, 'project': project});

  group('parseClaudeHistory', () {
    test('keeps this-project prompts, most-recent first, deduped', () {
      final jsonl = [
        line('first', 1000, '/proj'),
        line('second', 3000, '/proj'),
        line('first', 5000, '/proj'), // newer duplicate of "first"
        line('other-project', 9000, '/elsewhere'), // filtered out
      ].join('\n');

      // first(5000) newest, then second(3000); "other-project" excluded.
      expect(parseClaudeHistory(jsonl, '/proj'), ['first', 'second']);
    });

    test('skips empty prompts, malformed lines, and blanks', () {
      final jsonl = [
        line('ok', 2000, '/proj'),
        line('   ', 3000, '/proj'), // whitespace display
        '{ not valid json',
        '',
        '"a string, not an object"',
      ].join('\n');
      expect(parseClaudeHistory(jsonl, '/proj'), ['ok']);
    });

    test('caps the result', () {
      final jsonl = List.generate(
        10,
        (i) => line('cmd$i', i * 100, '/proj'),
      ).join('\n');
      final out = parseClaudeHistory(jsonl, '/proj', cap: 3);
      expect(out.length, 3);
      expect(out, ['cmd9', 'cmd8', 'cmd7']); // newest first
    });

    test('no matching project yields empty', () {
      final jsonl = line('x', 1, '/other');
      expect(parseClaudeHistory(jsonl, '/proj'), isEmpty);
    });
  });
}
