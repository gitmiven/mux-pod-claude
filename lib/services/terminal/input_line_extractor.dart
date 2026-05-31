/// Extracts the user's typed text from a terminal input line, for pre-filling
/// the command popup.
///
/// The captured line may carry ANSI codes plus a prompt or input-box
/// decoration. This strips, in order: ANSI escapes, a trailing box border, and
/// then either a leading input-box decoration (Claude Code's `│ > `) or a shell
/// prompt ending in `$ `, `# `, or `> `. If no decoration is recognised it falls
/// back to the trimmed raw line, so nothing useful is lost.
class InputLineExtractor {
  InputLineExtractor._();

  static final _ansi = RegExp(r'\x1b\[[0-9;?]*[ -/]*[@-~]');
  static final _trailingBox = RegExp(r'\s*[│┃|]\s*$');
  static final _leadingBox = RegExp(r'^\s*[│┃|]\s*(?:>\s?)?');
  // First prompt char (`$`, `#`, or `>`) followed by a space, non-greedy.
  static final _shellPrompt = RegExp(r'^.*?[\$#>] ');

  static String extract(String line) {
    var s = line.replaceAll(_ansi, '');
    // Strip a trailing box border first so leading-box stripping leaves content.
    s = s.replaceFirst(_trailingBox, '');
    if (_leadingBox.hasMatch(s)) {
      s = s.replaceFirst(_leadingBox, '');
    } else {
      final m = _shellPrompt.firstMatch(s);
      if (m != null) s = s.substring(m.end);
    }
    return s.trim();
  }
}
