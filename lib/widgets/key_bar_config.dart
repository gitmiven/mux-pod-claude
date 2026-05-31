import 'package:flutter/foundation.dart';

/// One button in the variable key bar: a visible [label] and the tmux key name
/// it sends (e.g. label `F1` → key `F1`, sent via `send-keys`).
@immutable
class KeyBarButton {
  final String label;
  final String tmuxKey;
  const KeyBarButton(this.label, this.tmuxKey);
}

/// A named, ordered set of buttons for the **variable key bar** — the third bar
/// shown above the special-key rows at the bottom of the terminal.
///
/// The bar is data-driven: it renders whichever configuration it is given, so
/// future features can supply a different button set without changing the bar
/// or the terminal screen's wiring. The only set that ships today is
/// [functionKeys].
@immutable
class KeyBarConfig {
  final String name;
  final List<KeyBarButton> buttons;
  const KeyBarConfig({required this.name, required this.buttons});

  /// The initial (and currently only) configuration: function keys F1–F10.
  /// Each button sends the matching tmux key name; modifier toggles on the
  /// special-key bar compose with it (e.g. SHIFT+F1 → `S-F1`).
  static const KeyBarConfig functionKeys = KeyBarConfig(
    name: 'Function keys',
    buttons: [
      KeyBarButton('F1', 'F1'),
      KeyBarButton('F2', 'F2'),
      KeyBarButton('F3', 'F3'),
      KeyBarButton('F4', 'F4'),
      KeyBarButton('F5', 'F5'),
      KeyBarButton('F6', 'F6'),
      KeyBarButton('F7', 'F7'),
      KeyBarButton('F8', 'F8'),
      KeyBarButton('F9', 'F9'),
      KeyBarButton('F10', 'F10'),
    ],
  );
}
