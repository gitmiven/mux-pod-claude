import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/settings_provider.dart';
import '../../../providers/terminal_display_provider.dart';
import '../../../services/terminal/ansi_parser.dart';
import '../../../services/terminal/font_calculator.dart';
import '../../../services/terminal/terminal_diff.dart';
import '../../../services/terminal/terminal_font_styles.dart';
import '../../../services/tmux/pane_navigator.dart';
import '../../../theme/design_colors.dart';
import 'eager_scale_gesture_recognizer.dart';

part 'ansi_text_view_logic.dart';
part 'ansi_text_view_view.dart';

/// Key input event
class KeyInputEvent {
  /// Key data (escape sequence or character)
  final String data;

  /// Whether it is a special key
  final bool isSpecialKey;

  /// tmux-format key name (e.g., 'Enter' for Enter)
  /// Used when isSpecialKey is true
  final String? tmuxKeyName;

  const KeyInputEvent({
    required this.data,
    this.isSpecialKey = false,
    this.tmuxKeyName,
  });
}

/// Terminal operation mode
enum TerminalMode {
  /// Normal mode (key input enabled)
  normal,

  /// Scroll mode (text selection possible, key input disabled)
  scroll,
}

/// ANSI text display widget
///
/// Display output of capture-pane -e with ANSI colors.
/// Uses RichText/SelectableText, eliminating xterm dependency.
class AnsiTextView extends ConsumerStatefulWidget {
  /// ANSI text to display
  final String text;

  /// Pane character width
  final int paneWidth;

  /// Pane character height
  final int paneHeight;

  /// Key input callback
  final void Function(KeyInputEvent)? onKeyInput;

  /// Background color
  final Color backgroundColor;

  /// Foreground color
  final Color foregroundColor;

  /// Operation mode
  final TerminalMode mode;

  /// Whether pinch zoom is enabled
  final bool zoomEnabled;

  /// Callback when zoom scale changes
  final void Function(double scale)? onZoomChanged;

  /// External vertical scroll controller (optional)
  final ScrollController? verticalScrollController;

  /// Cursor X position (0-based)
  final int cursorX;

  /// Cursor Y position (0-based, pane top reference)
  final int cursorY;

  /// Callback for arrow key input on hold+swipe
  /// direction: 'Up', 'Down', 'Left', 'Right'
  final void Function(String direction)? onArrowSwipe;

  /// Callback for pane switching on two-finger swipe
  final void Function(SwipeDirection direction)? onTwoFingerSwipe;

  /// Map indicating whether panes exist in each direction (for visual feedback)
  final Map<SwipeDirection, bool>? navigableDirections;

  /// Callback when terminal area is tapped
  final VoidCallback? onTap;

  const AnsiTextView({
    super.key,
    required this.text,
    required this.paneWidth,
    required this.paneHeight,
    this.onKeyInput,
    this.backgroundColor = const Color(0xFF1E1E1E),
    this.foregroundColor = const Color(0xFFD4D4D4),
    this.mode = TerminalMode.normal,
    this.zoomEnabled = true,
    this.onZoomChanged,
    this.verticalScrollController,
    this.cursorX = 0,
    this.cursorY = 0,
    this.onArrowSwipe,
    this.onTwoFingerSwipe,
    this.navigableDirections,
    this.onTap,
  });

  @override
  ConsumerState<AnsiTextView> createState() => AnsiTextViewState();
}

