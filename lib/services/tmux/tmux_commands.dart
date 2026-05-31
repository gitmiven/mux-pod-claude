import 'dart:convert';
import 'dart:math';

import '../shell/shell_escape.dart';

/// Tmux command generation service
///
/// Utility class for generating tmux commands.
/// Uses format strings that correspond with TmuxParser.
class TmuxCommands {
  /// Default delimiter (||| is used because tab is converted over SSH)
  static const String delimiter = '|||';

  // ===== Sessions =====

  /// Get list of sessions command (detailed version)
  ///
  /// Output format: `session_name\tsession_created\tsession_attached\tsession_windows\tsession_id`
  static String listSessions() {
    return 'tmux list-sessions -F "'
        '#{session_name}$delimiter'
        '#{session_created}$delimiter'
        '#{session_attached}$delimiter'
        '#{session_windows}$delimiter'
        '#{session_id}'
        '"';
  }

  /// Get list of sessions command (simple version)
  ///
  /// Output format: `session_name:session_windows:session_attached`
  static String listSessionsSimple() {
    return 'tmux list-sessions -F "#{session_name}:#{session_windows}:#{session_attached}"';
  }

  /// Check if a session exists
  static String hasSession(String sessionName) {
    return 'tmux has-session -t ${_escapeArg(sessionName)} 2>/dev/null && echo "1" || echo "0"';
  }

  /// Create a new session
  static String newSession({
    required String name,
    String? windowName,
    String? startDirectory,
    bool detached = true,
  }) {
    final parts = ['tmux', 'new-session'];
    if (detached) parts.add('-d');
    parts.addAll(['-s', _escapeArg(name)]);
    if (windowName != null) parts.addAll(['-n', _escapeArg(windowName)]);
    if (startDirectory != null) parts.addAll(['-c', _escapeArg(startDirectory)]);
    return parts.join(' ');
  }

  /// Delete a session
  static String killSession(String sessionName) {
    return 'tmux kill-session -t ${_escapeArg(sessionName)}';
  }

  /// Rename a session
  static String renameSession(String oldName, String newName) {
    return 'tmux rename-session -t ${_escapeArg(oldName)} ${_escapeArg(newName)}';
  }

  // ===== Windows =====

  /// Get list of windows command (detailed version)
  ///
  /// Output format: `window_index\twindow_id\twindow_name\twindow_active\twindow_panes\twindow_flags`
  static String listWindows(String sessionName) {
    return 'tmux list-windows -t ${_escapeArg(sessionName)} -F "'
        '#{window_index}$delimiter'
        '#{window_id}$delimiter'
        '#{window_name}$delimiter'
        '#{window_active}$delimiter'
        '#{window_panes}$delimiter'
        '#{window_flags}'
        '"';
  }

  /// Get list of windows command (simple version)
  ///
  /// Output format: `window_index:window_name:window_active:window_panes`
  static String listWindowsSimple(String sessionName) {
    return 'tmux list-windows -t ${_escapeArg(sessionName)} -F "'
        '#{window_index}:#{window_name}:#{window_active}:#{window_panes}"';
  }

  /// Create a new window
  static String newWindow({
    required String sessionName,
    String? windowName,
    String? startDirectory,
    bool background = false,
  }) {
    final parts = ['tmux', 'new-window', '-t', _escapeArg(sessionName)];
    if (background) parts.add('-d');
    if (windowName != null) parts.addAll(['-n', _escapeArg(windowName)]);
    if (startDirectory != null) parts.addAll(['-c', _escapeArg(startDirectory)]);
    return parts.join(' ');
  }

  /// Select a window
  static String selectWindow(String sessionName, int windowIndex) {
    return 'tmux select-window -t ${_escapeArg(sessionName)}:$windowIndex';
  }

  /// Delete a window
  static String killWindow(String sessionName, int windowIndex) {
    return 'tmux kill-window -t ${_escapeArg(sessionName)}:$windowIndex';
  }

