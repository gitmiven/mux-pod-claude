import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/design_colors.dart';

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

  const SpecialKeysBar({
    super.key,
    required this.onKeyPressed,
    required this.onSpecialKeyPressed,
    this.onInputTap,
    this.hapticFeedback = true,
    this.directInputEnabled = false,
    this.onDirectInputToggle,
    this.onImagePickRequested,
  });

  @override
  State<SpecialKeysBar> createState() => _SpecialKeysBarState();
}

class _SpecialKeysBarState extends State<SpecialKeysBar> {
  bool _ctrlPressed = false;
  bool _altPressed = false;
  bool _shiftPressed = false;
  final TextEditingController _directInputController = TextEditingController();
  final FocusNode _directInputFocusNode = FocusNode();

  /// Whether IME composition is currently active
  bool _isComposing = false;

  /// Latest text during IME composing (for iOS duplicate detection)
  /// When iOS returns committed text longer than composing text during auto-commit,
  /// treat composing text as canonical and remove extra duplicates
  String? _lastComposingText;

  /// Sentinel character for Backspace detection in DirectInput mode (zero-width space)
  /// iOS/iPadOS does not generate KeyDownEvent when Backspace is pressed with empty TextField,
  /// so we always maintain the sentinel and detect Backspace via deletion detection
  static const String _sentinel = '\u200B';

  /// Re-entry prevention flag during sentinel reset
  bool _isResettingController = false;

  /// Duplicate input prevention: timestamp of last key event processed by _handleKeyEvent
  /// iPad external keyboard generates both Flutter KeyEvent and iOS text input
  /// which process the same key twice, so we suppress via timestamp
  DateTime? _lastKeyEventHandledAt;

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

  /// DirectInput: handling text changes
  /// Detects Backspace using sentinel approach (iOS/iPadOS compatible)
  void _onDirectInputChanged() {
    if (_isResettingController) return;

    final text = _directInputController.text;
    final value = _directInputController.value;

    // composing is not empty = IME conversion in progress
    _isComposing = value.composing.isValid && !value.composing.isCollapsed;

    if (_isComposing) {
      // Record composing text for iOS duplicate detection
      _lastComposingText = text.replaceAll(_sentinel, '');

      // Samsung IME composing workaround:
      // Samsung (and some Android IMEs) treat English letters as composing,
      // so composing=false may NEVER arrive while the user keeps typing.
      // When a modifier (CTRL/ALT) is active, intercept the first composing
      // character immediately instead of waiting for composing to end.
      // Guards:
      //   - length == 1: only the first composing char (avoids accumulated repeats)
      //   - ASCII letter regex: don't intercept Korean (ㅊ) or other non-ASCII composing
      if ((_ctrlPressed || _altPressed) && _lastComposingText!.length == 1) {
        final char = _lastComposingText!;
        if (RegExp(r'^[A-Za-z]$').hasMatch(char)) {
          if (widget.hapticFeedback) {
            HapticFeedback.lightImpact();
          }
          final List<String> modifiers = [];
          if (_ctrlPressed) {
            modifiers.add('C');
            setState(() => _ctrlPressed = false);
          }
          if (_altPressed) {
            modifiers.add('M');
            setState(() => _altPressed = false);
          }
          final prefix = modifiers.join('-');
          widget.onSpecialKeyPressed('$prefix-${char.toLowerCase()}');
          _lastComposingText = null;
          _resetToSentinel();
          return;
        }
      }

      return;
    }

    // Sentinel deleted = Backspace pressed (iOS/iPadOS compatible)
    if (text.isEmpty) {
      _lastComposingText = null;
      _sendDirectBackspace();
      _resetToSentinel();
      return;
    }

    // Remove sentinel and get actual input text
    final actualText = text.replaceAll(_sentinel, '');

    // Send if actual text exists
    if (actualText.isNotEmpty) {
      // Duplicate input prevention for external keyboard: skip if already processed by _handleKeyEvent
      if (_isRecentKeyEventHandled()) {
        _lastComposingText = null;
        _resetToSentinel();
        return;
      }

      // iOS duplicate detection: if committed text is longer than composing text
      // and starts with composing text, treat as iOS duplicate insertion and use composing text
      String textToSend = actualText;
      if (_lastComposingText != null &&
          actualText.length > _lastComposingText!.length &&
          actualText.startsWith(_lastComposingText!)) {
        textToSend = _lastComposingText!;
      }
      _lastComposingText = null;

      // Send modifier+key when CTRL/ALT is active (non-composing path)
      // This handles IMEs that commit without composing (e.g. Gboard English)
      // tmux format: C-c (Ctrl+C), M-a (Alt+A), C-M-x (Ctrl+Alt+X)
      if ((_ctrlPressed || _altPressed) &&
          textToSend.length == 1 &&
          RegExp(r'^[A-Za-z]$').hasMatch(textToSend)) {
        if (widget.hapticFeedback) {
          HapticFeedback.lightImpact();
        }
        final List<String> modifiers = [];
        if (_ctrlPressed) {
          modifiers.add('C');
          setState(() => _ctrlPressed = false);
        }
        if (_altPressed) {
          modifiers.add('M');
          setState(() => _altPressed = false);
        }
        final prefix = modifiers.join('-');
        widget.onSpecialKeyPressed('$prefix-${textToSend.toLowerCase()}');
      } else {
        widget.onKeyPressed(textToSend);
      }

      // Reset to sentinel after sending
      _resetToSentinel();
    }
  }

