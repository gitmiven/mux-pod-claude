import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/tmux/tmux_parser.dart';

void main() {
  const d = '|||';

  // Builds one `list-panes -a` line. Fields 0..18 mirror the real format;
  // session_activity (field 19) is appended only when [activity] is non-null
  // (an older tmux / a payload without the token omits it).
  String line(String session, {int? activity}) {
    final fields = <String>[
      session, // 0 session_name
      '\$1', // 1 session_id
      '0', // 2 window_index
      '@0', // 3 window_id
      'win', // 4 window_name
      '1', // 5 window_active
      '0', // 6 pane_index
      '%0', // 7 pane_id
      '1', // 8 pane_active
      '80', // 9 pane_width
      '24', // 10 pane_height
      '0', // 11 pane_left
      '0', // 12 pane_top
      '', // 13 pane_title
      'bash', // 14 pane_current_command
      '0', // 15 cursor_x
      '0', // 16 cursor_y
      '/home', // 17 pane_current_path
      '', // 18 window_flags
    ];
    if (activity != null) fields.add('$activity'); // 19 session_activity
    return fields.join(d);
  }

  TmuxSession byName(List<TmuxSession> s, String name) =>
      s.firstWhere((e) => e.name == name);

  group('parseFullTree — session_activity', () {
    test('populates lastActivity from the epoch-seconds token', () {
      final output = [
        line('alpha', activity: 1000),
        line('beta', activity: 3000),
      ].join('\n');

      final sessions = TmuxParser.parseFullTree(output);

      expect(sessions.length, 2);
      expect(byName(sessions, 'alpha').lastActivity!.millisecondsSinceEpoch,
          1000 * 1000);
      expect(byName(sessions, 'beta').lastActivity!.millisecondsSinceEpoch,
          3000 * 1000);
    });

    test('a payload without the token still parses (lastActivity null)', () {
      final output = line('alpha'); // 19 fields, no session_activity
      final sessions = TmuxParser.parseFullTree(output);

      expect(sessions.length, 1);
      expect(sessions.single.name, 'alpha');
      expect(sessions.single.lastActivity, isNull);
    });
  });

  group('TmuxSession.byRecencyDesc', () {
    TmuxSession s(String name, int? activity) => TmuxSession(
          name: name,
          lastActivity: activity == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(activity * 1000),
        );

    test('orders most-recently-active first', () {
      final list = [s('old', 1000), s('new', 3000), s('mid', 2000)]
        ..sort(TmuxSession.byRecencyDesc);
      expect(list.map((e) => e.name).toList(), ['new', 'mid', 'old']);
    });

    test('null activity sorts to the bottom', () {
      final list = [s('unknown', null), s('recent', 5000), s('older', 1000)]
        ..sort(TmuxSession.byRecencyDesc);
      expect(list.map((e) => e.name).toList(), ['recent', 'older', 'unknown']);
    });

    test('ties break on name deterministically (incl. two nulls)', () {
      final list = [s('b', 1000), s('a', 1000), s('z', null), s('m', null)]
        ..sort(TmuxSession.byRecencyDesc);
      // equal activity → name asc; both-null → name asc, after the timed ones
      expect(list.map((e) => e.name).toList(), ['a', 'b', 'm', 'z']);
    });
  });
}
