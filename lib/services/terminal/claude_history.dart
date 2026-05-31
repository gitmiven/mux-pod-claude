import 'dart:convert';

import '../ssh/ssh_client.dart';

/// Parses Claude Code's `~/.claude/history.jsonl` into the recent prompts for
/// [project] (its working directory) — most-recent first, deduplicated by text,
/// capped to [cap]. Malformed lines, other projects, and empty prompts are
/// skipped. Pure / unit-testable.
List<String> parseClaudeHistory(
  String jsonl,
  String project, {
  int cap = 50,
}) {
  final entries = <({String display, int ts})>[];
  for (final line in const LineSplitter().convert(jsonl)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    try {
      final obj = jsonDecode(trimmed);
      if (obj is! Map) continue;
      if (obj['project'] != project) continue;
      final display = obj['display'];
      if (display is! String || display.trim().isEmpty) continue;
      final ts = obj['timestamp'];
      final tsInt = ts is int ? ts : (ts is num ? ts.toInt() : 0);
      entries.add((display: display, ts: tsInt));
    } catch (_) {
      // skip malformed line
    }
  }
  // Most recent first, then dedupe keeping the newest occurrence.
  entries.sort((a, b) => b.ts.compareTo(a.ts));
  final seen = <String>{};
  final out = <String>[];
  for (final e in entries) {
    if (seen.add(e.display)) out.add(e.display);
    if (out.length >= cap) break;
  }
  return out;
}

/// Reads recent Claude Code prompts for [project] over an existing SSH
/// connection. Returns the most-recent-first unique prompts, or null when the
/// source is unavailable (not connected, file missing, no entries) so the caller
/// can fall back to the app-recorded history.
class ClaudeHistoryReader {
  ClaudeHistoryReader._();

  /// Bound on how much of the (time-ordered) file we read from the end.
  static const int _tailLines = 5000;

  static Future<List<String>?> read(
    SshClient client,
    String project, {
    int cap = 50,
  }) async {
    if (!client.isConnected) return null;
    try {
      final out = await client.exec(
        'tail -n $_tailLines "\$HOME/.claude/history.jsonl" 2>/dev/null',
      );
      if (out.trim().isEmpty) return null;
      final list = parseClaudeHistory(out, project, cap: cap);
      return list.isEmpty ? null : list;
    } catch (_) {
      return null;
    }
  }
}
