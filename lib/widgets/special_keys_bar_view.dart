part of 'special_keys_bar.dart';

mixin _SpecialKeysBarView on _SpecialKeysBarLogic {
  /// Variable key bar (top row). Renders [config]'s buttons evenly across the
  /// width; each tap goes through [_sendSpecialKey] so active modifier toggles
  /// (CTRL/ALT/SHIFT) compose just like the other special keys. The initial
  /// configuration is the function keys F1–F10.
  Widget _buildVariableKeyBar(KeyBarConfig config) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      color: isDark ? DesignColors.surfaceDark : DesignColors.surfaceLight,
      child: Row(
        children: [
          for (final button in config.buttons)
            _buildSpecialKeyButton(button.label, button.tmuxKey),
        ],
      ),
    );
  }

  /// Top modifier key row (ESC, TAB, CTRL, ALT, SHIFT, ENTER, S-RET, /, -)
  Widget _buildModifierKeysRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      color: isDark ? DesignColors.surfaceDark : DesignColors.surfaceLight,
      child: Row(
        children: [
          _buildSpecialKeyButton('ESC', 'Escape'),
          // Up arrow at column 2 — sits exactly above Down in the arrow row.
          _buildArrowKeyCell(Icons.arrow_drop_up, 'Up'),
          _buildSpecialKeyButton('TAB', 'Tab'),
          _buildModifierButton('CTRL', _ctrlPressed, () {
            setState(() => _ctrlPressed = !_ctrlPressed);
          }),
          _buildModifierButton('ALT', _altPressed, () {
            setState(() => _altPressed = !_altPressed);
          }),
          _buildModifierButton('SHIFT', _shiftPressed, () {
            setState(() => _shiftPressed = !_shiftPressed);
          }),
          _buildEnterKeyButton(),
          _buildShiftEnterKeyButton(),
          _buildLiteralKeyButton('/', '/'),
          _buildLiteralKeyButton('-', '-'),
        ],
      ),
    );
  }

  /// Shift+Enter key button (for Claude Code AcceptEdits, etc.)
  Widget _buildShiftEnterKeyButton() {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.hapticFeedback) {
            HapticFeedback.lightImpact();
          }
        },
        onTap: () => _sendSpecialKey('S-Enter'),
        child: Container(
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: DesignColors.secondary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
            border: Border(
              bottom: BorderSide(color: DesignColors.secondary.withValues(alpha: 0.5), width: 2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'S-RET',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: DesignColors.secondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ENTER key button (sends Enter alone)
  Widget _buildEnterKeyButton() {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.hapticFeedback) {
            HapticFeedback.lightImpact();
          }
        },
        onTap: () => _sendSpecialKey('Enter'),
        child: Container(
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: DesignColors.primary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
            border: Border(
              bottom: BorderSide(color: DesignColors.primary.withValues(alpha: 0.5), width: 2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_return,
                  size: 12,
                  color: DesignColors.primary,
                ),
                const SizedBox(width: 2),
                Text(
                  'RET',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: DesignColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bottom arrow keys + Input button row
  Widget _buildArrowKeysRow() {
    // Arrows on the same 10-column grid as the modifier row, so Down (col 2)
    // sits exactly below Up (modifier-row col 2). Cols 1–4 are Left / Down /
    // Right / reserved; cols 5–10 (flex 6) hold the action buttons.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          _buildArrowKeyCell(Icons.arrow_left, 'Left'), // col 1
          _buildArrowKeyCell(Icons.arrow_drop_down, 'Down'), // col 2 (under Up)
          _buildArrowKeyCell(Icons.arrow_right, 'Right'), // col 3
          const Expanded(child: SizedBox()), // col 4 — reserved for later
          Expanded(
            flex: 6,
            child: Row(
              children: [
                // Image transfer button
                if (widget.onImagePickRequested != null) ...[
                  _buildImageTransferButton(),
                  const SizedBox(width: 2),
                ],
                // DirectInput mode toggle button
                _buildDirectInputToggle(),
                // When DirectInput is enabled: number keys (1-4) right-aligned
                if (widget.directInputEnabled) ...[
                  const Spacer(),
                  _buildNumberKeyButton('1'),
                  const SizedBox(width: 2),
                  _buildNumberKeyButton('2'),
                  const SizedBox(width: 2),
                  _buildNumberKeyButton('3'),
                  const SizedBox(width: 2),
                  _buildNumberKeyButton('4'),
                ],
                // When DirectInput is disabled: the Input button fills the gap
                if (!widget.directInputEnabled) ...[
                  const SizedBox(width: 4),
                  Expanded(child: _buildInputButton()),
                ],
                const SizedBox(width: 2),
                _buildHistoryButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Grid-aligned arrow cell (Expanded) used in both the modifier row (Up) and
  /// the arrow row (Left/Down/Right) so the columns line up.
  Widget _buildArrowKeyCell(IconData icon, String tmuxKey) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.hapticFeedback) {
            HapticFeedback.lightImpact();
          }
        },
        onTap: () => _sendSpecialKey(tmuxKey),
        child: Container(
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isDark ? DesignColors.keyBackground : DesignColors.keyBackgroundLight,
            borderRadius: BorderRadius.circular(4),
            border: Border(
              bottom: BorderSide(color: isDark ? Colors.black : Colors.grey.shade400, width: 2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.9)),
          ),
        ),
      ),
    );
  }

  /// History button: opens the recent-commands picker; selecting one sends it.
  Widget _buildHistoryButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        if (widget.hapticFeedback) {
          HapticFeedback.selectionClick();
        }
        showRecentCommandsSheet(
          context,
          fallback: widget.recentCommands,
          load: widget.loadRecentCommands,
          onSelected: (cmd) => widget.onSendCommand?.call(cmd),
        );
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? DesignColors.keyBackground : DesignColors.keyBackgroundLight,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Center(
          child: Icon(Icons.history, size: 18, color: colorScheme.onSurface),
        ),
      ),
    );
  }

  /// DirectInput-only row (input field only)
  /// RET/BS use native keyboard version
  Widget _buildDirectInputRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: _buildDirectInputField(),
    );
  }

  /// Toggle button for DirectInput mode
  Widget _buildDirectInputToggle() {
    final isEnabled = widget.directInputEnabled;
    return GestureDetector(
      onTap: () {
        if (widget.hapticFeedback) {
          HapticFeedback.selectionClick();
        }
        widget.onDirectInputToggle?.call();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isEnabled
              ? DesignColors.success.withValues(alpha: 0.3)
              : DesignColors.keyBackground,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isEnabled
                ? DesignColors.success.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Center(
          child: Icon(
            isEnabled ? Icons.flash_on : Icons.flash_off,
            size: 18,
            color: isEnabled ? DesignColors.success : Colors.white70,
          ),
        ),
      ),
    );
  }

  /// Text field for DirectInput (real-time transmission)
  Widget _buildDirectInputField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: DesignColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: DesignColors.success.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            // LIVE indicator (positioned on left)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: DesignColors.success.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: DesignColors.success,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: DesignColors.success.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'LIVE',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: DesignColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Input field
            Expanded(
              child: TextField(
                controller: _directInputController,
                focusNode: _directInputFocusNode,
                autofocus: true,
                textInputAction: TextInputAction.send,
                onSubmitted: _onDirectInputSubmitted,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Type here...',
                  hintStyle: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    color: DesignColors.success.withValues(alpha: 0.5),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Special key button (sends in tmux format)
  Widget _buildSpecialKeyButton(String label, String tmuxKey) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.hapticFeedback) {
            HapticFeedback.lightImpact();
          }
        },
        onTap: () => _sendSpecialKey(tmuxKey),
        child: Container(
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isDark ? DesignColors.keyBackground : DesignColors.keyBackgroundLight,
            borderRadius: BorderRadius.circular(4),
            border: Border(
              bottom: BorderSide(color: isDark ? Colors.black : Colors.grey.shade400, width: 2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Literal key button (sends as character as-is)
  Widget _buildLiteralKeyButton(String label, String key) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.hapticFeedback) {
            HapticFeedback.lightImpact();
          }
        },
        onTap: () => _sendLiteralKey(key),
        child: Container(
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isDark ? DesignColors.keyBackground : DesignColors.keyBackgroundLight,
            borderRadius: BorderRadius.circular(4),
            border: Border(
              bottom: BorderSide(color: isDark ? Colors.black : Colors.grey.shade400, width: 2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModifierButton(String label, bool isPressed, VoidCallback onPressed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.hapticFeedback) {
            HapticFeedback.lightImpact();
          }
        },
        onTap: onPressed,
        child: Container(
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isPressed ? colorScheme.primary : (isDark ? DesignColors.keyBackground : DesignColors.keyBackgroundLight),
            borderRadius: BorderRadius.circular(4),
            border: Border(
              bottom: BorderSide(
                color: isPressed ? colorScheme.primary : (isDark ? Colors.black : Colors.grey.shade400),
                width: 2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isPressed ? colorScheme.onPrimary : colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Image transfer button
  Widget _buildImageTransferButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) {
        if (widget.hapticFeedback) {
          HapticFeedback.lightImpact();
        }
      },
      onTap: widget.onImagePickRequested,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? DesignColors.keyBackground : DesignColors.keyBackgroundLight,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Icon(
          Icons.image_outlined,
          size: 16,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }

  /// Number key button (displayed in arrow key row when DirectInput is enabled)
  Widget _buildNumberKeyButton(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) {
        if (widget.hapticFeedback) {
          HapticFeedback.lightImpact();
        }
      },
      onTap: () => _sendLiteralKey(label),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? DesignColors.keyBackground : DesignColors.keyBackgroundLight,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputButton() {
    return GestureDetector(
      onTap: widget.onInputTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: DesignColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: DesignColors.primary.withValues(alpha: 0.2)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(
              Icons.keyboard,
              size: 16,
              color: DesignColors.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Input...',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: DesignColors.primary.withValues(alpha: 0.5),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: DesignColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: DesignColors.primary.withValues(alpha: 0.1)),
              ),
              child: Text(
                'cmd',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: DesignColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
