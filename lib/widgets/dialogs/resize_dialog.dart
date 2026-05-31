import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/terminal/font_calculator.dart';
import '../../services/tmux/tmux_parser.dart';
import '../../theme/design_colors.dart';

/// Resize result
class ResizeResult {
  final int cols;
  final int rows;
  const ResizeResult({required this.cols, required this.rows});
}

/// Preset size definition
class _SizePreset {
  final String label;
  final int cols;
  final int rows;
  const _SizePreset(this.label, this.cols, this.rows);
}

// ====================================================================
// ResizePaneDialog
// ====================================================================

/// Dialog for pane resizing
class ResizePaneDialog extends StatefulWidget {
  final TmuxPane targetPane;
  final List<TmuxPane> allPanesInWindow;
  final int currentCols;
  final int currentRows;
  final double screenWidth;
  final double screenHeight;
  final double fontSize;
  final String fontFamily;

  const ResizePaneDialog({
    super.key,
    required this.targetPane,
    required this.allPanesInWindow,
    required this.currentCols,
    required this.currentRows,
    required this.screenWidth,
    required this.screenHeight,
    required this.fontSize,
    required this.fontFamily,
  });

  @override
  State<ResizePaneDialog> createState() => _ResizePaneDialogState();
}

class _ResizePaneDialogState extends State<ResizePaneDialog> {
  late int _cols;
  late int _rows;

  @override
  void initState() {
    super.initState();
    _cols = widget.currentCols;
    _rows = widget.currentRows;
  }

  List<_SizePreset> get _presets {
    final matchCols = FontCalculator.calculateMaxCols(
      screenWidth: widget.screenWidth,
      fontSize: widget.fontSize,
      fontFamily: widget.fontFamily,
    );
    final matchRows = FontCalculator.calculateMaxRows(
      screenHeight: widget.screenHeight,
      fontSize: widget.fontSize,
      fontFamily: widget.fontFamily,
    );
    return [
      const _SizePreset('80x24 (Standard)', 80, 24),
      const _SizePreset('120x40 (Wide)', 120, 40),
      const _SizePreset('160x50 (Full HD)', 160, 50),
      _SizePreset('Match Screen ($matchCols x $matchRows)', matchCols, matchRows),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.of(context).size;
    debugPrint('[ResizePaneDialog] build() mediaSize=$mediaSize '
        'allPanes=${widget.allPanesInWindow.length} '
        'target=${widget.targetPane.id} '
        'screenW=${widget.screenWidth} screenH=${widget.screenHeight} '
        'fontSize=${widget.fontSize} fontFamily=${widget.fontFamily}');

    return AlertDialog(
      backgroundColor: DesignColors.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Resize Pane',
        style: TextStyle(color: DesignColors.textPrimary),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPaneGridPreview(
                allPanes: widget.allPanesInWindow,
                highlightPaneId: widget.targetPane.id,
                previewPaneId: widget.targetPane.id,
                previewCols: _cols,
                previewRows: _rows,
              ),
            const SizedBox(height: 12),
            if (widget.allPanesInWindow.length >= 2)
              _buildWarning('Other pane sizes may also change.'),
            const SizedBox(height: 12),
            _buildSizeInputRow(
              cols: _cols,
              rows: _rows,
              onColsChanged: (v) => setState(() => _cols = v),
              onRowsChanged: (v) => setState(() => _rows = v),
            ),
            const SizedBox(height: 12),
            _buildPresetChips(
              presets: _presets,
              onSelect: (p) => setState(() {
                _cols = p.cols;
                _rows = p.rows;
              }),
            ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, ResizeResult(cols: _cols, rows: _rows)),
          style: FilledButton.styleFrom(
            backgroundColor: DesignColors.primary,
          ),
          child: const Text('Resize'),
        ),
      ],
    );
  }
}

// ====================================================================
// ResizeWindowDialog
// ====================================================================

/// Dialog for window resizing
class ResizeWindowDialog extends StatefulWidget {
  final TmuxWindow window;
  final List<TmuxPane> panes;
  final int currentCols;
  final int currentRows;
  final double screenWidth;
  final double screenHeight;
  final double fontSize;
  final String fontFamily;
  final bool supportsResizeWindow;

  const ResizeWindowDialog({
    super.key,
    required this.window,
    required this.panes,
    required this.currentCols,
    required this.currentRows,
    required this.screenWidth,
    required this.screenHeight,
    required this.fontSize,
    required this.fontFamily,
    required this.supportsResizeWindow,
  });

