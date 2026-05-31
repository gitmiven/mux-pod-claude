import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import '../logging/app_log.dart';

/// Persistent shell session
///
/// Writes commands, detects output completion via markers, and returns the result.
/// Eliminates channel open/close overhead, enabling command execution in ~1 RTT.
class PersistentShell {
  final SSHClient _sshClient;
  SSHSession? _session;

  /// Core text for markers
  static const String _markerId = '7f3d8a2b';

  /// Marker for detecting command start (\x01 prefix/suffix included)
  ///
  /// By including \x01 (SOH control character), we distinguish it from literal
  /// text in shell echo output (where `\x01` appears as 4 characters).
  /// Only printf's actual output contains byte 0x01, so echo output won't match.
  static const String _startMarker = '\x01###START_$_markerId###\x01';

  /// Marker for detecting command end
  static const String _endMarker = '\x01###END_$_markerId###\x01';

  /// Marker strings for printf (used within shell commands)
  static const String _printfStartMarker = r'\x01###START_' '$_markerId' r'###\x01';
  static const String _printfEndMarker = r'\x01###END_' '$_markerId' r'###\x01';

  /// Output buffer (accumulated as byte sequence to prevent UTF-8 multibyte boundary split)
  final _rawBuffer = <int>[];

  /// Completer for command execution in progress
  Completer<String>? _pendingCommand;

  /// Whether the shell has started
  bool get isStarted => _session != null;

  /// For detecting session disconnection
  bool _isClosed = false;

  /// stdout subscription
  StreamSubscription<Uint8List>? _stdoutSubscription;

  PersistentShell(this._sshClient);

  /// Start the shell session
  Future<void> start() async {
    if (_session != null) {
      return; // Already started
    }

    _session = await _sshClient.shell(
      pty: SSHPtyConfig(
        type: 'dumb', // Minimal PTY (suppresses escape sequences)
        width: 200,
        height: 50,
      ),
    );

    _isClosed = false;

    // Start monitoring stdout
    _stdoutSubscription = _session!.stdout.listen(
      _onData,
      onDone: _onDone,
      onError: _onError,
    );

    // Wait for shell initialization (brief wait until prompt is output)
    await Future.delayed(const Duration(milliseconds: 100));

    // Disable history (Bash/Zsh/fish compatible) and suppress prompt
    // - export HISTFILE=... : for Bash/Zsh (overwritten after startup files)
    // - set fish_history ... : for fish (export causes syntax error, so separate)
    // - 2>/dev/null suppresses errors on unsupported shells
    _session!.write(utf8.encode(
      'export HISTFILE=/dev/null HISTSIZE=0 HISTFILESIZE=0 SAVEHIST=0 2>/dev/null;'
      ' set fish_history "" 2>/dev/null; true;'
      ' export PS1="" PS2="" 2>/dev/null; stty -echo\n',
    ));
    await Future.delayed(const Duration(milliseconds: 100));

    // Clear buffer (discard initialization output)
    _rawBuffer.clear();
  }

  /// Execute a command and retrieve the result
  ///
  /// [command] The command to execute
  /// [timeout] Timeout (default: 5 seconds)
  /// Returns: The command's standard output
  Future<String> exec(String command, {Duration? timeout}) async {
    if (_session == null) {
      throw PersistentShellError('Shell not started');
    }

    if (_isClosed) {
      throw PersistentShellError('Shell session is closed');
    }

    if (_pendingCommand != null && !_pendingCommand!.isCompleted) {
      throw PersistentShellError('Another command is already running');
    }

    _pendingCommand = Completer<String>();
    _rawBuffer.clear();

    // Output markers via printf (includes \x01 byte)
    // Use printf instead of echo: in shell echo output, literal '\x01' appears as 4 characters,
    // but printf's actual output contains byte 0x01.
    // This lets us reliably distinguish markers in echo output from markers in actual output.
    final commandWithMarkers =
        "printf '$_printfStartMarker\\n'; $command; printf '$_printfEndMarker\\n'\n";
    _session!.write(utf8.encode(commandWithMarkers));

    // Wait for result with timeout
    final effectiveTimeout = timeout ?? const Duration(seconds: 5);
    try {
      return await _pendingCommand!.future.timeout(effectiveTimeout);
    } on TimeoutException {
      _pendingCommand = null;
      throw PersistentShellError('Command execution timed out');
    }
  }

  /// Processing when stdout is received
  void _onData(Uint8List data) {
    // Ignore if no command is pending or already completed
    final pending = _pendingCommand;
    if (pending == null || pending.isCompleted) {
      return;
    }

    // Debug: UTF-8 boundary split detection (debug build only)
    assert(() {
      final chunkDecoded = utf8.decode(data, allowMalformed: true);
      if (chunkDecoded.contains('\uFFFD')) {
        final lastBytes = data.length > 6
            ? data.sublist(data.length - 6)
            : data;
        AppLog.d(
          '[PersistentShell] UTF-8 boundary split detected!'
          ' chunk_size=${data.length}'
          ' last_bytes=${lastBytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}'
        );
      }
      return true;
    }());

    // Accumulate as byte sequence (prevent UTF-8 boundary split from per-chunk decoding)
    _rawBuffer.addAll(data);

    // Decode the accumulated byte sequence all at once
    final content = utf8.decode(_rawBuffer, allowMalformed: true);

    // Check if both start and end markers are present
    final startIndex = content.indexOf(_startMarker);
    final endIndex = content.indexOf(_endMarker);

    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      // Extract from the line after the start marker to before the end marker
      final startPos = startIndex + _startMarker.length;
      var result = content.substring(startPos, endIndex);

      // Normalize because PTY output may use \r\n or \r
      // Fact: on macOS PTY, newlines=0, CRs=19 (\n is converted to \r)
      result = result.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

      // Remove leading and trailing newlines
      if (result.startsWith('\n')) {
        result = result.substring(1);
      }
      if (result.endsWith('\n')) {
        result = result.substring(0, result.length - 1);
      }

      // Set Completer to null first before completing (prevent re-entrance)
      _pendingCommand = null;
      _rawBuffer.clear();
      pending.complete(result);
    }
  }

  /// Processing when session ends
  void _onDone() {
    _isClosed = true;
    if (_pendingCommand != null && !_pendingCommand!.isCompleted) {
      _pendingCommand!.completeError(PersistentShellError('Shell session closed'));
    }
  }

  /// Processing when error occurs
  void _onError(Object error) {
    _isClosed = true;
    if (_pendingCommand != null && !_pendingCommand!.isCompleted) {
      _pendingCommand!.completeError(PersistentShellError('Shell error: $error'));
    }
  }

  /// Restart the shell session
  ///
  /// Call when session is disconnected
  Future<void> restart() async {
    await dispose();
    await start();
  }

  /// Release resources
  Future<void> dispose() async {
    _isClosed = true;

    if (_pendingCommand != null && !_pendingCommand!.isCompleted) {
      _pendingCommand!.completeError(PersistentShellError('Shell disposed'));
    }
    _pendingCommand = null;

    await _stdoutSubscription?.cancel();
    _stdoutSubscription = null;

    _session?.close();
    _session = null;

    _rawBuffer.clear();
  }
}

/// PersistentShell error
class PersistentShellError implements Exception {
  final String message;

  PersistentShellError(this.message);

  @override
  String toString() => 'PersistentShellError: $message';
}
