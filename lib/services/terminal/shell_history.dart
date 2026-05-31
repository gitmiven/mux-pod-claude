import 'dart:convert';

import '../ssh/ssh_client.dart';

/// Parses a bash history file (`~/.bash_history`: one command per line, newest
/// last, no timestamps) into recent unique commands, **newest first**, capped.
/// Blank and comment (`#…`) lines are skipped.
List<String> parseBashHistory(String content, {int cap = 50}) {
  return _dedupeNewestFirst(
    const LineSplitter().convert(content),
    (line) {
      final cmd = line.trim();
      if (cmd.isEmpty || cmd.startsWith('#')) return null;
      return cmd;
    },
    cap,
  );
}

/// Parses a zsh history file (`~/.zsh_history`): extended entries
/// `: <epoch>:<dur>;<command>` or plain lines, newest last. Returns recent
/// unique commands, **newest first**, capped.
List<String> parseZshHistory(String content, {int cap = 50}) {
  final extended = RegExp(r'^: \d+:\d+;(.*)$');
  return _dedupeNewestFirst(
    const LineSplitter().convert(content),
    (line) {
      final m = extended.firstMatch(line);
      final cmd = (m != null ? m.group(1)! : line).trim();
      return cmd.isEmpty ? null : cmd;
    },
    cap,
  );
}

/// Iterates [lines] from the end (newest first), maps each via [extract]
/// (null = skip), dedupes, and caps.
List<String> _dedupeNewestFirst(
  List<String> lines,
  String? Function(String line) extract,
  int cap,
) {
  final out = <String>[];
  final seen = <String>{};
  for (final line in lines.reversed) {
    final cmd = extract(line);
    if (cmd == null) continue;
    if (seen.add(cmd)) out.add(cmd);
    if (out.length >= cap) break;
  }
  return out;
}

/// Reads recent shell-history commands over an existing SSH connection,
/// choosing bash vs zsh from the pane's foreground command [shellHint]. Returns
/// the most-recent-first unique commands, or null when unavailable (not
/// connected / no history) so the caller can fall back.
class ShellHistoryReader {
  ShellHistoryReader._();

  static const int _tailLines = 2000;

  static Future<List<String>?> read(
    SshClient client, {
    String? shellHint,
    int cap = 50,
  }) async {
    if (!client.isConnected) return null;
    final hint = (shellHint ?? '').toLowerCase();

    Future<List<String>> readZsh() async =>
        parseZshHistory(await _tail(client, r'$HOME/.zsh_history'), cap: cap);
    Future<List<String>> readBash() async =>
        parseBashHistory(await _tail(client, r'$HOME/.bash_history'), cap: cap);

    try {
      // Preferred shell first, then the other as a fallback.
      final preferZsh = hint.contains('zsh');
      final first = preferZsh ? await readZsh() : await readBash();
      if (first.isNotEmpty) return first;
      final second = preferZsh ? await readBash() : await readZsh();
      return second.isEmpty ? null : second;
    } catch (_) {
      return null;
    }
  }

  static Future<String> _tail(SshClient client, String path) async {
    try {
      return await client.exec('tail -n $_tailLines "$path" 2>/dev/null');
    } catch (_) {
      return '';
    }
  }
}
