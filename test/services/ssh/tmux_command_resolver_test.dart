import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/ssh/tmux_command_resolver.dart';
import 'package:flutter_muxpod/services/tmux/tmux_commands.dart';

void main() {
  const path = '/home/miven/.local/bin/tmux';

  String r(String cmd) => TmuxCommandResolver.resolve(cmd, path);

  group('TmuxCommandResolver.resolve', () {
    test('null path leaves the command unchanged', () {
      expect(TmuxCommandResolver.resolve('tmux ls', null), 'tmux ls');
    });

    test('rewrites a leading tmux', () {
      expect(r('tmux list-sessions'), '$path list-sessions');
    });

    test('rewrites tmux after a semicolon', () {
      expect(r('tmux a; tmux b'), '$path a; $path b');
    });

    // The bug: tmux after a pipe / && was left bare → wrong binary.
    test('rewrites tmux after a pipe', () {
      expect(r('cat x | tmux load-buffer -'), 'cat x | $path load-buffer -');
    });

    test('rewrites tmux after && and &', () {
      expect(r('a && tmux paste-buffer'), 'a && $path paste-buffer');
      expect(r('a & tmux paste-buffer'), 'a & $path paste-buffer');
    });

    test('rewrites tmux inside a subshell', () {
      expect(r('(tmux kill-server)'), '($path kill-server)');
    });

    test('does NOT rewrite tmux that is an argument (not command position)', () {
      expect(r('echo tmux'), 'echo tmux');
      expect(r("printf '%s' 'xtmuxy'"), "printf '%s' 'xtmuxy'");
    });

    test('the real load-buffer/paste-buffer command gets BOTH tmux tokens fixed',
        () {
      final cmd = TmuxCommands.loadBufferAndPaste('%38', 'echo hi');
      final resolved = r(cmd);
      // No bare "tmux " command word should remain (only "$path ").
      expect(resolved, isNot(contains('| tmux ')));
      expect(resolved, isNot(contains('&& tmux ')));
      expect(resolved.split('$path ').length - 1, 2); // both occurrences rewritten
    });

    test('a path needing escaping is shell-quoted', () {
      final resolved =
          TmuxCommandResolver.resolve('tmux ls', '/opt/my tmux/tmux');
      expect(resolved, '"/opt/my tmux/tmux" ls');
    });
  });

  group('TmuxCommandResolver.resolve socket flag', () {
    test('a socket name becomes a -L flag after the binary', () {
      expect(
        TmuxCommandResolver.resolve('tmux list-sessions', path,
            tmuxSocket: 'fleet'),
        '$path -L fleet list-sessions',
      );
    });

    test('a socket path (contains /) becomes a -S flag', () {
      expect(
        TmuxCommandResolver.resolve('tmux ls', path,
            tmuxSocket: '/tmp/tmux-1000/fleet'),
        '$path -S /tmp/tmux-1000/fleet ls',
      );
    });

    test('an unset/empty/whitespace socket emits no flag', () {
      expect(
        TmuxCommandResolver.resolve('tmux ls', path, tmuxSocket: null),
        '$path ls',
      );
      expect(
        TmuxCommandResolver.resolve('tmux ls', path, tmuxSocket: ''),
        '$path ls',
      );
      expect(
        TmuxCommandResolver.resolve('tmux ls', path, tmuxSocket: '   '),
        '$path ls',
      );
    });

    test('no tmux path + socket set uses the literal tmux binary', () {
      expect(
        TmuxCommandResolver.resolve('tmux ls', null, tmuxSocket: 'fleet'),
        'tmux -L fleet ls',
      );
    });

    test('no tmux path + no socket leaves the command byte-for-byte unchanged',
        () {
      expect(
        TmuxCommandResolver.resolve('tmux ls', null, tmuxSocket: '  '),
        'tmux ls',
      );
    });

    test('a socket name with spaces is shell-quoted', () {
      expect(
        TmuxCommandResolver.resolve('tmux ls', path, tmuxSocket: 'my sock'),
        '$path -L "my sock" ls',
      );
    });

    test('a socket path with spaces is shell-quoted as -S', () {
      expect(
        TmuxCommandResolver.resolve('tmux ls', path, tmuxSocket: '/tmp/a b/x'),
        '$path -S "/tmp/a b/x" ls',
      );
    });

    test('EVERY tmux token in the paste pipeline gets the socket flag', () {
      final cmd = TmuxCommands.loadBufferAndPaste('%38', 'echo hi');
      final resolved =
          TmuxCommandResolver.resolve(cmd, path, tmuxSocket: 'fleet');
      // No bare or path-only tmux token may remain without the socket flag.
      expect(resolved, isNot(contains('| tmux ')));
      expect(resolved, isNot(contains('&& tmux ')));
      expect(resolved.contains('| $path -L fleet load-buffer'), isTrue);
      expect(resolved.contains('&& $path -L fleet paste-buffer'), isTrue);
      // Both tmux invocations carry the flag (2 occurrences).
      expect('-L fleet '.allMatches(resolved).length, 2);
    });

    test('resolving an already-resolved command does NOT double the flag', () {
      // execPersistent historically passed the resolved string back through
      // exec(); resolution must be idempotent for the absolute-path case.
      final once =
          TmuxCommandResolver.resolve('tmux ls', path, tmuxSocket: 'fleet');
      final twice =
          TmuxCommandResolver.resolve(once, path, tmuxSocket: 'fleet');
      expect(twice, once);
      expect('-L fleet'.allMatches(twice).length, 1);
    });
  });
}
