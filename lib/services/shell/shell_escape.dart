/// The single shared mechanism for safely encoding user-supplied values passed to shell/tmux commands.
///
/// Holds the single responsibility of preventing command injection (FR-013). All user-supplied
/// fragments entering commands executed via shell — such as session names, window names, pane IDs,
/// key sends, file paths, and user-specified tmux paths — must pass through this mechanism.
///
/// Method: wrap in double quotes only if the string contains special characters, and escape
/// the internal `\\ " $ \`` sequences. Within double quotes, spaces, `'`, `;`, `|`, `&`, `<`, `>`,
/// `()`, and newlines are all treated as literals, so no additional escaping is required.
class ShellEscape {
  /// Characters that require quoting (characters with special meaning to the shell).
  static final RegExp _needsQuote = RegExp(r'''[\s"'\\$`!{}\[\]<>|&;()]''');

  /// Encodes [arg] as a safe single token for shell arguments.
  ///
  /// - If only safe characters are present, returns it unchanged (for command readability and test compatibility).
  /// - If empty, returns `""` (prevents argument dropout and misalignment of subsequent options).
  /// - Otherwise wraps in double quotes and escapes `\\ " $ \`` sequences.
  static String quote(String arg) {
    if (arg.isEmpty) {
      return '""';
    }
    if (!_needsQuote.hasMatch(arg)) {
      return arg;
    }
    final escaped = arg
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll(r'$', r'\$')
        .replaceAll('`', r'\`');
    return '"$escaped"';
  }
}
