part of 'ansi_text_view.dart';

mixin _AnsiTextViewView on _AnsiTextViewLogic {
  /// Swipe overlay widget
  Widget _buildSwipeOverlay() {
    return Center(
      child: AnimatedOpacity(
        opacity: _isLongPressing ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              // Up arrow
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Icon(
                  Icons.arrow_drop_up,
                  size: 40,
                  color: _lastSwipeDirection == 'Up'
                      ? Colors.amber
                      : Colors.white.withValues(alpha: 0.6),
                ),
              ),
              // Down arrow
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Icon(
                  Icons.arrow_drop_down,
                  size: 40,
                  color: _lastSwipeDirection == 'Down'
                      ? Colors.amber
                      : Colors.white.withValues(alpha: 0.6),
                ),
              ),
              // Left arrow
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Icon(
                  Icons.arrow_left,
                  size: 40,
                  color: _lastSwipeDirection == 'Left'
                      ? Colors.amber
                      : Colors.white.withValues(alpha: 0.6),
                ),
              ),
              // Right arrow
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Icon(
                  Icons.arrow_right,
                  size: 40,
                  color: _lastSwipeDirection == 'Right'
                      ? Colors.amber
                      : Colors.white.withValues(alpha: 0.6),
                ),
              ),
              // Center dot
              Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Visual feedback overlay for two-finger swipe
  Widget _buildTwoFingerSwipeOverlay() {
    // Flash display when reaching edge
    if (_twoFingerSwipeResult != null) {
      return _buildEdgeFlash(_twoFingerSwipeResult!);
    }

    // Edge glow display during pan
    if (_isTwoFingerPanning) {
      return _buildPanGlow();
    }

    return const SizedBox.shrink();
  }

  /// Red-toned flash when reaching edge
  Widget _buildEdgeFlash(SwipeDirection direction) {
    final alignment = switch (direction) {
      SwipeDirection.left => Alignment.centerLeft,
      SwipeDirection.right => Alignment.centerRight,
      SwipeDirection.up => Alignment.topCenter,
      SwipeDirection.down => Alignment.bottomCenter,
    };

    final isHorizontal =
        direction == SwipeDirection.left || direction == SwipeDirection.right;

    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: alignment,
          child: Container(
            width: isHorizontal ? 40 : double.infinity,
            height: isHorizontal ? double.infinity : 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: isHorizontal
                    ? (direction == SwipeDirection.left
                        ? Alignment.centerRight
                        : Alignment.centerLeft)
                    : (direction == SwipeDirection.up
                        ? Alignment.bottomCenter
                        : Alignment.topCenter),
                end: isHorizontal
                    ? (direction == SwipeDirection.left
                        ? Alignment.centerLeft
                        : Alignment.centerRight)
                    : (direction == SwipeDirection.up
                        ? Alignment.topCenter
                        : Alignment.bottomCenter),
                colors: [
                  Colors.transparent,
                  Colors.red.withValues(alpha: 0.4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Direction glow during pan
  Widget _buildPanGlow() {
    final dx = _twoFingerPanDelta.dx;
    final dy = _twoFingerPanDelta.dy;

    // Do not display if movement amount is too small
    if (dx.abs() < _panGlowThreshold && dy.abs() < _panGlowThreshold) {
      return const SizedBox.shrink();
    }

    SwipeDirection? direction;
    if (dx.abs() > dy.abs()) {
      direction = dx > 0 ? SwipeDirection.right : SwipeDirection.left;
    } else {
      direction = dy > 0 ? SwipeDirection.down : SwipeDirection.up;
    }

    final canNavigate = widget.navigableDirections?[direction] ?? true;
    final color = canNavigate
        ? DesignColors.primary.withValues(alpha: 0.2)
        : Colors.red.withValues(alpha: 0.15);

    final alignment = switch (direction) {
      SwipeDirection.left => Alignment.centerLeft,
      SwipeDirection.right => Alignment.centerRight,
      SwipeDirection.up => Alignment.topCenter,
      SwipeDirection.down => Alignment.bottomCenter,
    };

    final isHorizontal =
        direction == SwipeDirection.left || direction == SwipeDirection.right;

    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: alignment,
          child: Container(
            width: isHorizontal ? 30 : double.infinity,
            height: isHorizontal ? double.infinity : 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: isHorizontal
                    ? (direction == SwipeDirection.left
                        ? Alignment.centerRight
                        : Alignment.centerLeft)
                    : (direction == SwipeDirection.up
                        ? Alignment.bottomCenter
                        : Alignment.topCenter),
                end: isHorizontal
                    ? (direction == SwipeDirection.left
                        ? Alignment.centerLeft
                        : Alignment.centerRight)
                    : (direction == SwipeDirection.up
                        ? Alignment.topCenter
                        : Alignment.bottomCenter),
                colors: [
                  Colors.transparent,
                  color,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}
