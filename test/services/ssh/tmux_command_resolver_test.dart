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
}
