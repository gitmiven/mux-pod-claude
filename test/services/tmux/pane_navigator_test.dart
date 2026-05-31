import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/tmux/pane_navigator.dart';
import 'package:flutter_muxpod/services/tmux/tmux_parser.dart';

void main() {
  group('PaneNavigator', () {
    group('findAdjacentPane', () {
      test('水平2分割でleft/rightナビゲーション', () {
        final panes = [
          const TmuxPane(index: 0, id: '%0', left: 0, top: 0, width: 40, height: 24),
          const TmuxPane(index: 1, id: '%1', left: 41, top: 0, width: 39, height: 24),
        ];

        // From pane0 to the right → pane1
        final right = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[0],
          direction: SwipeDirection.right,
        );
        expect(right?.id, '%1');

        // From pane1 to the left → pane0
        final left = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[1],
          direction: SwipeDirection.left,
        );
        expect(left?.id, '%0');

        // From pane0 to the left → null (edge)
        final noLeft = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[0],
          direction: SwipeDirection.left,
        );
        expect(noLeft, isNull);

        // From pane1 to the right → null (edge)
        final noRight = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[1],
          direction: SwipeDirection.right,
        );
        expect(noRight, isNull);
      });

      test('垂直2分割でup/downナビゲーション', () {
        final panes = [
          const TmuxPane(index: 0, id: '%0', left: 0, top: 0, width: 80, height: 12),
          const TmuxPane(index: 1, id: '%1', left: 0, top: 13, width: 80, height: 11),
        ];

        // From pane0 downward → pane1
        final down = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[0],
          direction: SwipeDirection.down,
        );
        expect(down?.id, '%1');

        // From pane1 upward → pane0
        final up = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[1],
          direction: SwipeDirection.up,
        );
        expect(up?.id, '%0');

        // From pane0 upward → null
        expect(
          PaneNavigator.findAdjacentPane(
            panes: panes,
            current: panes[0],
            direction: SwipeDirection.up,
          ),
          isNull,
        );
      });

      test('垂直3分割で最も近いペインを返す', () {
        final panes = [
          const TmuxPane(index: 0, id: '%0', left: 0, top: 0, width: 80, height: 12),
          const TmuxPane(index: 1, id: '%1', left: 0, top: 13, width: 80, height: 12),
          const TmuxPane(index: 2, id: '%2', left: 0, top: 26, width: 80, height: 11),
        ];

        // From pane0 downward → pane1 (closest pane, not pane2)
        final down = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[0],
          direction: SwipeDirection.down,
        );
        expect(down?.id, '%1');

        // From pane2 upward → pane1
        final up = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[2],
          direction: SwipeDirection.up,
        );
        expect(up?.id, '%1');
      });

      test('T字レイアウトで重なり条件が機能する', () {
        // Top: 1 wide pane
        // Bottom: 2 panes left and right
        final panes = [
          const TmuxPane(index: 0, id: '%0', left: 0, top: 0, width: 80, height: 12),
          const TmuxPane(index: 1, id: '%1', left: 0, top: 13, width: 40, height: 11),
          const TmuxPane(index: 2, id: '%2', left: 41, top: 13, width: 39, height: 11),
        ];

        // From pane0 downward: pane1 or pane2 (both overlap, returns closest)
        final down = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[0],
          direction: SwipeDirection.down,
        );
        expect(down, isNotNull);
        expect(['%1', '%2'], contains(down?.id));

        // From pane1 upward → pane0 (overlap)
        final up = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[1],
          direction: SwipeDirection.up,
        );
        expect(up?.id, '%0');

        // From pane1 to the right → pane2
        final right = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[1],
          direction: SwipeDirection.right,
        );
        expect(right?.id, '%2');
      });

      test('L字レイアウトで重なりがない方向はnull', () {
        // Top-left: pane0
        // Top-right: pane1
        // Bottom-left: pane2 (no pane at bottom-right)
        final panes = [
          const TmuxPane(index: 0, id: '%0', left: 0, top: 0, width: 40, height: 12),
          const TmuxPane(index: 1, id: '%1', left: 41, top: 0, width: 39, height: 24),
          const TmuxPane(index: 2, id: '%2', left: 0, top: 13, width: 40, height: 11),
        ];

        // From pane2 to the right → pane1 (vertical overlap exists)
        final right = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[2],
          direction: SwipeDirection.right,
        );
        expect(right?.id, '%1');
      });

      test('ペインが1つのみの場合は全方向null', () {
        final panes = [
          const TmuxPane(index: 0, id: '%0', left: 0, top: 0, width: 80, height: 24),
        ];

        for (final direction in SwipeDirection.values) {
          expect(
            PaneNavigator.findAdjacentPane(
              panes: panes,
              current: panes[0],
              direction: direction,
            ),
            isNull,
          );
        }
      });

      test('ペインリストが空の場合はnull', () {
        const current = TmuxPane(index: 0, id: '%0', left: 0, top: 0, width: 80, height: 24);
        for (final direction in SwipeDirection.values) {
          expect(
            PaneNavigator.findAdjacentPane(
              panes: const [],
              current: current,
              direction: direction,
            ),
            isNull,
          );
        }
      });
    });

    group('getNavigableDirections', () {
      test('水平2分割で正しい方向マップを返す', () {
        final panes = [
          const TmuxPane(index: 0, id: '%0', left: 0, top: 0, width: 40, height: 24),
          const TmuxPane(index: 1, id: '%1', left: 41, top: 0, width: 39, height: 24),
        ];

        final dirs = PaneNavigator.getNavigableDirections(
          panes: panes,
          current: panes[0],
        );

        expect(dirs[SwipeDirection.right], isTrue);
        expect(dirs[SwipeDirection.left], isFalse);
        expect(dirs[SwipeDirection.up], isFalse);
        expect(dirs[SwipeDirection.down], isFalse);
      });

      test('ペイン1つの場合は全方向false', () {
        final panes = [
          const TmuxPane(index: 0, id: '%0', left: 0, top: 0, width: 80, height: 24),
        ];

        final dirs = PaneNavigator.getNavigableDirections(
          panes: panes,
          current: panes[0],
        );

        for (final dir in SwipeDirection.values) {
          expect(dirs[dir], isFalse);
        }
      });
    });

    group('detectSwipeDirection', () {
      test('右方向のスワイプを検出', () {
        expect(
          PaneNavigator.detectSwipeDirection(const Offset(60, 10)),
          SwipeDirection.right,
        );
      });

      test('左方向のスワイプを検出', () {
        expect(
          PaneNavigator.detectSwipeDirection(const Offset(-60, -10)),
          SwipeDirection.left,
        );
      });

      test('下方向のスワイプを検出', () {
        expect(
          PaneNavigator.detectSwipeDirection(const Offset(10, 60)),
          SwipeDirection.down,
        );
      });

      test('上方向のスワイプを検出', () {
        expect(
          PaneNavigator.detectSwipeDirection(const Offset(-10, -60)),
          SwipeDirection.up,
        );
      });

      test('閾値未満の移動はnull', () {
        expect(
          PaneNavigator.detectSwipeDirection(const Offset(30, 10)),
          isNull,
        );
        expect(
          PaneNavigator.detectSwipeDirection(const Offset(10, 30)),
          isNull,
        );
        expect(
          PaneNavigator.detectSwipeDirection(Offset.zero),
          isNull,
        );
      });

      test('カスタム閾値で検出', () {
        // Not detected with default threshold (50), but detected with threshold 20
        expect(
          PaneNavigator.detectSwipeDirection(const Offset(30, 5)),
          isNull,
        );
        expect(
          PaneNavigator.detectSwipeDirection(const Offset(30, 5), threshold: 20),
          SwipeDirection.right,
        );
      });

      test('dx == dyの場合は垂直方向優先', () {
        // When abs(dx) == abs(dy), enters the dy branch (else)
        expect(
          PaneNavigator.detectSwipeDirection(const Offset(60, 60)),
          SwipeDirection.down,
        );
        expect(
          PaneNavigator.detectSwipeDirection(const Offset(-60, -60)),
          SwipeDirection.up,
        );
      });
    });

    group('SwipeDirectionExtension.inverted', () {
      test('upの反転はdown', () {
        expect(SwipeDirection.up.inverted, SwipeDirection.down);
      });

      test('downの反転はup', () {
        expect(SwipeDirection.down.inverted, SwipeDirection.up);
      });

      test('leftの反転はright', () {
        expect(SwipeDirection.left.inverted, SwipeDirection.right);
      });

      test('rightの反転はleft', () {
        expect(SwipeDirection.right.inverted, SwipeDirection.left);
      });

      test('二重反転で元に戻る', () {
        for (final dir in SwipeDirection.values) {
          expect(dir.inverted.inverted, dir);
        }
      });
    });
  });
}