  @override
  State<ResizeWindowDialog> createState() => _ResizeWindowDialogState();
}

class _ResizeWindowDialogState extends State<ResizeWindowDialog> {
  late int _cols;
  late int _rows;

  @override
  void initState() {
    super.initState();
    _cols = widget.currentCols;
    _rows = widget.currentRows;
  }

  List<_SizePreset> get _presets {
    final matchCols = FontCalculator.calculateMaxCols(
      screenWidth: widget.screenWidth,
      fontSize: widget.fontSize,
      fontFamily: widget.fontFamily,
    );
    final matchRows = FontCalculator.calculateMaxRows(
      screenHeight: widget.screenHeight,
      fontSize: widget.fontSize,
      fontFamily: widget.fontFamily,
    );
    return [
      const _SizePreset('80x24 (Standard)', 80, 24),
      const _SizePreset('120x40 (Wide)', 120, 40),
      const _SizePreset('160x50 (Full HD)', 160, 50),
      _SizePreset('Match Screen ($matchCols x $matchRows)', matchCols, matchRows),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: DesignColors.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Resize Window',
        style: TextStyle(color: DesignColors.textPrimary),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildWindowGridPreview(
                window: widget.window,
                panes: widget.panes,
                currentCols: widget.currentCols,
                currentRows: widget.currentRows,
              ),
            const SizedBox(height: 12),
            if (!widget.supportsResizeWindow)
              _buildWarning('Window resize requires tmux 2.9+. Resize button disabled.'),
            const SizedBox(height: 12),
            _buildSizeInputRow(
              cols: _cols,
              rows: _rows,
              onColsChanged: (v) => setState(() => _cols = v),
              onRowsChanged: (v) => setState(() => _rows = v),
            ),
            const SizedBox(height: 12),
            _buildPresetChips(
              presets: _presets,
              onSelect: (p) => setState(() {
                _cols = p.cols;
                _rows = p.rows;
              }),
            ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: widget.supportsResizeWindow
              ? () => Navigator.pop(
                  context, ResizeResult(cols: _cols, rows: _rows))
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: DesignColors.primary,
          ),
          child: const Text('Resize'),
        ),
      ],
    );
  }
}

// ====================================================================
// Common builders (top-level functions)
// ====================================================================

