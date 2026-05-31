import 'package:flutter/material.dart';

import '../../../services/tmux/tmux_parser.dart';
import '../../../theme/design_colors.dart';

// ====================================================================
// ResizePaneChooserDialog
// ====================================================================

/// Dialog to graphically select pane for resizing
class ResizePaneChooserDialog extends StatefulWidget {
  final List<TmuxPane> panes;
  final String? activePaneId;
  final void Function(TmuxPane selectedPane) onResize;

  const ResizePaneChooserDialog({
    super.key,
    required this.panes,
    this.activePaneId,
    required this.onResize,
  });

  @override
  State<ResizePaneChooserDialog> createState() =>
      _ResizePaneChooserDialogState();
}

class _ResizePaneChooserDialogState extends State<ResizePaneChooserDialog> {
  late String? _selectedPaneId;

  @override
  void initState() {
    super.initState();
    // Default: currently active pane is selected
    _selectedPaneId = widget.activePaneId;
  }

  TmuxPane? get _selectedPane {
    if (_selectedPaneId == null) return null;
    try {
      return widget.panes.firstWhere((p) => p.id == _selectedPaneId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedPane;

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
            // Grid preview of pane layout
            _buildSelectablePaneGrid(),
            const SizedBox(height: 12),
            // Selected pane info
            if (selected != null)
              Text(
                'Selected: Pane ${selected.index} (${selected.width}x${selected.height})',
                style: const TextStyle(
                  fontSize: 13,
                  color: DesignColors.textSecondary,
                ),
              )
            else
              const Text(
                'Tap a pane to select',
                style: TextStyle(
                  fontSize: 13,
                  color: DesignColors.textSecondary,
                ),
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
          onPressed: selected != null ? () => widget.onResize(selected) : null,
          style: FilledButton.styleFrom(
            backgroundColor: DesignColors.primary,
          ),
          child: const Text('Resize'),
        ),
      ],
    );
  }

  Widget _buildSelectablePaneGrid() {
    if (widget.panes.isEmpty) return const SizedBox.shrink();

    // Calculate overall window size
    int maxRight = 0;
    int maxBottom = 0;
    for (final pane in widget.panes) {
      final right = pane.left + pane.width;
      final bottom = pane.top + pane.height;
      if (right > maxRight) maxRight = right;
      if (bottom > maxBottom) maxBottom = bottom;
    }
    if (maxRight == 0) maxRight = 1;
    if (maxBottom == 0) maxBottom = 1;

    return Container(
      height: 150,
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
            final scaleX = areaW / maxRight;
            final scaleY = areaH / maxBottom;

            return Padding(
              padding: const EdgeInsets.all(pad),
              child: Stack(
                children: [
                  SizedBox(width: areaW, height: areaH),
                  ...widget.panes.map((pane) {
                  final isSelected = pane.id == _selectedPaneId;
                  final left = pane.left * scaleX;
                  final top = pane.top * scaleY;
                  final width = (pane.width * scaleX).clamp(20.0, areaW - left);
                  final height = (pane.height * scaleY).clamp(14.0, areaH - top);

                  return Positioned(
                    left: left,
                    top: top,
                    width: width,
                    height: height,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPaneId = pane.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? DesignColors.primary.withValues(alpha: 0.25)
                              : DesignColors.surfaceDark,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isSelected
                                ? DesignColors.primary
                                : DesignColors.borderDark,
                            width: isSelected ? 2 : 1,
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
                                color: isSelected
                                    ? DesignColors.primary
                                    : DesignColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ]),
            );
          },
        ),
      );
  }
}