  /// Rename a window
  static String renameWindow(String sessionName, int windowIndex, String newName) {
    return 'tmux rename-window -t ${_escapeArg(sessionName)}:$windowIndex ${_escapeArg(newName)}';
  }

  // ===== Panes =====

  /// Get list of panes command (detailed version)
  ///
  /// Output format: `pane_index\tpane_id\tpane_active\tpane_current_command\tpane_title\tpane_width\tpane_height\tcursor_x\tcursor_y`
  static String listPanes(String sessionName, int windowIndex) {
    return 'tmux list-panes -t ${_escapeArg(sessionName)}:$windowIndex -F "'
        '#{pane_index}$delimiter'
        '#{pane_id}$delimiter'
        '#{pane_active}$delimiter'
        '#{pane_current_command}$delimiter'
        '#{pane_title}$delimiter'
        '#{pane_width}$delimiter'
        '#{pane_height}$delimiter'
        '#{cursor_x}$delimiter'
        '#{cursor_y}'
        '"';
  }

  /// Get list of panes command (simple version)
  ///
  /// Output format: `pane_index:pane_id:pane_active:pane_width x pane_height`
  static String listPanesSimple(String sessionName, int windowIndex) {
    return 'tmux list-panes -t ${_escapeArg(sessionName)}:$windowIndex -F "'
        '#{pane_index}:#{pane_id}:#{pane_active}:#{pane_width}x#{pane_height}"';
  }

  /// Get all panes command (for session tree construction)
  ///
  /// Output format: Complete tree information (including window_flags)
  static String listAllPanes() {
    return 'tmux list-panes -a -F "'
        '#{session_name}$delimiter'
        '#{session_id}$delimiter'
        '#{window_index}$delimiter'
        '#{window_id}$delimiter'
        '#{window_name}$delimiter'
        '#{window_active}$delimiter'
        '#{pane_index}$delimiter'
        '#{pane_id}$delimiter'
        '#{pane_active}$delimiter'
        '#{pane_width}$delimiter'
        '#{pane_height}$delimiter'
        '#{pane_left}$delimiter'
        '#{pane_top}$delimiter'
        '#{pane_title}$delimiter'
        '#{pane_current_command}$delimiter'
        '#{cursor_x}$delimiter'
        '#{cursor_y}$delimiter'
        '#{pane_current_path}$delimiter'
        '#{window_flags}'
        '"';
  }

  /// Select a pane
  static String selectPane(String paneId) {
    return 'tmux select-pane -t ${_escapeArg(paneId)}';
  }

  /// Split pane horizontally
  static String splitWindowHorizontal({
    required String target,
    String? startDirectory,
    int? percentage,
  }) {
    final parts = ['tmux', 'split-window', '-h', '-t', _escapeArg(target)];
    if (percentage != null) parts.addAll(['-p', percentage.toString()]);
    if (startDirectory != null) parts.addAll(['-c', _escapeArg(startDirectory)]);
    return parts.join(' ');
  }

  /// Split pane vertically
  static String splitWindowVertical({
    required String target,
    String? startDirectory,
    int? percentage,
  }) {
    final parts = ['tmux', 'split-window', '-v', '-t', _escapeArg(target)];
    if (percentage != null) parts.addAll(['-p', percentage.toString()]);
    if (startDirectory != null) parts.addAll(['-c', _escapeArg(startDirectory)]);
    return parts.join(' ');
  }

  /// Delete a pane
  static String killPane(String paneId) {
    return 'tmux kill-pane -t ${_escapeArg(paneId)}';
  }

  /// Zoom or unzoom a pane
  static String resizePane(String paneId, {bool zoom = true}) {
    return 'tmux resize-pane -t ${_escapeArg(paneId)} ${zoom ? '-Z' : '-z'}';
  }

  /// Resize pane to specified dimensions
  /// cols/rows are optional (either can be specified alone; tmux does not change unspecified dimension)
  static String resizePaneToSize(String paneId, {int? cols, int? rows}) {
    final args = <String>['-t', _escapeArg(paneId)];
    if (cols != null) args.addAll(['-x', '$cols']);
    if (rows != null) args.addAll(['-y', '$rows']);
    return 'tmux resize-pane ${args.join(' ')}';
  }