/// Simulate tmux resize-pane with a simple simulation.
///
/// Determine size first, then recalculate all positions.
/// 1. Calculate window size and separators
/// 2. Determine new size (column width, height distribution within column)
/// 3. Recalculate positions from top and left
List<TmuxPane> _simulatePaneResize({
  required List<TmuxPane> panes,
  required String targetId,
  required int newCols,
  required int newRows,
}) {
  if (panes.isEmpty) return panes;
  final target = panes.firstWhere((p) => p.id == targetId, orElse: () => panes.first);
  if (!panes.any((p) => p.id == targetId)) return panes;

  // === Step 1: Calculate window size and separators ===
  int winW = 0, winH = 0;
  for (final p in panes) {
    winW = math.max(winW, p.left + p.width);
    winH = math.max(winH, p.top + p.height);
  }
  if (winW == 0 || winH == 0) return panes;

  // Same column (same left as target)
  final colPanes = panes.where((p) => p.left == target.left).toList()
    ..sort((a, b) => a.top.compareTo(b.top));

  // Left neighbors (panes adjacent to the left of column, overlapping vertically)
  final leftNeighbors = panes.where((p) =>
      p.left != target.left &&
      p.left + p.width < target.left &&
      colPanes.any((cm) => p.top < cm.top + cm.height && p.top + p.height > cm.top)).toList();

  // Horizontal separator (gap between column and left neighbor)
  int hSep = 1; // default
  if (leftNeighbors.isNotEmpty) {
    hSep = target.left - (leftNeighbors.first.left + leftNeighbors.first.width);
    if (hSep < 0) hSep = 1;
  }

  // Vertical separator (gap between panes within column)
  int vSep = 1; // default
  if (colPanes.length >= 2) {
    vSep = colPanes[1].top - (colPanes[0].top + colPanes[0].height);
    if (vSep < 0) vSep = 1;
  }

  // === Step 2: Determine new size ===

  // Column width (clamp: min 1, max winW - hSep - left neighbor min 1)
  final maxColWidth = leftNeighbors.isNotEmpty ? winW - hSep - 1 : winW;
  final colWidth = newCols.clamp(1, maxColWidth);

  // Left neighbor width
  final leftWidth = leftNeighbors.isNotEmpty
      ? math.max<int>(1, winW - hSep - colWidth)
      : 0;

  // Height distribution within column
  // Total column height (height currently used by the column)
  final colTop = colPanes.first.top;
  final colBottom = colPanes.last.top + colPanes.last.height;
  final colTotalH = colBottom - colTop;
  final totalVSep = vSep * (colPanes.length - 1);
  final availableH = colTotalH - totalVSep;

  // Target pane's new height (clamp: min 1, max = available - other panes min 1 each)
  final otherCount = colPanes.length - 1;
  final maxTargetH = availableH - otherCount; // other panes have min 1 each
  final targetH = newRows.clamp(1, math.max<int>(1, maxTargetH));

  // Distribute remaining height to other panes according to original ratio
  final int remainingH = math.max<int>(0, availableH - targetH);
  final otherOriginalSum = colPanes
      .where((p) => p.id != targetId)
      .fold<int>(0, (s, p) => s + p.height);

  final newHeights = <String, int>{};
  newHeights[targetId] = targetH;

  if (otherCount > 0 && otherOriginalSum > 0) {
    int distributed = 0;
    final others = colPanes.where((p) => p.id != targetId).toList();
    for (int i = 0; i < others.length; i++) {
      final p = others[i];
      if (i == others.length - 1) {
        // Assign all remaining to last pane (remainder adjustment)
        newHeights[p.id] = math.max<int>(1, remainingH - distributed);
      } else {
        final h = math.max(1, (remainingH * p.height / otherOriginalSum).round());
        newHeights[p.id] = h;
        distributed += h;
      }
    }
  }

  // === Step 3: Recalculate positions ===

  // New left position of left neighbor (unchanged)
  final newColLeft = leftNeighbors.isNotEmpty
      ? leftNeighbors.first.left + leftWidth + hSep
      : target.left; // If no left neighbor, keep original position

  // If no left neighbor and right neighbor exists
  // (If column is at left edge, position remains 0)

  // Recalculate top within column from top
  final newTops = <String, int>{};
  var currentTop = colTop;
  for (final p in colPanes) {
    newTops[p.id] = currentTop;
    currentTop += (newHeights[p.id] ?? p.height) + vSep;
  }

  // === Step 4: Assemble results ===
  return panes.map((p) {
    if (colPanes.any((cp) => cp.id == p.id)) {
      // Pane within column
      return p.copyWith(
        left: newColLeft,
        top: newTops[p.id] ?? p.top,
        width: colWidth,
        height: newHeights[p.id] ?? p.height,
      );
    } else if (leftNeighbors.any((ln) => ln.id == p.id)) {
      // Left neighbor pane (width changed, position unchanged)
      return p.copyWith(width: leftWidth);
    } else {
      // Others (no change)
      return p;
    }
  }).toList();
}

