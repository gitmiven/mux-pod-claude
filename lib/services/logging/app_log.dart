import 'package:flutter/foundation.dart';

/// Severity levels, ordered from most to least verbose. [none] disables output.
enum LogLevel { debug, info, warning, error, none }

/// Receives a formatted log line. Swappable so tests can capture output and
/// release builds can stay silent.
typedef LogSink = void Function(String line);

/// The single, level-gated, release-safe logging utility for the app.
///
/// - Gated **off in release builds** by default ([level] starts at [LogLevel.none]
///   when `kReleaseMode`), so diagnostics never ship to production logs.
/// - Never logs secrets (passwords, passphrases, private keys) or raw remote
///   command output — callers must pass only non-sensitive messages.
/// - Never throws: a failing [sink] is swallowed so logging can't crash the app.
///
/// Replaces the previous ad-hoc `debugPrint` / `developer.log` calls.
class AppLog {
  AppLog._();

  /// Minimum level to emit. Defaults to off in release, debug otherwise.
  static LogLevel level = kReleaseMode ? LogLevel.none : LogLevel.debug;

  /// Where formatted lines go. Defaults to [debugPrint]; tests replace it.
  static LogSink sink = _defaultSink;

  static void _defaultSink(String line) => debugPrint(line);

  /// Restore production defaults (for use in test `tearDown`).
  static void resetForTesting() {
    level = kReleaseMode ? LogLevel.none : LogLevel.debug;
    sink = _defaultSink;
  }

  static void d(String message, {String? tag}) =>
      _emit(LogLevel.debug, message, tag);

  static void i(String message, {String? tag}) =>
      _emit(LogLevel.info, message, tag);

  static void w(String message, {String? tag}) =>
      _emit(LogLevel.warning, message, tag);

  static void e(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _emit(LogLevel.error, message, tag, error, stackTrace);

  static void _emit(
    LogLevel level_,
    String message,
    String? tag, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (level == LogLevel.none || level_.index < level.index) return;
    try {
      final label = level_.name.toUpperCase();
      final prefix = tag != null ? '$label [$tag]' : label;
      sink('$prefix $message');
      if (error != null) sink('$prefix   error: $error');
      if (stackTrace != null) sink('$prefix   stack: $stackTrace');
    } catch (_) {
      // Logging must never throw.
    }
  }
}
