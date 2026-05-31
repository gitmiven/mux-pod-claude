part of 'ansi_text_view.dart';

mixin _AnsiTextViewLogic on ConsumerState<AnsiTextView> {
  final FocusNode _focusNode = FocusNode();
  final ScrollController _horizontalScrollController = ScrollController();
  ScrollController? _internalVerticalScrollController;

  /// Controller for caret blinking
  late final AnimationController _caretBlinkController;

  /// Vertical scroll controller to use
  ScrollController get _verticalScrollController =>
      widget.verticalScrollController ?? _internalVerticalScrollController!;

  late AnsiParser _parser;

  /// Diff calculation service
  final TerminalDiff _terminalDiff = TerminalDiff();

  /// Modifier key state
  bool _ctrlPressed = false;
  bool _altPressed = false;
  bool _shiftPressed = false;

  /// Hold+swipe state
  bool _isLongPressing = false;
  Offset? _longPressStartPosition;
  String? _lastSwipeDirection;
  static const double _swipeThreshold = 30.0;

  /// Two-finger gesture mode (determined by finger movement direction, locked until end)
  _TwoFingerMode _twoFingerMode = _TwoFingerMode.undetermined;
  Offset _twoFingerPanStart = Offset.zero;
  Offset _twoFingerPanDelta = Offset.zero;
  bool _isTwoFingerPanning = false;
  SwipeDirection? _twoFingerSwipeResult;
  static const double _twoFingerSwipeThreshold = 50.0;
  static const Duration _edgeFlashDuration = Duration(milliseconds: 400);

  /// Individual pointer tracking (determine zoom/pan by finger movement direction vector)
  final Map<int, Offset> _pointerStartPositions = {};
  final Map<int, Offset> _pointerCurrentPositions = {};

  /// Current zoom scale
  double _currentScale = 1.0;

  /// Scale at pinch zoom start
  double _baseScale = 1.0;

  /// Parsed line data cache (for virtual scroll)
  List<ParsedLine>? _cachedParsedLines;
  String? _cachedText;
  double? _cachedFontSize;
  String? _cachedFontFamily;

  /// Line height (fixed height used in virtual scroll)
  double _lineHeight = 20.0;

  /// Last diff result (for adaptive polling)
  DiffResult? _lastDiffResult;

  /// Invalidate cache
  void _invalidateCache() {
    _cachedParsedLines = null;
    _cachedText = null;
    _cachedFontSize = null;
    _cachedFontFamily = null;
  }

  /// Get line data (cache used, for virtual scroll)
  List<ParsedLine> _getParsedLines({
    required double fontSize,
    required String fontFamily,
  }) {
    // Execute diff calculation
    _lastDiffResult = _terminalDiff.calculateDiff(widget.text);

    // Check if cache is valid
    if (_cachedParsedLines != null &&
        _cachedText == widget.text &&
        _cachedFontSize == fontSize &&
        _cachedFontFamily == fontFamily) {
      return _cachedParsedLines!;
    }

    // Parse new and cache
    _cachedParsedLines = _parser.parseLines(widget.text);
    _cachedText = widget.text;
    _cachedFontSize = fontSize;
    _cachedFontFamily = fontFamily;

    // Calculate line height (fontSize * lineHeight factor)
    _lineHeight = fontSize * 1.4;

    return _cachedParsedLines!;
  }

  /// Get last diff result (for reference from parent widget)
  DiffResult? get lastDiffResult => _lastDiffResult;

  /// Get recommended polling interval (for adaptive polling)
  int get recommendedPollingInterval {
    if (_lastDiffResult == null) {
      return AdaptivePollingInterval.defaultInterval;
    }
    return AdaptivePollingInterval.calculateInterval(
      _lastDiffResult!.unchangedFrames,
      _lastDiffResult!.changeRatio,
    );
  }

  /// Reset zoom
  void resetZoom() {
    setState(() {
      _currentScale = 1.0;
      _baseScale = 1.0;
    });
    widget.onZoomChanged?.call(1.0);
  }

  // === Pointer tracking (determine zoom/pan by finger movement direction vector) ===

  void _onPointerDown(PointerDownEvent event) {
    _pointerStartPositions[event.pointer] = event.position;
    _pointerCurrentPositions[event.pointer] = event.position;
  }

  void _onPointerMove(PointerMoveEvent event) {
    _pointerCurrentPositions[event.pointer] = event.position;
  }

  void _onPointerUpOrCancel(PointerEvent event) {
    _pointerStartPositions.remove(event.pointer);
    _pointerCurrentPositions.remove(event.pointer);
  }

  /// Determine mode from dot product of two-finger movement direction vectors
  ///
  /// - Dot product > 0: same direction (pan) → pane switch
  /// - Dot product < 0: opposite direction (pinch) → zoom
  /// - Insufficient movement: cannot determine
  _TwoFingerMode _detectModeFromFingerDirections() {
    if (_pointerCurrentPositions.length < 2) {
      return _TwoFingerMode.undetermined;
    }

    final pointers = _pointerStartPositions.keys
        .where((p) => _pointerCurrentPositions.containsKey(p))
        .take(2)
        .toList();
    if (pointers.length < 2) return _TwoFingerMode.undetermined;

    final v1 =
        _pointerCurrentPositions[pointers[0]]! -
        _pointerStartPositions[pointers[0]]!;
    final v2 =
        _pointerCurrentPositions[pointers[1]]! -
        _pointerStartPositions[pointers[1]]!;

    // If minimum movement not reached, cannot determine
    if (v1.distance < 15 || v2.distance < 15) {
      return _TwoFingerMode.undetermined;
    }

    final dot = v1.dx * v2.dx + v1.dy * v2.dy;
    return dot > 0 ? _TwoFingerMode.pan : _TwoFingerMode.zoom;
  }

  // === Pinch zoom + two-finger swipe handling ===

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
    _twoFingerPanStart = details.focalPoint;
    _twoFingerPanDelta = Offset.zero;
    _isTwoFingerPanning = false;
    _twoFingerMode = _TwoFingerMode.undetermined;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // Leave single-finger drag to scroll
    if (details.pointerCount <= 1) return;

    // Mode confirmed → process as-is
    if (_twoFingerMode == _TwoFingerMode.zoom) {
      _isTwoFingerPanning = false;
      _applyZoom(details);
      return;
    }
    if (_twoFingerMode == _TwoFingerMode.pan) {
      _isTwoFingerPanning = true;
      _twoFingerPanDelta = details.focalPoint - _twoFingerPanStart;
      setState(() {});
      return;
    }

    // Mode undetermined → determine by finger movement direction vector
    _twoFingerMode = _detectModeFromFingerDirections();

    switch (_twoFingerMode) {
      case _TwoFingerMode.zoom:
        _isTwoFingerPanning = false;
        _applyZoom(details);
      case _TwoFingerMode.pan:
        _isTwoFingerPanning = true;
        _twoFingerPanDelta = details.focalPoint - _twoFingerPanStart;
        setState(() {});
      case _TwoFingerMode.undetermined:
        // Cannot determine yet → temporarily track pan delta only
        _twoFingerPanDelta = details.focalPoint - _twoFingerPanStart;
    }
  }

  void _applyZoom(ScaleUpdateDetails details) {
    final newScale = (_baseScale * details.scale).clamp(0.5, 5.0);
    if (newScale != _currentScale) {
      setState(() {
        _currentScale = newScale;
      });
      widget.onZoomChanged?.call(newScale);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final wasPanning = _isTwoFingerPanning;
    _isTwoFingerPanning = false;
    _twoFingerMode = _TwoFingerMode.undetermined;
    if (!wasPanning) return;

    final direction = PaneNavigator.detectSwipeDirection(
      _twoFingerPanDelta,
      threshold: _twoFingerSwipeThreshold,
    );

    if (direction != null) {
      final canNavigate = widget.navigableDirections?[direction] ?? true;
      if (canNavigate) {
        widget.onTwoFingerSwipe?.call(direction);
        HapticFeedback.mediumImpact();
      } else {
        _showEdgeFlash(direction);
      }
    }
    _twoFingerPanDelta = Offset.zero;
    setState(() {});
  }

  void _showEdgeFlash(SwipeDirection direction) {
    HapticFeedback.heavyImpact();
    setState(() {
      _twoFingerSwipeResult = direction;
    });
    Future.delayed(_edgeFlashDuration, () {
      if (mounted) {
        setState(() {
          _twoFingerSwipeResult = null;
        });
      }
    });
  }

  // === Hold+swipe handling ===

  void _onLongPressStart(LongPressStartDetails details) {
    setState(() {
      _isLongPressing = true;
      _longPressStartPosition = details.localPosition;
      _lastSwipeDirection = null;
    });
    HapticFeedback.lightImpact();
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_isLongPressing || _longPressStartPosition == null) return;

    final delta = details.localPosition - _longPressStartPosition!;
    String? direction;

    // Detect direction that exceeds threshold
    if (delta.dx.abs() > delta.dy.abs()) {
      // Horizontal direction
      if (delta.dx > _swipeThreshold) {
        direction = 'Right';
      } else if (delta.dx < -_swipeThreshold) {
        direction = 'Left';
      }
    } else {
      // Vertical direction
      if (delta.dy > _swipeThreshold) {
        direction = 'Down';
      } else if (delta.dy < -_swipeThreshold) {
        direction = 'Up';
      }
    }

    if (direction != null) {
      setState(() {
        _lastSwipeDirection = direction;
      });
      widget.onArrowSwipe?.call(direction);
      HapticFeedback.selectionClick();
      // Reset starting point for continuous swipe support
      _longPressStartPosition = details.localPosition;
      // Reset highlight after short time
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && _isLongPressing) {
          setState(() {
            _lastSwipeDirection = null;
          });
        }
      });
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    setState(() {
      _isLongPressing = false;
      _longPressStartPosition = null;
      _lastSwipeDirection = null;
    });
  }

  /// Get current zoom scale
  double get currentScale => _currentScale;

  /// Handle key event
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.onKeyInput == null) return KeyEventResult.ignored;

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final key = event.logicalKey;

      // Update modifier key state
      if (key == LogicalKeyboardKey.controlLeft ||
          key == LogicalKeyboardKey.controlRight) {
        _ctrlPressed = true;
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.altLeft ||
          key == LogicalKeyboardKey.altRight) {
        _altPressed = true;
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.shiftLeft ||
          key == LogicalKeyboardKey.shiftRight) {
        _shiftPressed = true;
        return KeyEventResult.handled;
      }

      // Handle special keys
      String? data;
      bool isSpecialKey = false;
      String? tmuxKeyName;

      if (key == LogicalKeyboardKey.escape) {
        data = '\x1b';
        isSpecialKey = true;
        tmuxKeyName = 'Escape';
      } else if (key == LogicalKeyboardKey.enter) {
        // Send with different key name for Shift+Enter
        if (_shiftPressed) {
          data = '\x1b[27;2;13~'; // xterm extension: Shift+Enter
          isSpecialKey = true;
          tmuxKeyName = 'S-Enter';
          _shiftPressed = false;
        } else {
          data = '\r';
          isSpecialKey = true;
          tmuxKeyName = 'Enter';
        }
      } else if (key == LogicalKeyboardKey.backspace) {
        data = '\x7f';
        isSpecialKey = true;
        tmuxKeyName = 'BSpace';
      } else if (key == LogicalKeyboardKey.delete) {
        data = _getParamSequence(3, '~');
        isSpecialKey = true;
        tmuxKeyName = _getModifiedTmuxKey('DC');
      } else if (key == LogicalKeyboardKey.tab) {
        if (_shiftPressed) {
          data = '\x1b[Z';
          tmuxKeyName = 'BTab';
          _shiftPressed = false;
        } else {
          data = '\t';
          tmuxKeyName = 'Tab';
        }
        isSpecialKey = true;
      } else if (key == LogicalKeyboardKey.arrowUp) {
        data = _getArrowSequence('A');
        isSpecialKey = true;
        tmuxKeyName = _getArrowTmuxKey('Up');
      } else if (key == LogicalKeyboardKey.arrowDown) {
        data = _getArrowSequence('B');
        isSpecialKey = true;
        tmuxKeyName = _getArrowTmuxKey('Down');
      } else if (key == LogicalKeyboardKey.arrowRight) {
        data = _getArrowSequence('C');
        isSpecialKey = true;
        tmuxKeyName = _getArrowTmuxKey('Right');
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        data = _getArrowSequence('D');
        isSpecialKey = true;
        tmuxKeyName = _getArrowTmuxKey('Left');
      } else if (key == LogicalKeyboardKey.home) {
        data = _getFinalCharSequence('H');
        isSpecialKey = true;
        tmuxKeyName = _getModifiedTmuxKey('Home');
      } else if (key == LogicalKeyboardKey.end) {
        data = _getFinalCharSequence('F');
        isSpecialKey = true;
        tmuxKeyName = _getModifiedTmuxKey('End');
      } else if (key == LogicalKeyboardKey.pageUp) {
        data = _getParamSequence(5, '~');
        isSpecialKey = true;
        tmuxKeyName = _getModifiedTmuxKey('PPage');
      } else if (key == LogicalKeyboardKey.pageDown) {
        data = _getParamSequence(6, '~');
        isSpecialKey = true;
        tmuxKeyName = _getModifiedTmuxKey('NPage');
      } else if (key == LogicalKeyboardKey.f1) {
        data = _getFKeySequence('P');
        isSpecialKey = true;
        tmuxKeyName = _getModifiedTmuxKey('F1');
      } else if (key == LogicalKeyboardKey.f2) {
        data = _getFKeySequence('Q');
        isSpecialKey = true;
        tmuxKeyName = _getModifiedTmuxKey('F2');
      } else if (key == LogicalKeyboardKey.f3) {
        data = _getFKeySequence('R');
        isSpecialKey = true;
        tmuxKeyName = _getModifiedTmuxKey('F3');
      } else if (key == LogicalKeyboardKey.f4) {
        data = _getFKeySequence('S');
        isSpecialKey = true;
        tmuxKeyName = _getModifiedTmuxKey('F4');
      } else if (key == LogicalKeyboardKey.f5) {
        data = _getParamSequence(15, '~');
        isSpecialKey = true;
        tmuxKeyName = _getModifiedTmuxKey('F5');
      } else if (key == LogicalKeyboardKey.f6) {
        data = _getParamSequence(17, '~');
        isSpecialKey = true;
        tmuxKeyName = _getModifiedTmuxKey('F6');
      } else if (key == LogicalKeyboardKey.f7) {
        data = _getParamSequence(18, '~');
        isSpecialKey = true;
        tmuxKeyName = _getModifiedTmuxKey('F7');
      } else if (key == LogicalKeyboardKey.f8) {
        data = _getParamSequence(19, '~');
        isSpecialKey = true;
        tmuxKeyName = _getModifiedTmuxKey('F8');
      } else if (key == LogicalKeyboardKey.f9) {
        data = _getParamSequence(20, '~');
        isSpecialKey = true;
        tmuxKeyName = _getModifiedTmuxKey('F9');
      } else if (key == LogicalKeyboardKey.f10) {
        data = _getParamSequence(21, '~');
        isSpecialKey = true;
        tmuxKeyName = _getModifiedTmuxKey('F10');
      } else if (key == LogicalKeyboardKey.f11) {
        data = _getParamSequence(23, '~');
        isSpecialKey = true;
        tmuxKeyName = _getModifiedTmuxKey('F11');
      } else if (key == LogicalKeyboardKey.f12) {
        data = _getParamSequence(24, '~');
        isSpecialKey = true;
        tmuxKeyName = _getModifiedTmuxKey('F12');
      } else if (event.character != null && event.character!.isNotEmpty) {
        // Normal character
        data = event.character!;

        // Handle Ctrl+character
        if (_ctrlPressed && data.length == 1) {
          final code = data.codeUnitAt(0);
          if ((code >= 0x61 && code <= 0x7a) ||
              (code >= 0x41 && code <= 0x5a)) {
            data = String.fromCharCode(code & 0x1f);
          }
        }

        // Handle Alt+character
        if (_altPressed) {
          data = '\x1b$data';
        }
      }

      if (data != null) {
        widget.onKeyInput!(KeyInputEvent(
          data: data,
          isSpecialKey: isSpecialKey,
          tmuxKeyName: tmuxKeyName,
        ));
        return KeyEventResult.handled;
      }
    } else if (event is KeyUpEvent) {
      final key = event.logicalKey;

      // Release modifier keys
      if (key == LogicalKeyboardKey.controlLeft ||
          key == LogicalKeyboardKey.controlRight) {
        _ctrlPressed = false;
      } else if (key == LogicalKeyboardKey.altLeft ||
          key == LogicalKeyboardKey.altRight) {
        _altPressed = false;
      } else if (key == LogicalKeyboardKey.shiftLeft ||
          key == LogicalKeyboardKey.shiftRight) {
        _shiftPressed = false;
      }
    }

    return KeyEventResult.ignored;
  }

  /// Get arrow key sequence
  String _getArrowSequence(String code) {
    if (_shiftPressed) {
      return '\x1b[1;2$code';
    } else if (_ctrlPressed) {
      return '\x1b[1;5$code';
    } else if (_altPressed) {
      return '\x1b[1;3$code';
    }
    return '\x1b[$code';
  }

  /// Get arrow key tmux-format key name
  String _getArrowTmuxKey(String direction) {
    if (_shiftPressed) {
      return 'S-$direction';
    } else if (_ctrlPressed) {
      return 'C-$direction';
    } else if (_altPressed) {
      return 'M-$direction';
    }
    return direction;
  }

  /// Get modified tmux key name (generic: Home/End/PPage/NPage/DC, etc.)
  /// Consume (reset) modifier flags
  String _getModifiedTmuxKey(String baseKey) {
    if (_shiftPressed) {
      _shiftPressed = false;
      return 'S-$baseKey';
    } else if (_ctrlPressed) {
      _ctrlPressed = false;
      return 'C-$baseKey';
    } else if (_altPressed) {
      _altPressed = false;
      return 'M-$baseKey';
    }
    return baseKey;
  }

  /// Modified CSI sequence: final-character type (Home: \x1b[H, End: \x1b[F)
  /// With modifier: \x1b[1;{mod}{finalChar}
  String _getFinalCharSequence(String finalChar) {
    final mod = _shiftPressed ? 2 : _ctrlPressed ? 5 : _altPressed ? 3 : 0;
    if (mod == 0) return '\x1b[$finalChar';
    return '\x1b[1;$mod$finalChar';
  }

  /// Modified CSI sequence: parameter type (PageUp: \x1b[5~, Delete: \x1b[3~)
  /// With modifier: \x1b[{param};{mod}~
  String _getParamSequence(int param, String suffix) {
    final mod = _shiftPressed ? 2 : _ctrlPressed ? 5 : _altPressed ? 3 : 0;
    if (mod == 0) return '\x1b[$param$suffix';
    return '\x1b[$param;$mod$suffix';
  }

  /// F1-F4 sequence (SS3 format, convert to CSI format if modifier present)
  /// F1=P, F2=Q, F3=R, F4=S
  /// Without modifier: \x1bO{code}, with modifier: \x1b[1;{mod}{code}
  String _getFKeySequence(String code) {
    final mod = _shiftPressed ? 2 : _ctrlPressed ? 5 : _altPressed ? 3 : 0;
    if (mod == 0) return '\x1bO$code';
    return '\x1b[1;$mod$code';
  }

  // === Modifier key toggle (for external control) ===

  void toggleCtrl() {
    setState(() {
      _ctrlPressed = !_ctrlPressed;
    });
    HapticFeedback.selectionClick();
  }

  void toggleAlt() {
    setState(() {
      _altPressed = !_altPressed;
    });
    HapticFeedback.selectionClick();
  }

  void toggleShift() {
    setState(() {
      _shiftPressed = !_shiftPressed;
    });
    HapticFeedback.selectionClick();
  }

  bool get ctrlPressed => _ctrlPressed;
  bool get altPressed => _altPressed;
  bool get shiftPressed => _shiftPressed;

  void resetModifiers() {
    setState(() {
      _ctrlPressed = false;
      _altPressed = false;
      _shiftPressed = false;
    });
  }

  // === Scroll control ===

  /// Scroll to bottom
  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_verticalScrollController.hasClients) {
        _verticalScrollController.animateTo(
          _verticalScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Scroll to top
  void scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_verticalScrollController.hasClients) {
        _verticalScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Scroll to cursor position
  void scrollToCaret() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_verticalScrollController.hasClients) return;

      final parsedLines = _cachedParsedLines;
      if (parsedLines == null || parsedLines.isEmpty) return;

      // Calculate cursor line index (same logic as in build)
      final int cursorLineIndex;
      if (parsedLines.length >= widget.paneHeight) {
        cursorLineIndex =
            parsedLines.length - widget.paneHeight + widget.cursorY;
      } else {
        cursorLineIndex = widget.cursorY;
      }

      // Scroll offset of cursor line
      final targetOffset = cursorLineIndex * _lineHeight;

      // Adjust so cursor line comes near center considering viewport height
      final viewportHeight =
          _verticalScrollController.position.viewportDimension;
      final centeredOffset =
          targetOffset - (viewportHeight / 2) + (_lineHeight / 2);

      // Clamp to valid range
      final maxExtent = _verticalScrollController.position.maxScrollExtent;
      final clampedOffset = centeredOffset.clamp(0.0, maxExtent);

      _verticalScrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }
}
