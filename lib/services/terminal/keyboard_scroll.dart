/// Pure decision logic for revealing the terminal input line when the soft
/// keyboard opens.
///
/// The terminal screen observes bottom view-inset changes (`didChangeMetrics`).
/// When the keyboard slides up the layout shrinks, but the terminal's scroll
/// position is not moved — so the live prompt / cursor line ends up hidden
/// behind the keyboard. We scroll to the caret on the keyboard *show* edge.
///
/// This function isolates the "should we scroll now?" decision so it can be
/// unit-tested without a widget/engine harness.
///
/// Returns true only on the rising edge — the inset was below [threshold]
/// (keyboard hidden) and is now above it (keyboard shown) — and only when the
/// terminal is in its normal follow-the-cursor state. While the user is reading
/// history in scroll mode ([isScrollMode] true) we never yank the view.
bool shouldScrollOnKeyboardShow({
  required double prevInset,
  required double newInset,
  required bool isScrollMode,
  double threshold = 80.0,
}) {
  if (isScrollMode) return false;
  final wasVisible = prevInset > threshold;
  final isVisible = newInset > threshold;
  return !wasVisible && isVisible;
}
