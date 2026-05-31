import 'package:flutter/gestures.dart';

/// ScaleGestureRecognizer that forcibly wins gesture arena when 2+ fingers detected.
///
/// Normal ScaleGestureRecognizer loses to
/// HorizontalDragGestureRecognizer in internal SingleChildScrollView in gesture arena.
/// This class overrides rejectGesture() to acceptGesture() when 2 fingers detected,
/// forcibly winning arena. For 1 finger, normally delegates with super.rejectGesture()
/// to ScrollView, so single-finger scroll is unaffected.
class EagerScaleGestureRecognizer extends ScaleGestureRecognizer {
  int _pointerCount = 0;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _pointerCount++;
  }

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointerCount = (_pointerCount - 1).clamp(0, 99);
    }
  }

  @override
  void rejectGesture(int pointer) {
    if (_pointerCount >= 2) {
      acceptGesture(pointer);
    } else {
      super.rejectGesture(pointer);
    }
  }

  @override
  void dispose() {
    _pointerCount = 0;
    super.dispose();
  }
}
