/// Key overlay category
enum KeyOverlayCategory {
  /// Modifier key combinations: Ctrl+x, Alt+x, Shift+x
  modifier,

  /// Standalone special keys: ESC, TAB, ENTER, S-Enter, BSpace, BTab
  special,

  /// Arrow keys: Up, Down, Left, Right
  arrow,

  /// Shortcut keys: /, -, 1, 2, 3, 4
  shortcut,
}

/// Key overlay display position
enum KeyOverlayPosition {
  /// Directly above the keyboard (SpecialKeysBar)
  aboveKeyboard,

  /// Center of the terminal area
  center,

  /// Directly below the breadcrumb header
  belowHeader,
}

/// Utility to convert tmux send-keys format key names to human-readable display
class TmuxKeyDisplay {
  static const _specialKeys = {
    'Escape', 'Tab', 'Enter', 'BSpace', 'BTab', 'S-Enter',
  };

  static const _arrowKeys = {'Up', 'Down', 'Left', 'Right'};

  static const _shortcutKeys = {'/', '-', '1', '2', '3', '4'};

  static const _displayMap = {
    'Escape': 'ESC',
    'Tab': 'TAB',
    'Enter': 'ENTER',
    'S-Enter': 'Shift+Enter',
    'BSpace': 'BS',
    'BTab': 'Shift+TAB',
    'Up': '↑',
    'Down': '↓',
    'Left': '←',
    'Right': '→',
  };

  static final _modifierPattern = RegExp(r'^([CMS]-)+');

  /// Determine overlay category from tmux key name
  ///
  /// Returns null if no match is found
  static KeyOverlayCategory? categoryOf(String tmuxKey) {
    if (_specialKeys.contains(tmuxKey)) return KeyOverlayCategory.special;
    if (_arrowKeys.contains(tmuxKey)) return KeyOverlayCategory.arrow;
    if (_shortcutKeys.contains(tmuxKey)) return KeyOverlayCategory.shortcut;
    if (_modifierPattern.hasMatch(tmuxKey)) return KeyOverlayCategory.modifier;
    return null;
  }

  /// Determine if a literal key matches a shortcut key
  static bool isShortcutKey(String key) => _shortcutKeys.contains(key);

  /// Convert tmux format key names to human-readable text
  static String displayText(String tmuxKey) {
    // Fixed mapping
    final mapped = _displayMap[tmuxKey];
    if (mapped != null) return mapped;

    // Modifier key pattern: C-c → Ctrl+C, M-x → Alt+X, S-a → Shift+A
    final match = _modifierPattern.firstMatch(tmuxKey);
    if (match != null) {
      final prefix = match.group(0)!;
      final baseKey = tmuxKey.substring(prefix.length);
      final parts = <String>[];
      if (prefix.contains('C-')) parts.add('Ctrl');
      if (prefix.contains('M-')) parts.add('Alt');
      if (prefix.contains('S-')) parts.add('Shift');
      final displayBase = _displayMap[baseKey] ?? baseKey.toUpperCase();
      parts.add(displayBase);
      return parts.join('+');
    }

    // Return as-is (literal keys such as /, -, 1-4)
    return tmuxKey;
  }
}
