import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Default maximum number of remembered commands.
const int kCommandHistoryCap = 50;

/// Returns [history] with [command] added at the front, deduplicated (exact
/// match — a re-sent command moves to the front) and capped to [cap]. An empty
/// / whitespace-only command is ignored (the same list is returned).
List<String> addCommandToHistory(
  List<String> history,
  String command, {
  int cap = kCommandHistoryCap,
}) {
  final c = command.trim();
  if (c.isEmpty) return history;
  final next = <String>[c, ...history.where((e) => e != c)];
  return next.length > cap ? next.sublist(0, cap) : next;
}

/// Persisted, deduplicated, most-recently-used-first history of commands sent
/// from the "Enter Command" popup.
class CommandHistoryNotifier extends Notifier<List<String>> {
  static const String _key = 'command_history';

  @override
  List<String> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        state = decoded
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // Corrupt history is ignored (stays empty).
    }
  }

  /// Records a sent [command] (deduped, moved to front, capped) and persists.
  Future<void> add(String command) async {
    final next = addCommandToHistory(state, command);
    if (identical(next, state)) return; // empty command → no change
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(next));
  }
}

final commandHistoryProvider =
    NotifierProvider<CommandHistoryNotifier, List<String>>(
  CommandHistoryNotifier.new,
);
