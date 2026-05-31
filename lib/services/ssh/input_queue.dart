/// Class for queuing input while disconnected
///
/// Holds key input while the SSH connection is disconnected,
/// allowing batched sending after reconnection.
class InputQueue {
  final List<String> _queue = [];

  /// Maximum queue size (character count)
  static const int maxSize = 1000;

  /// Adds input to the queue
  ///
  /// If exceeding maxSize, the input is not added and isOverflow becomes true.
  void enqueue(String input) {
    if (length + input.length <= maxSize) {
      _queue.add(input);
    }
  }

  /// Extracts and joins all input from the queue
  ///
  /// After extraction, the queue becomes empty.
  String flush() {
    if (_queue.isEmpty) return '';
    final result = _queue.join();
    _queue.clear();
    return result;
  }

  /// Clears the queue
  void clear() {
    _queue.clear();
  }

  /// Whether the queue is empty
  bool get isEmpty => _queue.isEmpty;

  /// Total character count in the queue
  int get length {
    int total = 0;
    for (final item in _queue) {
      total += item.length;
    }
    return total;
  }

  /// Whether the queue is in overflow state (cannot add more)
  bool get isOverflow => length >= maxSize;

  /// Number of items in the queue
  int get itemCount => _queue.length;
}
