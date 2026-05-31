part of 'special_keys_bar.dart';

mixin _SpecialKeysBarLogic on State<SpecialKeysBar> {
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

  /// Re-entry prevention flag during sentinel reset
  bool _isResettingController = false;

  /// Duplicate input prevention: timestamp of last key event processed by _handleKeyEvent
  /// iPad external keyboard generates both Flutter KeyEvent and iOS text input
  /// which process the same key twice, so we suppress via timestamp
  DateTime? _lastKeyEventHandledAt;

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
