import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/design_colors.dart';
import 'key_bar_config.dart';
import 'recent_commands_sheet.dart';

part 'special_keys_bar_logic.dart';
part 'special_keys_bar_view.dart';

/// Zero-width sentinel char kept in the direct-input field to detect backspace.
const String _sentinel = '\u200B';

/// Special keys bar (HTML design specification compliant)
///
/// To send keys in tmux command format,
/// uses key names in tmux send-keys format.
class SpecialKeysBar extends StatefulWidget {
  /// Literal key transmission (regular characters)
  final void Function(String key) onKeyPressed;

  /// Special key transmission (tmux format: Enter, Escape, C-c, etc.)
  final void Function(String tmuxKey) onSpecialKeyPressed;

  final VoidCallback? onInputTap;
  final bool hapticFeedback;

  /// Whether DirectInput mode is enabled
  final bool directInputEnabled;

  /// Callback to toggle DirectInput mode
  final VoidCallback? onDirectInputToggle;

  /// Callback when image transfer button is pressed
  final VoidCallback? onImagePickRequested;

  /// The variable key bar shown above the special-key rows. Data-driven so the
  /// button set can be repurposed later; defaults to the function keys F1–F10.
  /// Pass null to hide the bar.
  final KeyBarConfig? variableKeyBar;

  /// Recent commands (most-recent first) for the bar's history button.
  final List<String> recentCommands;

  /// Sends a full command selected from the history picker.
  final void Function(String command)? onSendCommand;

  const SpecialKeysBar({
    super.key,
    required this.onKeyPressed,
    required this.onSpecialKeyPressed,
    this.onInputTap,
    this.hapticFeedback = true,
    this.directInputEnabled = false,
    this.onDirectInputToggle,
    this.onImagePickRequested,
    this.variableKeyBar = KeyBarConfig.functionKeys,
    this.recentCommands = const [],
    this.onSendCommand,
  });

  @override
  State<SpecialKeysBar> createState() => _SpecialKeysBarState();
}

class _SpecialKeysBarState extends State<SpecialKeysBar> with _SpecialKeysBarLogic, _SpecialKeysBarView {
  @override
  void initState() {
    super.initState();
    if (widget.directInputEnabled) {
      _directInputController.value = TextEditingValue(
        text: _sentinel,
        selection: TextSelection.collapsed(offset: _sentinel.length),
      );
    }
    _directInputController.addListener(_onDirectInputChanged);
  }

  @override
  void didUpdateWidget(SpecialKeysBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.directInputEnabled && !oldWidget.directInputEnabled) {
      _resetToSentinel();
    } else if (!widget.directInputEnabled && oldWidget.directInputEnabled) {
      _isResettingController = true;
      _directInputController.clear();
      _isResettingController = false;
    }
  }

  @override
  void dispose() {
    _directInputController.removeListener(_onDirectInputChanged);
    _directInputController.dispose();
    _directInputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? DesignColors.footerBackground : DesignColors.footerBackgroundLight,
        border: Border(
          top: BorderSide(color: colorScheme.outline, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.variableKeyBar != null)
              _buildVariableKeyBar(widget.variableKeyBar!),
            _buildModifierKeysRow(),
            _buildArrowKeysRow(),
            if (widget.directInputEnabled) _buildDirectInputRow(),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

}