/// Grid preview for pane layout
///
/// If [previewPaneId] is specified, draw the simulation result of resizing
/// that pane to [previewCols]x[previewRows].
Widget _buildPaneGridPreview({
  required List<TmuxPane> allPanes,
  required String highlightPaneId,
  String? previewPaneId,
  int? previewCols,
  int? previewRows,
}) {
  if (allPanes.isEmpty) return const SizedBox.shrink();

  // Resize simulation
  final panes = (previewPaneId != null && previewCols != null && previewRows != null)
      ? _simulatePaneResize(
          panes: allPanes,
          targetId: previewPaneId,
          newCols: previewCols,
          newRows: previewRows,
        )
      : allPanes;

  return Container(
    height: 120,
    clipBehavior: Clip.hardEdge,
    decoration: BoxDecoration(
      color: DesignColors.canvasDark,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: DesignColors.borderDark),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        const pad = 4.0;
        final areaW = constraints.maxWidth - pad * 2;
        final areaH = constraints.maxHeight - pad * 2;

        // Calculate bounds of entire window
        int maxRight = 0;
        int maxBottom = 0;
        for (final p in panes) {
          final right = p.left + p.width;
          final bottom = p.top + p.height;
          if (right > maxRight) maxRight = right;
          if (bottom > maxBottom) maxBottom = bottom;
        }
        if (maxRight == 0) maxRight = 1;
        if (maxBottom == 0) maxBottom = 1;

        final scaleX = areaW / maxRight;
        final scaleY = areaH / maxBottom;

        return Padding(
          padding: const EdgeInsets.all(pad),
          child: Stack(
            children: [
              SizedBox(width: areaW, height: areaH),
              ...panes.map((pane) {
                final isTarget = pane.id == highlightPaneId;
                final left = pane.left * scaleX;
                final top = pane.top * scaleY;
                final width = (pane.width * scaleX).clamp(20.0, areaW - left);
                final height = (pane.height * scaleY).clamp(14.0, areaH - top);

                return Positioned(
                  left: left,
                  top: top,
                  width: width,
                  height: height,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isTarget
                          ? DesignColors.primary.withValues(alpha: 0.25)
                          : DesignColors.surfaceDark,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isTarget
                            ? DesignColors.primary
                            : DesignColors.borderDark,
                        width: isTarget ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          '${pane.index}\n${pane.width}x${pane.height}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: isTarget
                                ? DesignColors.primary
                                : DesignColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    ),
  );
}

/// Grid preview of entire window (for window resizing)
Widget _buildWindowGridPreview({
  required TmuxWindow window,
  required List<TmuxPane> panes,
  required int currentCols,
  required int currentRows,
}) {
  return Container(
    height: 120,
    clipBehavior: Clip.hardEdge,
    decoration: BoxDecoration(
      color: DesignColors.canvasDark,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: DesignColors.primary, width: 2),
    ),
    child: Column(
      children: [
        // Window header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: const BoxDecoration(
            color: DesignColors.surfaceDark,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          ),
          child: Text(
            '${window.name}  ${currentCols}x$currentRows',
            style: const TextStyle(
              fontSize: 11,
              color: DesignColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Pane layout
        Expanded(
          child: _buildPaneGridPreview(
            allPanes: panes,
            highlightPaneId: '', // No pane highlight for window resize
          ),
        ),
      ],
    ),
  );
}

/// Warning message
Widget _buildWarning(String message) {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: DesignColors.warning.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: DesignColors.warning.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.warning_amber_rounded,
            size: 16, color: DesignColors.warning),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              color: DesignColors.warning,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Cols / Rows numeric input row
Widget _buildSizeInputRow({
  required int cols,
  required int rows,
  required ValueChanged<int> onColsChanged,
  required ValueChanged<int> onRowsChanged,
}) {
  return Row(
    children: [
      Expanded(
        child: _buildNumberInput(
          label: 'Cols',
          value: cols,
          onChanged: onColsChanged,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _buildNumberInput(
          label: 'Rows',
          value: rows,
          onChanged: onRowsChanged,
        ),
      ),
    ],
  );
}

/// Single numeric input field (label + ◀ value ▶)
Widget _buildNumberInput({
  required String label,
  required int value,
  required ValueChanged<int> onChanged,
  int min = 10,
  int max = 500,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: DesignColors.textSecondary,
        ),
      ),
      const SizedBox(height: 4),
      Container(
        decoration: BoxDecoration(
          color: DesignColors.inputDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: DesignColors.borderDark),
        ),
        child: Row(
          children: [
            _stepButton(
              icon: Icons.chevron_left,
              onPressed: value > min
                  ? () => onChanged((value - 1).clamp(min, max))
                  : null,
            ),
            Expanded(
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: DesignColors.textPrimary,
                ),
              ),
            ),
            _stepButton(
              icon: Icons.chevron_right,
              onPressed: value < max
                  ? () => onChanged((value + 1).clamp(min, max))
                  : null,
            ),
          ],
        ),
      ),
    ],
  );
}

/// Step button (◀ / ▶)
Widget _stepButton({
  required IconData icon,
  required VoidCallback? onPressed,
}) {
  return IconButton(
    icon: Icon(icon, size: 20),
    onPressed: onPressed,
    color: DesignColors.textSecondary,
    disabledColor: DesignColors.textMuted,
    splashRadius: 18,
    padding: const EdgeInsets.all(4),
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
  );
}

/// Preset chip button group
Widget _buildPresetChips({
  required List<_SizePreset> presets,
  required ValueChanged<_SizePreset> onSelect,
}) {
  return Wrap(
    spacing: 6,
    runSpacing: 6,
    children: presets.map((preset) {
      return ActionChip(
        label: Text(
          preset.label,
          style: const TextStyle(fontSize: 11, color: DesignColors.textPrimary),
        ),
        backgroundColor: DesignColors.keyBackground,
        side: const BorderSide(color: DesignColors.borderDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => onSelect(preset),
      );
    }).toList(),
  );
}