  /// Resize window to specified dimensions (requires tmux 2.9+)
  static String resizeWindow(String target, {int? cols, int? rows}) {
    final args = <String>['-t', _escapeArg(target)];
    if (cols != null) args.addAll(['-x', '$cols']);
    if (rows != null) args.addAll(['-y', '$rows']);
    return 'tmux resize-window ${args.join(' ')}';
  }

  // ===== Input and key sending =====

  /// Send keys
  static String sendKeys(String paneId, String keys, {bool literal = false}) {
    final escapedKeys = _escapeArg(keys);
    if (literal) {
      return 'tmux send-keys -t ${_escapeArg(paneId)} -l $escapedKeys';
    }
    return 'tmux send-keys -t ${_escapeArg(paneId)} $escapedKeys';
  }

  /// Send Enter key
  static String sendEnter(String paneId) {
    return 'tmux send-keys -t ${_escapeArg(paneId)} Enter';
  }

  /// Build a single shell command that loads [text] into a named tmux
  /// buffer and pastes it into the given [target] pane using bracketed
  /// paste mode (`paste-buffer -p`).
  ///
  /// Intended for multi-line text only; single-key / control-key paths
  /// use [sendKeys] directly.
  ///
  /// The payload is base64-encoded in transit so any shell-special
  /// characters in [text] do not need extra escaping. The receiving
  /// remote is expected to have a POSIX `base64` binary on PATH.
  ///
  /// The buffer is named with a microsecond timestamp plus a random hex
  /// suffix to avoid collisions when multiple paste operations run
  /// concurrently. `-d` deletes the buffer immediately after pasting.
  ///
  /// Practical upper bound: tested up to ~100 KB; very large pastes may
  /// exceed ARG_MAX (~256 KB on macOS, ~2 MB on Linux). True stdin-piping
  /// via dartssh2 would remove this limit but is deferred.
  ///
  /// Note: requires tmux >= 2.6 for `-p` (bracketed paste). Use
  /// [loadBufferAndPasteNoBracketed] as a fallback for older tmux.
  static String loadBufferAndPaste(String target, String text) {
    final encoded = base64.encode(utf8.encode(text));
    final rand = Random().nextInt(0xffffff).toRadixString(16).padLeft(6, '0');
    // bufName is safe: numeric + lowercase hex only — no escaping needed.
    final bufName = 'muxpod-${DateTime.now().microsecondsSinceEpoch}-$rand';
    return "printf '%s' '$encoded' | base64 -d "
        "| tmux load-buffer -b '$bufName' - "
        "&& tmux paste-buffer -d -p -b '$bufName' -t ${_escapeArg(target)}";
  }

  /// Fallback variant of [loadBufferAndPaste] for tmux < 2.6, which does
  /// not support the `-p` (bracketed paste) flag on `paste-buffer`.
  ///
  /// Prefer [loadBufferAndPaste] when the remote tmux version is >= 2.6.
  static String loadBufferAndPasteNoBracketed(String target, String text) {
    final encoded = base64.encode(utf8.encode(text));
    final rand = Random().nextInt(0xffffff).toRadixString(16).padLeft(6, '0');
    // bufName is safe: numeric + lowercase hex only — no escaping needed.
    final bufName = 'muxpod-${DateTime.now().microsecondsSinceEpoch}-$rand';
    return "printf '%s' '$encoded' | base64 -d "
        "| tmux load-buffer -b '$bufName' - "
        "&& tmux paste-buffer -d -b '$bufName' -t ${_escapeArg(target)}";
  }

  /// Send Ctrl+C
  static String sendInterrupt(String paneId) {
    return 'tmux send-keys -t ${_escapeArg(paneId)} C-c';
  }

  /// Send Escape key
  static String sendEscape(String paneId) {
    return 'tmux send-keys -t ${_escapeArg(paneId)} Escape';
  }

