import '../shell/shell_escape.dart';

/// Rewrites command-position `tmux` tokens in a shell command to the detected
/// absolute tmux binary path, and optionally appends a global socket flag
/// (`-L <name>` / `-S <path>`) immediately after the binary.
///
/// On hosts with more than one tmux install (e.g. a user `~/.local/bin/tmux`
/// vs the system `/usr/bin/tmux`), running the *wrong* binary against a tmux
/// server started by the other can fail with a protocol/version mismatch. The
/// app detects one absolute path and must use it for **every** tmux invocation
/// in a command — including those after `|`, `&&`, `;`, or `(` in piped/chained
/// commands such as the multi-line paste pipeline.
///
/// The optional [tmuxSocket] selects a non-default tmux server. It is applied
/// as a global option positioned immediately after the binary (before the
/// subcommand) on **every** command-position `tmux` token, so chained pipelines
/// all target the same server.
class TmuxCommandResolver {
  TmuxCommandResolver._();

  /// Matches a `tmux` token in command position: at the start of the command,
  /// or immediately after a command separator (`| & ; (`), optional whitespace.
  /// `\b` after the word avoids matching `tmuxfoo`; requiring a leading
  /// separator avoids matching `tmux` that appears inside argument data.
  static final RegExp _tmuxToken = RegExp(r'(^|[|&;(]\s*)tmux\b');

  /// Returns [command] with every command-position `tmux` replaced by the
  /// shell-escaped [tmuxPath] (or the literal `tmux` when [tmuxPath] is null),
  /// optionally followed by the [tmuxSocket] global flag.
  ///
  /// When [tmuxPath] is null and no socket is set, returns [command] unchanged
  /// (byte-for-byte), preserving the implicit-default-socket behavior.
  static String resolve(String command, String? tmuxPath, {String? tmuxSocket}) {
    final socketFlag = _socketFlag(tmuxSocket);
    // Nothing to rewrite: no detected binary and no socket flag.
    if (tmuxPath == null && socketFlag.isEmpty) return command;
    final binary = tmuxPath != null ? ShellEscape.quote(tmuxPath) : 'tmux';
    return command.replaceAllMapped(
      _tmuxToken,
      (m) => '${m[1]}$binary$socketFlag',
    );
  }

  /// Builds the global socket flag fragment (with a leading space), or `''`.
  ///
  /// A value containing a `/` is treated as a socket **path** (`-S`), otherwise
  /// as a socket **name** (`-L`). Empty / whitespace-only ⇒ no flag (default
  /// socket). The value is shell-escaped so metacharacters are literal data.
  static String _socketFlag(String? socket) {
    if (socket == null) return '';
    final value = socket.trim();
    if (value.isEmpty) return '';
    final flag = value.contains('/') ? '-S' : '-L';
    return ' $flag ${ShellEscape.quote(value)}';
  }
}
