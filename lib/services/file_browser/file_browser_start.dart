import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Start-directory modes for the file browser (see `AppSettings.fileBrowserStartDir`).
const String kFileBrowserStartClaudeCode = 'claudeCodeFolder';
const String kFileBrowserStartLastVisited = 'lastVisited';

/// Ordered directory candidates to open the browser at, given the start [mode],
/// the remembered [lastPath], and the pane CWD [claudeCodePath].
///
/// The caller tries them in order and uses the first that loads; if none load
/// (or the list is empty) it falls back to the home directory. With
/// [kFileBrowserStartLastVisited] the remembered path is tried first; otherwise
/// (and always as a fallback) the Claude Code folder is used.
List<String> startPathCandidates({
  required String mode,
  String? lastPath,
  String? claudeCodePath,
}) {
  final out = <String>[];
  if (mode == kFileBrowserStartLastVisited &&
      lastPath != null &&
      lastPath.isNotEmpty) {
    out.add(lastPath);
  }
  if (claudeCodePath != null && claudeCodePath.isNotEmpty) {
    out.add(claudeCodePath);
  }
  return out;
}

/// Persists the last directory the file browser was in, **per connection**, so
/// "open at last visited" survives app restarts without crossing servers.
class LastPathStore {
  static const String _key = 'file_browser_last_paths';

  Future<Map<String, String>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  /// The remembered path for [connectionId], or null if none.
  Future<String?> get(String connectionId) async {
    final map = await _read();
    final path = map[connectionId];
    return (path != null && path.isNotEmpty) ? path : null;
  }

  /// Remembers [path] as the last-visited directory for [connectionId].
  Future<void> set(String connectionId, String path) async {
    if (connectionId.isEmpty || path.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final map = await _read();
    map[connectionId] = path;
    await prefs.setString(_key, jsonEncode(map));
  }
}
