import 'package:flutter/material.dart';

import '../../../services/tmux/tmux_parser.dart';
import '../../../theme/design_colors.dart';


// ====================================================================
// ResizeWindowChooserDialog
// ====================================================================

/// Dialog to graphically select window for resizing
class ResizeWindowChooserDialog extends StatefulWidget {
  final List<TmuxWindow> windows;
  final int? activeWindowIndex;
  final void Function(TmuxWindow selectedWindow) onResize;

  const ResizeWindowChooserDialog({
    super.key,
    required this.windows,
    this.activeWindowIndex,
    required this.onResize,
  });

  @override
  State<ResizeWindowChooserDialog> createState() =>
      _ResizeWindowChooserDialogState();
}

class _ResizeWindowChooserDialogState
    extends State<ResizeWindowChooserDialog> {
  late int? _selectedWindowIndex;

  @override
  void initState() {
    super.initState();
    // Default: currently active window is selected
    _selectedWindowIndex = widget.activeWindowIndex;
  }

  TmuxWindow? get _selectedWindow {
    if (_selectedWindowIndex == null) return null;
    try {
      return widget.windows
          .firstWhere((w) => w.index == _selectedWindowIndex);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedWindow;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Window card list
              ...widget.windows.map((window) {
                final isSelected = window.index == _selectedWindowIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildWindowCard(window, isSelected),
                );
              }),
              const SizedBox(height: 4),
              // Selected window info
              if (selected != null) ...[
                Text(
                  'Selected: ${selected.name} (${_windowSizeString(selected)})',
                  style: const TextStyle(
                    fontSize: 13,
                    color: DesignColors.textSecondary,
                  ),
                ),
              ] else
                const Text(
                  'Tap a window to select',
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
          onPressed:
              selected != null ? () => widget.onResize(selected) : null,
          style: FilledButton.styleFrom(
            backgroundColor: DesignColors.primary,
          ),
          child: const Text('Resize'),
        ),
      ],
    );
  }

  String _windowSizeString(TmuxWindow window) {
    final panes = window.panes;
    if (panes.isEmpty) return '?x?';
    final cols =
        panes.map((p) => p.left + p.width).reduce((a, b) => a > b ? a : b);
    final rows =
        panes.map((p) => p.top + p.height).reduce((a, b) => a > b ? a : b);
    return '${cols}x$rows';
  }

  Widget _buildWindowCard(TmuxWindow window, bool isSelected) {
    final panes = window.panes;
    return GestureDetector(
      onTap: () => setState(() => _selectedWindowIndex = window.index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: DesignColors.canvasDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? DesignColors.primary : DesignColors.borderDark,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Window header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? DesignColors.primary.withValues(alpha: 0.15)
                    : DesignColors.surfaceDark,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(7),
                  topRight: Radius.circular(7),
                ),
              ),
              child: Text(
                '${window.name}  ${_windowSizeString(window)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? DesignColors.primary
                      : DesignColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Pane layout preview
            if (panes.isNotEmpty)
              SizedBox(
                height: 60,
                child: _buildPaneLayoutPreview(panes),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaneLayoutPreview(List<TmuxPane> panes) {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final areaW = constraints.maxWidth - 8;
        final areaH = constraints.maxHeight - 8;

        return Padding(
          padding: const EdgeInsets.all(4),
          child: Stack(
            children: [
              SizedBox(width: areaW, height: areaH),
              ...panes.map((pane) {
              final left = (pane.left / maxRight) * areaW;
              final top = (pane.top / maxBottom) * areaH;
              final width = (pane.width / maxRight) * areaW;
              final height = (pane.height / maxBottom) * areaH;

              return Positioned(
                left: left,
                top: top,
                width: width.clamp(16.0, areaW),
                height: height.clamp(10.0, areaH),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: DesignColors.borderDark,
                      width: 1,
                    ),
                  ),
                ),
              );
            }),
          ]),
        );
      },
    );
  }
}