  /// Get cursor position and pane dimensions
  static String getCursorPosition(String target) {
    return 'tmux display-message -p -t ${_escapeArg(target)} "#{cursor_x},#{cursor_y},#{pane_width},#{pane_height}"';
  }

  /// Get pane mode (for copy-mode detection)
  static String getPaneMode(String target) {
    return 'tmux display-message -p -t ${_escapeArg(target)} "#{pane_mode}"';
  }

  /// Enter copy-mode
  static String enterCopyMode(String target) {
    return 'tmux copy-mode -t ${_escapeArg(target)}';
  }

  /// Exit copy-mode (only effective when in copy-mode; harmless when not in copy-mode)
  static String cancelCopyMode(String target) {
    return 'tmux send-keys -t ${_escapeArg(target)} -X cancel';
  }

  // ===== Pane content =====

  /// Capture pane content (with ANSI escape sequences)
  static String capturePane(
    String paneId, {
    int? startLine,
    int? endLine,
    bool escapeSequences = true,
  }) {
    final parts = ['tmux', 'capture-pane', '-t', _escapeArg(paneId), '-p'];
    if (escapeSequences) parts.add('-e');
    if (startLine != null) parts.addAll(['-S', startLine.toString()]);
    if (endLine != null) parts.addAll(['-E', endLine.toString()]);
    return parts.join(' ');
  }

  /// Capture visible area of pane
  static String capturePaneVisible(String paneId) {
    return capturePane(paneId, escapeSequences: true);
  }

  /// Capture entire scrollback buffer of pane
  static String capturePaneAll(String paneId) {
    return capturePane(paneId, startLine: -32768, endLine: 32768);
  }

  // ===== Session/Attach =====

  /// Attach to a session
  static String attachSession(String sessionName) {
    return 'tmux attach-session -t ${_escapeArg(sessionName)}';
  }

  /// Detach from a session
  static String detachClient({String? sessionName}) {
    if (sessionName != null) {
      return 'tmux detach-client -s ${_escapeArg(sessionName)}';
    }
    return 'tmux detach-client';
  }

  // ===== Server =====

  /// Check if tmux server is running
  static String serverInfo() {
    return 'tmux server-info 2>&1';
  }

  /// Get tmux version
  static String version() {
    return 'tmux -V';
  }

  /// Start tmux server
  static String startServer() {
    return 'tmux start-server';
  }

  /// Terminate tmux server
  static String killServer() {
    return 'tmux kill-server';
  }

  // ===== Layout =====

  /// Apply a predefined layout
  static String selectLayout(String target, TmuxLayout layout) {
    return 'tmux select-layout -t ${_escapeArg(target)} ${layout.name}';
  }

  // ===== Utility =====

  /// Escape arguments
  ///
  /// Delegates to [ShellEscape], the sole shared mechanism for command injection prevention (FR-013).
  static String _escapeArg(String arg) => ShellEscape.quote(arg);

  /// Chain multiple commands
  static String chain(List<String> commands) {
    return commands.join(' && ');
  }

  /// Pipe multiple commands
  static String pipe(List<String> commands) {
    return commands.join(' | ');
  }
}

/// Pane split direction
enum SplitDirection {
  /// Split to the right (arrange left-right) - tmux split-window -h
  horizontal,

  /// Split downward (arrange top-bottom) - tmux split-window -v
  vertical,
}

/// Tmux layout
enum TmuxLayout {
  /// Evenly divided horizontally
  evenHorizontal,

  /// Evenly divided vertically
  evenVertical,

  /// Main pane positioned at top
  mainHorizontal,

  /// Main pane positioned at left
  mainVertical,

  /// Arranged in tile pattern
  tiled,
}

extension TmuxLayoutExtension on TmuxLayout {
  String get name {
    switch (this) {
      case TmuxLayout.evenHorizontal:
        return 'even-horizontal';
      case TmuxLayout.evenVertical:
        return 'even-vertical';
      case TmuxLayout.mainHorizontal:
        return 'main-horizontal';
      case TmuxLayout.mainVertical:
        return 'main-vertical';
      case TmuxLayout.tiled:
        return 'tiled';
    }
  }
}
