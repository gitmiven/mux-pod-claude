import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'active_session_provider.dart';

/// Session history provider sorted by last access time
/// Sorted in descending order by lastAccessedAt (newest first)
final sessionHistoryProvider = Provider<List<ActiveSession>>((ref) {
  final state = ref.watch(activeSessionsProvider);

  final sorted = [...state.sessions]..sort((a, b) {
    // Fall back to connectedAt if lastAccessedAt is not available
    final aTime = a.lastAccessedAt ?? a.connectedAt;
    final bTime = b.lastAccessedAt ?? b.connectedAt;
    return bTime.compareTo(aTime); // Descending order
  });

  return sorted;
});
