import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/shell/shell_escape.dart';

void main() {
  group('ShellEscape.quote', () {
    test('returns safe words unquoted', () {
      expect(ShellEscape.quote('hello'), 'hello');
      expect(ShellEscape.quote('%0'), '%0');
      expect(ShellEscape.quote('my-session'), 'my-session');
      expect(ShellEscape.quote('/usr/bin/tmux'), '/usr/bin/tmux');
      expect(
        ShellEscape.quote('img_20260403_a3f2.png'),
        'img_20260403_a3f2.png',
      );
      expect(ShellEscape.quote('session:0.0'), 'session:0.0');
    });

    test('quotes empty string as ""', () {
      expect(ShellEscape.quote(''), '""');
    });

    test('quotes values containing spaces', () {
      expect(ShellEscape.quote('my session'), '"my session"');
      expect(ShellEscape.quote('/home/my projects'), '"/home/my projects"');
    });

    group('command-injection metacharacters are neutralised', () {
      test('semicolon', () {
        expect(ShellEscape.quote('report;backup'), '"report;backup"');
      });

      test('pipe / and / background', () {
        expect(ShellEscape.quote('a|b'), '"a|b"');
        expect(ShellEscape.quote('a&b'), '"a&b"');
      });

      test('redirections', () {
        expect(ShellEscape.quote('a<b'), '"a<b"');
        expect(ShellEscape.quote('a>b'), '"a>b"');
      });

      test('command substitution \$() is escaped, not executable', () {
        expect(ShellEscape.quote(r'$(id)'), r'"\$(id)"');
        expect(ShellEscape.quote(r'x;$(rm -rf ~)'), r'"x;\$(rm -rf ~)"');
      });

      test('backticks are escaped', () {
        expect(ShellEscape.quote('`id`'), r'"\`id\`"');
      });

      test('dollar variable expansion is escaped', () {
        expect(ShellEscape.quote(r'$HOME'), r'"\$HOME"');
      });

      test('double quotes are escaped', () {
        expect(ShellEscape.quote('a"b'), r'"a\"b"');
      });

      test('backslash is escaped', () {
        expect(ShellEscape.quote(r'a\b'), r'"a\\b"');
      });

      test('single quotes survive inside double quotes (no escape needed)', () {
        expect(ShellEscape.quote("it's"), '"it\'s"');
      });

      test('newlines are kept literal inside quotes', () {
        expect(ShellEscape.quote('line1\nline2'), '"line1\nline2"');
      });
    });

    test('combined adversarial payload', () {
      // A session name attempting to break out and run a command.
      const evil = r'foo"; rm -rf $HOME #';
      final quoted = ShellEscape.quote(evil);
      // Must be wrapped in double quotes with the inner " and $ escaped.
      expect(quoted.startsWith('"'), isTrue);
      expect(quoted.endsWith('"'), isTrue);
      expect(quoted, contains(r'\"'));
      expect(quoted, contains(r'\$HOME'));
    });
  });
}
