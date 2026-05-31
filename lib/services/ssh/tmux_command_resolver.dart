import '../shell/shell_escape.dart';

/// Rewrites command-position `tmux` tokens in a shell command to the detected
/// absolute tmux binary path.
///
/// On hosts with more than one tmux install (e.g. a user `~/.local/bin/tmux`
/// vs the system `/usr/bin/tmux`), running the *wrong* binary against a tmux
/// server started by the other can fail with a protocol/version mismatch. The
/// app detects one absolute path and must use it for **every** tmux invocation
/// in a command — including those after `|`, `&&`, `;`, or `(` in piped/chained
/// commands such as the multi-line paste pipeline.
class TmuxCommandResolver {
  TmuxCommandResolver._();

  /// Matches a `tmux` token in command position: at the start of the command,
  /// or immediately after a command separator (`| & ; (`), optional whitespace.
  /// `\b` after the word avoids matching `tmuxfoo`; requiring a leading
  /// separator avoids matching `tmux` that appears inside argument data.
  static final RegExp _tmuxToken = RegExp(r'(^|[|&;(]\s*)tmux\b');

  /// Returns [command] with every command-position `tmux` replaced by the
  /// shell-escaped [tmuxPath]. If [tmuxPath] is null, returns [command] as-is.
  static String resolve(String command, String? tmuxPath) {
    if (tmuxPath == null) return command;
    final safePath = ShellEscape.quote(tmuxPath);
    return command.replaceAllMapped(
      _tmuxToken,
      (m) => '${m[1]}$safePath',
    );
  }
}