  /// DirectInput: called when software keyboard Enter (submit) is pressed
  void _onDirectInputSubmitted(String value) {
    // Duplicate input prevention for external keyboard: skip if already processed by _handleKeyEvent
    if (_isRecentKeyEventHandled()) return;

    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    widget.onSpecialKeyPressed('Enter');
    _resetToSentinel();
  }

  /// DirectInput: send Backspace key
  void _sendDirectBackspace() {
    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    widget.onSpecialKeyPressed('BSpace');
  }

  /// DirectInput: reset to sentinel (for Backspace detection)
  ///
  /// Defer _isResettingController release to next frame to absorb
  /// delayed text updates sent by iOS when IME commits.
  /// If controller is overwritten in PostFrameCallback, reset to sentinel again.
  void _resetToSentinel() {
    _isResettingController = true;
    _directInputController.value = TextEditingValue(
      text: _sentinel,
      selection: TextSelection.collapsed(offset: _sentinel.length),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentValue = _directInputController.value;
      final hasActiveComposing = currentValue.composing.isValid &&
          !currentValue.composing.isCollapsed;
      // If composing is in progress, respect iOS input and don't reset again
      if (!hasActiveComposing && _directInputController.text != _sentinel) {
        _directInputController.value = TextEditingValue(
          text: _sentinel,
          selection: TextSelection.collapsed(offset: _sentinel.length),
        );
      }
      _isResettingController = false;
    });
  }

  /// Duplicate input prevention: mark as processed by _handleKeyEvent
  void _markKeyEventHandled() {
    _lastKeyEventHandledAt = DateTime.now();
  }

  /// Duplicate input prevention: check if processed by _handleKeyEvent within last 100ms
  bool _isRecentKeyEventHandled() {
    if (_lastKeyEventHandledAt == null) return false;
    return DateTime.now().difference(_lastKeyEventHandledAt!) <
        const Duration(milliseconds: 100);
  }

  /// Detect external keyboard modifiers and convert to tmux format key name
  String _applyHardwareModifiers(String baseKey) {
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;

    // Special case: Shift+Tab → BTab
    if (isShift && baseKey == 'Tab') return 'BTab';

    final mods = <String>[];
    if (isShift) mods.add('S');
    if (isCtrl) mods.add('C');
    if (isAlt) mods.add('M');
    if (mods.isEmpty) return baseKey;
    return '${mods.join('-')}-$baseKey';
  }

  /// External keyboard → tmux key name mapping
  static final _hwSpecialKeyMap = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.escape: 'Escape',
    LogicalKeyboardKey.tab: 'Tab',
    LogicalKeyboardKey.arrowUp: 'Up',
    LogicalKeyboardKey.arrowDown: 'Down',
    LogicalKeyboardKey.arrowLeft: 'Left',
    LogicalKeyboardKey.arrowRight: 'Right',
    LogicalKeyboardKey.home: 'Home',
    LogicalKeyboardKey.end: 'End',
    LogicalKeyboardKey.pageUp: 'PPage',
    LogicalKeyboardKey.pageDown: 'NPage',
    LogicalKeyboardKey.delete: 'DC',
    LogicalKeyboardKey.f1: 'F1',
    LogicalKeyboardKey.f2: 'F2',
    LogicalKeyboardKey.f3: 'F3',
    LogicalKeyboardKey.f4: 'F4',
    LogicalKeyboardKey.f5: 'F5',
    LogicalKeyboardKey.f6: 'F6',
    LogicalKeyboardKey.f7: 'F7',
    LogicalKeyboardKey.f8: 'F8',
    LogicalKeyboardKey.f9: 'F9',
    LogicalKeyboardKey.f10: 'F10',
    LogicalKeyboardKey.f11: 'F11',
    LogicalKeyboardKey.f12: 'F12',
  };

  /// Send special key for external keyboard (with debounce)
  void _sendHwSpecialKey(String baseKey) {
    _markKeyEventHandled();
    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    widget.onSpecialKeyPressed(_applyHardwareModifiers(baseKey));
    // Reset software modifier toggle when using external keyboard
    _resetSoftwareModifiers();
  }

  /// Reset software modifier button states
  void _resetSoftwareModifiers() {
    if (_shiftPressed || _ctrlPressed || _altPressed) {
      setState(() {
        _shiftPressed = false;
        _ctrlPressed = false;
        _altPressed = false;
      });
    }
  }

  /// Key event handler (for external keyboard: captures all special keys)
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    // Don't process key events during IME conversion
    if (_isComposing) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // Ctrl/Meta + A-Z shortcut handling
    final isCtrlPressed = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (isCtrlPressed) {
      final keyLabel = key.keyLabel;
      if (keyLabel.length == 1 && RegExp(r'^[A-Za-z]$').hasMatch(keyLabel)) {
        _markKeyEventHandled();
        if (widget.hapticFeedback) {
          HapticFeedback.lightImpact();
        }
        widget.onSpecialKeyPressed('C-${keyLabel.toLowerCase()}');
        _resetSoftwareModifiers();
        return KeyEventResult.handled;
      }
    }

    // Enter key
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _markKeyEventHandled();
      _sendDirectEnterAndClear();
      _resetSoftwareModifiers();
      return KeyEventResult.handled;
    }

    // Backspace key: handled in _onDirectInputChanged via sentinel approach
    if (key == LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }

    // Special keys registered in map (Escape/Tab/arrows/Nav/F1-F12)
    final tmuxKey = _hwSpecialKeyMap[key];
    if (tmuxKey != null) {
      _sendHwSpecialKey(tmuxKey);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// DirectInput: send Enter key and reset input field
  void _sendDirectEnterAndClear() {
    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    widget.onSpecialKeyPressed('Enter');
    _resetToSentinel();
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
            _buildModifierKeysRow(),
            _buildArrowKeysRow(),
            if (widget.directInputEnabled) _buildDirectInputRow(),
            const SizedBox(height: 4),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          // Arrow keys side by side: left, up, down, right
          _buildArrowButton(Icons.arrow_left, 'Left'),
          const SizedBox(width: 2),
          _buildArrowButton(Icons.arrow_drop_up, 'Up'),
          const SizedBox(width: 2),
          _buildArrowButton(Icons.arrow_drop_down, 'Down'),
          const SizedBox(width: 2),
          _buildArrowButton(Icons.arrow_right, 'Right'),
          const SizedBox(width: 8),
          // Image transfer button
          if (widget.onImagePickRequested != null) ...[
            _buildImageTransferButton(),
            const SizedBox(width: 2),
          ],
          // DirectInput mode toggle button
          _buildDirectInputToggle(),
          // When DirectInput is enabled: display number keys (1-4) right-aligned
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
          // When DirectInput is disabled: display Input button
          if (!widget.directInputEnabled) ...[
            const SizedBox(width: 4),
            Expanded(child: _buildInputButton()),
          ],
        ],
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

  Widget _buildArrowButton(IconData icon, String tmuxKey) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) {
        if (widget.hapticFeedback) {
          HapticFeedback.lightImpact();
        }
      },
      onTap: () => _sendSpecialKey(tmuxKey),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? DesignColors.keyBackground : DesignColors.keyBackgroundLight,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Icon(
          icon,
          size: 16,
          color: colorScheme.onSurface,
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

  /// Send special key (tmux format)
  void _sendSpecialKey(String tmuxKey) {
    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }

    String key = tmuxKey;

    // Special case: Shift+Tab → BTab (Back Tab)
    if (_shiftPressed && tmuxKey == 'Tab') {
      setState(() => _shiftPressed = false);
      // Also reset Ctrl/Alt state
      if (_ctrlPressed) setState(() => _ctrlPressed = false);
      if (_altPressed) setState(() => _altPressed = false);
      widget.onSpecialKeyPressed('BTab');
      return;
    }

    // Combine modifiers (Shift, Ctrl, Alt order)
    final List<String> modifiers = [];
    if (_shiftPressed) {
      modifiers.add('S');
      setState(() => _shiftPressed = false);
    }
    if (_ctrlPressed) {
      modifiers.add('C');
      setState(() => _ctrlPressed = false);
    }
    if (_altPressed) {
      modifiers.add('M');
      setState(() => _altPressed = false);
    }

    // Apply modifiers in tmux format
    if (modifiers.isNotEmpty) {
      // Example: S-Enter, C-M-a, etc.
      final prefix = modifiers.join('-');
      key = '$prefix-$tmuxKey';
    }

    widget.onSpecialKeyPressed(key);
  }

  /// Send literal key (character as-is)
  void _sendLiteralKey(String key) {
    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }

    // Combine modifiers
    final List<String> modifiers = [];
    if (_shiftPressed) {
      modifiers.add('S');
      setState(() => _shiftPressed = false);
    }
    if (_ctrlPressed) {
      modifiers.add('C');
      setState(() => _ctrlPressed = false);
    }
    if (_altPressed) {
      modifiers.add('M');
      setState(() => _altPressed = false);
    }

    // Send in tmux format if modifiers are present
    if (modifiers.isNotEmpty && key.length == 1) {
      final prefix = modifiers.join('-');
      widget.onSpecialKeyPressed('$prefix-$key');
      return;
    }

    // Send literal without modifiers
    widget.onKeyPressed(key);
  }
}