class AnsiTextViewState extends ConsumerState<AnsiTextView>
    with SingleTickerProviderStateMixin, _AnsiTextViewLogic, _AnsiTextViewView {
  @override
  void initState() {
    super.initState();
    // If no ScrollController is passed from outside, create one internally
    if (widget.verticalScrollController == null) {
      _internalVerticalScrollController = ScrollController();
    }
    _parser = AnsiParser(
      defaultForeground: widget.foregroundColor,
      defaultBackground: widget.backgroundColor,
    );

    // Blinks at 500ms interval (1 cycle per second)
    _caretBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(AnsiTextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.foregroundColor != widget.foregroundColor ||
        oldWidget.backgroundColor != widget.backgroundColor) {
      _parser = AnsiParser(
        defaultForeground: widget.foregroundColor,
        defaultBackground: widget.backgroundColor,
      );
      // Cache invalidated because parser changed
      _invalidateCache();
    }
  }

  @override
  void dispose() {
    _caretBlinkController.dispose();
    _focusNode.dispose();
    _horizontalScrollController.dispose();
    // Dispose only if created internally
    _internalVerticalScrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isScrollMode = widget.mode == TerminalMode.scroll;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Notify TerminalDisplayProvider of screen size (for resize dialog)
        // Execute after frame because provider changes are forbidden during build
        // Update only when value changes (prevent infinite loop)
        final currentDisplay = ref.read(terminalDisplayProvider);
        if (currentDisplay.screenWidth != constraints.maxWidth ||
            currentDisplay.screenHeight != constraints.maxHeight) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(terminalDisplayProvider.notifier).updateScreenSize(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
            }
          });
        }

        // Determine font size
        late final double fontSize;
        late final bool needsHorizontalScroll;

        if (settings.isAutoFit) {
          // Auto fit: calculate based on screen width
          final calcResult = FontCalculator.calculate(
            screenWidth: constraints.maxWidth,
            paneCharWidth: widget.paneWidth,
            fontFamily: settings.fontFamily,
            minFontSize: settings.minFontSize,
          );
          fontSize = calcResult.fontSize;
          needsHorizontalScroll = calcResult.needsScroll;
        } else {
          // Manual setting: use settings.fontSize
          fontSize = settings.fontSize;
          // Determine if horizontal scroll is needed
          final terminalWidth = FontCalculator.calculateTerminalWidth(
            paneCharWidth: widget.paneWidth,
            fontSize: fontSize,
            fontFamily: settings.fontFamily,
          );
          needsHorizontalScroll = terminalWidth > constraints.maxWidth;
        }

        // Calculate terminal width
        final terminalWidth = FontCalculator.calculateTerminalWidth(
          paneCharWidth: widget.paneWidth,
          fontSize: fontSize,
          fontFamily: settings.fontFamily,
        );

        // Get line data (cache used, for virtual scroll)
        final parsedLines = _getParsedLines(
          fontSize: fontSize,
          fontFamily: settings.fontFamily,
        );

        // ListView.builder with virtual scroll support
        Widget listWidget = ListView.builder(
          controller: _verticalScrollController,
          padding: EdgeInsets.zero, // Explicitly set padding to zero
          physics: const ClampingScrollPhysics(),
          itemCount: parsedLines.length,
          // Use fixed line height to speed up scroll calculation
          itemExtent: _lineHeight,
          // Auto-add RepaintBoundary
          addRepaintBoundaries: true,
          itemBuilder: (context, index) {
            final line = parsedLines[index];
            final textSpan = _parser.lineToTextSpan(
              line,
              fontSize: fontSize,
              fontFamily: settings.fontFamily,
            );

            // Text widget for each line
            Widget lineWidget = Text.rich(
              textSpan,
              style: TerminalFontStyles.getTextStyle(
                settings.fontFamily,
                fontSize: fontSize,
                height: 1.4,
                color: widget.foregroundColor,
              ),
              textScaler: TextScaler.noScaling,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
            );

            // Cursor rendering
            // Calculate line index of cursor position
            // parsedLines contains history + visible area.
            // The last paneHeight portion becomes the visible area.
            final int cursorLineIndex;
            if (parsedLines.length >= widget.paneHeight) {
              cursorLineIndex = parsedLines.length - widget.paneHeight + widget.cursorY;
            } else {
              // If line count is less than paneHeight, simply use cursorY (initial state, etc.)
              cursorLineIndex = widget.cursorY;
            }

            // If current line matches cursor position, overlay cursor with Stack
            if (index == cursorLineIndex &&
                widget.mode == TerminalMode.normal &&
                settings.showTerminalCursor) {
              // Use TextPainter.getOffsetForCaret to get accurate cursor position calculated by rendering engine
              double cursorLeft;
              double charWidth;

              // Create TextPainter using full line text and style
              final textSpanFull = _parser.lineToTextSpan(
                line,
                fontSize: fontSize,
                fontFamily: settings.fontFamily,
              );

              final painter = TextPainter(
                text: textSpanFull,
                textDirection: TextDirection.ltr,
                textScaler: TextScaler.noScaling,
              )..layout();

              // Get plain text of line
              final lineText = line.segments.map((s) => s.text).join();
              final lineTextLength = lineText.length;

              // Convert column position to character offset considering full-width characters
              // tmux's cursor_x is column position (full-width = 2), but
              // TextPosition expects character offset (full-width = 1)
              final lineDisplayWidth = FontCalculator.getTextDisplayWidth(lineText);
              final charOffset = FontCalculator.columnToCharOffset(lineText, widget.cursorX);

              if (widget.cursorX <= lineDisplayWidth) {
                 // If cursor is within line, get position with getOffsetForCaret
                 final offset = painter.getOffsetForCaret(
                   TextPosition(offset: charOffset),
                   Rect.zero,
                 );
                 cursorLeft = offset.dx;

                 // Get cursor width from current character position (width to next character)
                 // Use standard width at line end
                 if (charOffset < lineTextLength) {
                    final nextOffset = painter.getOffsetForCaret(
                      TextPosition(offset: charOffset + 1),
                      Rect.zero,
                    );
                    charWidth = nextOffset.dx - offset.dx;
                 } else {
                    charWidth = FontCalculator.measureCharWidth(settings.fontFamily, fontSize);
                 }
              } else {
                 // If cursor is beyond line end (empty line or space after line end)
                 // Get line end position and add excess
                 cursorLeft = painter.width;
                 charWidth = FontCalculator.measureCharWidth(settings.fontFamily, fontSize);
                 cursorLeft += (widget.cursorX - lineDisplayWidth) * charWidth;
              }

              lineWidget = Stack(
                clipBehavior: Clip.none,
                children: [
                  lineWidget,
                  AnimatedBuilder(
                    animation: _caretBlinkController,
                    builder: (context, child) {
                      // Match caret height to font size (not including line spacing)
                      final caretHeight = fontSize;
                      // Center vertically within line
                      final caretTop = (_lineHeight - caretHeight) / 2;

                      return Positioned(
                        left: cursorLeft,
                        top: caretTop,
                        width: 2,
                        height: caretHeight,
                        child: Opacity(
                          opacity: _caretBlinkController.value, // Fade in/out
                          child: Container(
                            color: DesignColors.primary,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            }

            // Fixed-width container (for horizontal scroll)
            if (needsHorizontalScroll) {
              lineWidget = SizedBox(
                width: terminalWidth,
                child: lineWidget,
              );
            }

            return lineWidget;
          },
        );

        // If horizontal scroll is needed
        if (needsHorizontalScroll) {
          listWidget = SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              width: terminalWidth,
              height: constraints.maxHeight,
              child: listWidget,
            ),
          );
        }

        // Pinch zoom + two-finger swipe
        if (widget.zoomEnabled) {
          // Force gesture arena win on two-finger detection with RawGestureDetector
          listWidget = RawGestureDetector(
            gestures: <Type, GestureRecognizerFactory>{
              EagerScaleGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    EagerScaleGestureRecognizer
                  >(
                    () => EagerScaleGestureRecognizer(),
                    (EagerScaleGestureRecognizer instance) {
                      instance
                        ..onStart = _onScaleStart
                        ..onUpdate = _onScaleUpdate
                        ..onEnd = _onScaleEnd;
                    },
                  ),
            },
            child: Transform.scale(
              scale: _currentScale,
              alignment: Alignment.topLeft,
              child: listWidget,
            ),
          );
          // Track individual pointers with Listener (not participating in gesture arena)
          // Used to determine zoom/pan by dot product of finger movement direction vectors
          listWidget = Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUpOrCancel,
            onPointerCancel: _onPointerUpOrCancel,
            child: listWidget,
          );
        }

        // Enable text selection if in scroll mode
        if (isScrollMode) {
          return Container(
            color: widget.backgroundColor,
            child: SelectionArea(
              child: listWidget,
            ),
          );
        }

        // Normal mode: handle keyboard input
        // Support arrow key input with hold+swipe
        return Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: GestureDetector(
            onTap: () {
              _focusNode.requestFocus();
              widget.onTap?.call();
            },
            onLongPressStart: _onLongPressStart,
            onLongPressMoveUpdate: _onLongPressMoveUpdate,
            onLongPressEnd: _onLongPressEnd,
            child: Stack(
              children: [
                Container(
                  color: widget.backgroundColor,
                  child: listWidget,
                ),
                // Hold+swipe overlay
                if (_isLongPressing) _buildSwipeOverlay(),
                // Two-finger swipe overlay
                if (_isTwoFingerPanning || _twoFingerSwipeResult != null)
                  _buildTwoFingerSwipeOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

}

/// Two-finger gesture mode (determined at gesture start, locked until end)
enum _TwoFingerMode { undetermined, pan, zoom }

/// Pan-glow activation threshold (shared by logic + view).
const double _panGlowThreshold = 20.0;
