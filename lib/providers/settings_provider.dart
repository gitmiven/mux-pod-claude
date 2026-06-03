import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/file_browser/file_browser_start.dart';
import '../services/settings_migration.dart';
import '../services/viewer/file_viewer_type.dart';

/// App settings
class AppSettings {
  final bool darkMode;
  final double fontSize;
  final String fontFamily;
  final bool requireBiometricAuth;
  final bool enableNotifications;
  final bool enableVibration;
  final bool keepScreenOn;
  final int scrollbackLines;
  final double minFontSize;

  /// Display adjustment mode: 'none', 'autoFit', 'autoResize'
  final String adjustMode;

  /// DirectInput mode (send input characters directly to terminal immediately)
  final bool directInputEnabled;

  /// Terminal cursor display setting
  final bool showTerminalCursor;

  /// Invert pane navigation direction
  final bool invertPaneNavigation;

  // --- Key overlay settings ---
  /// Key overlay enable/disable
  final bool showKeyOverlay;

  /// Key overlay: modifier key combinations (Ctrl+x, Alt+x, Shift+x)
  final bool keyOverlayModifier;

  /// Key overlay: standalone special keys (ESC, TAB, ENTER, S-Enter)
  final bool keyOverlaySpecial;

  /// Key overlay: arrow keys
  final bool keyOverlayArrow;

  /// Key overlay: shortcut keys (/, -, 1-4)
  final bool keyOverlayShortcut;

  /// Key overlay: display position
  final String keyOverlayPosition;

  // --- Image transfer settings ---
  final String imageRemotePath;
  final String imageOutputFormat;
  final int imageJpegQuality;
  final String imageResizePreset; // 'original'/'small'/'medium'/'large'/'custom'
  final int imageMaxWidth;
  final int imageMaxHeight;
  final String imagePathFormat;
  final bool imageAutoEnter;
  final bool imageBracketedPaste;

  /// Extension → in-app viewer-type mapping (type-name: `image`/`markdown`/`text`),
  /// e.g. `png → image`, `md → markdown`. Drives the file browser's
  /// `Open with <viewer>` action.
  final Map<String, String> fileViewers;

  /// Where the file browser opens: `claudeCodeFolder` (the pane CWD, default) or
  /// `lastVisited` (the remembered per-connection directory).
  final String fileBrowserStartDir;

  /// Pre-fill the "Enter Command" popup with the current terminal input line.
  final bool prefillCommandFromTerminal;

  /// Open the file browser with hidden (dot-prefixed) entries visible by
  /// default. The AppBar eye toggle still overrides this per session.
  final bool showHiddenFilesByDefault;

  const AppSettings({
    this.darkMode = true,
    this.fontSize = 14.0,
    this.fontFamily = 'JetBrains Mono',
    this.requireBiometricAuth = false,
    this.enableNotifications = true,
    this.enableVibration = true,
    this.keepScreenOn = true,
    this.scrollbackLines = 10000,
    this.minFontSize = 8.0,
    this.adjustMode = 'autoFit',
    this.directInputEnabled = false,
    this.showTerminalCursor = true,
    this.invertPaneNavigation = false,
    this.showKeyOverlay = true,
    this.keyOverlayModifier = true,
    this.keyOverlaySpecial = true,
    this.keyOverlayArrow = true,
    this.keyOverlayShortcut = true,
    this.keyOverlayPosition = 'aboveKeyboard',
    this.imageRemotePath = '/tmp/muxpod/',
    this.imageOutputFormat = 'original',
    this.imageJpegQuality = 85,
    this.imageResizePreset = 'original',
    this.imageMaxWidth = 1920,
    this.imageMaxHeight = 1080,
    this.imagePathFormat = '{path}',
    this.imageAutoEnter = false,
    this.imageBracketedPaste = false,
    this.fileViewers = kDefaultFileViewers,
    this.fileBrowserStartDir = kFileBrowserStartClaudeCode,
    this.prefillCommandFromTerminal = false,
    this.showHiddenFilesByDefault = false,
  });

  bool get isAutoFit => adjustMode == 'autoFit';
  bool get isAutoResize => adjustMode == 'autoResize';

  AppSettings copyWith({
    bool? darkMode,
    double? fontSize,
    String? fontFamily,
    bool? requireBiometricAuth,
    bool? enableNotifications,
    bool? enableVibration,
    bool? keepScreenOn,
    int? scrollbackLines,
    double? minFontSize,
    String? adjustMode,
    bool? directInputEnabled,
    bool? showTerminalCursor,
    bool? invertPaneNavigation,
    bool? showKeyOverlay,
    bool? keyOverlayModifier,
    bool? keyOverlaySpecial,
    bool? keyOverlayArrow,
    bool? keyOverlayShortcut,
    String? keyOverlayPosition,
    String? imageRemotePath,
    String? imageOutputFormat,
    int? imageJpegQuality,
    String? imageResizePreset,
    int? imageMaxWidth,
    int? imageMaxHeight,
    String? imagePathFormat,
    bool? imageAutoEnter,
    bool? imageBracketedPaste,
    Map<String, String>? fileViewers,
    String? fileBrowserStartDir,
    bool? prefillCommandFromTerminal,
    bool? showHiddenFilesByDefault,
  }) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      requireBiometricAuth: requireBiometricAuth ?? this.requireBiometricAuth,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      enableVibration: enableVibration ?? this.enableVibration,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      scrollbackLines: scrollbackLines ?? this.scrollbackLines,
      minFontSize: minFontSize ?? this.minFontSize,
      adjustMode: adjustMode ?? this.adjustMode,
      directInputEnabled: directInputEnabled ?? this.directInputEnabled,
      showTerminalCursor: showTerminalCursor ?? this.showTerminalCursor,
      invertPaneNavigation: invertPaneNavigation ?? this.invertPaneNavigation,
      showKeyOverlay: showKeyOverlay ?? this.showKeyOverlay,
      keyOverlayModifier: keyOverlayModifier ?? this.keyOverlayModifier,
      keyOverlaySpecial: keyOverlaySpecial ?? this.keyOverlaySpecial,
      keyOverlayArrow: keyOverlayArrow ?? this.keyOverlayArrow,
      keyOverlayShortcut: keyOverlayShortcut ?? this.keyOverlayShortcut,
      keyOverlayPosition: keyOverlayPosition ?? this.keyOverlayPosition,
      imageRemotePath: imageRemotePath ?? this.imageRemotePath,
      imageOutputFormat: imageOutputFormat ?? this.imageOutputFormat,
      imageJpegQuality: imageJpegQuality ?? this.imageJpegQuality,
      imageResizePreset: imageResizePreset ?? this.imageResizePreset,
      imageMaxWidth: imageMaxWidth ?? this.imageMaxWidth,
      imageMaxHeight: imageMaxHeight ?? this.imageMaxHeight,
      imagePathFormat: imagePathFormat ?? this.imagePathFormat,
      imageAutoEnter: imageAutoEnter ?? this.imageAutoEnter,
      imageBracketedPaste: imageBracketedPaste ?? this.imageBracketedPaste,
      fileViewers: fileViewers ?? this.fileViewers,
      fileBrowserStartDir: fileBrowserStartDir ?? this.fileBrowserStartDir,
      prefillCommandFromTerminal:
          prefillCommandFromTerminal ?? this.prefillCommandFromTerminal,
      showHiddenFilesByDefault:
          showHiddenFilesByDefault ?? this.showHiddenFilesByDefault,
    );
  }
}

/// Notifier for managing settings
class SettingsNotifier extends Notifier<AppSettings> {
  static const String _darkModeKey = 'settings_dark_mode';
  static const String _fontSizeKey = 'settings_font_size';
  static const String _fontFamilyKey = 'settings_font_family';
  static const String _biometricKey = 'settings_biometric_auth';
  static const String _notificationsKey = 'settings_notifications';
  static const String _vibrationKey = 'settings_vibration';
  static const String _keepScreenOnKey = 'settings_keep_screen_on';
  static const String _scrollbackKey = 'settings_scrollback';
  static const String _minFontSizeKey = 'settings_min_font_size';
  static const String _adjustModeKey = 'settings_adjust_mode';
  static const String _directInputEnabledKey = 'settings_direct_input_enabled';
  static const String _showTerminalCursorKey = 'settings_show_terminal_cursor';
  static const String _invertPaneNavKey = 'settings_invert_pane_nav';
  static const String _imageRemotePathKey = 'settings_image_remote_path';
  static const String _imageOutputFormatKey = 'settings_image_output_format';
  static const String _imageJpegQualityKey = 'settings_image_jpeg_quality';
  static const String _imageResizePresetKey = 'settings_image_resize_preset';
  static const String _imageMaxWidthKey = 'settings_image_max_width';
  static const String _imageMaxHeightKey = 'settings_image_max_height';
  static const String _imagePathFormatKey = 'settings_image_path_format';
  static const String _imageAutoEnterKey = 'settings_image_auto_enter';
  static const String _imageBracketedPasteKey = 'settings_image_bracketed_paste';
  static const String _showKeyOverlayKey = 'settings_show_key_overlay';
  static const String _keyOverlayModifierKey = 'settings_key_overlay_modifier';
  static const String _keyOverlaySpecialKey = 'settings_key_overlay_special';
  static const String _keyOverlayArrowKey = 'settings_key_overlay_arrow';
  static const String _keyOverlayShortcutKey = 'settings_key_overlay_shortcut';
  static const String _keyOverlayPositionKey = 'settings_key_overlay_position';
  static const String _fileViewersKey = 'settings_file_viewers';
  static const String _fileBrowserStartDirKey = 'settings_file_browser_start_dir';
  static const String _prefillCommandKey = 'settings_prefill_command_from_terminal';
  static const String _showHiddenFilesKey = 'settings_show_hidden_files_default';

  /// Decode the file-viewers map from its stored JSON, falling back to the
  /// defaults when absent or unparseable. Keeps only entries whose value is a
  /// recognised viewer type.
  static Map<String, String> _decodeFileViewers(String? raw) {
    if (raw == null || raw.isEmpty) return kDefaultFileViewers;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return kDefaultFileViewers;
      final map = <String, String>{};
      decoded.forEach((k, v) {
        final key = k.toString().toLowerCase().trim();
        final type = FileViewerType.fromName(v.toString());
        if (key.isNotEmpty && type != null) map[key] = type.name;
      });
      return map;
    } catch (_) {
      return kDefaultFileViewers;
    }
  }

  @override
  AppSettings build() {
    _loadSettings();
    return const AppSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await SettingsMigrationRunner.run(prefs);

    // The provider may have been disposed while the async load was in flight
    // (e.g. the screen was left, or a unit-test container was torn down).
    // Setting state after disposal throws; guard against it.
    if (!ref.mounted) return;

    state = AppSettings(
      darkMode: prefs.getBool(_darkModeKey) ?? true,
      fontSize: prefs.getDouble(_fontSizeKey) ?? 14.0,
      fontFamily: prefs.getString(_fontFamilyKey) ?? 'JetBrains Mono',
      requireBiometricAuth: prefs.getBool(_biometricKey) ?? false,
      enableNotifications: prefs.getBool(_notificationsKey) ?? true,
      enableVibration: prefs.getBool(_vibrationKey) ?? true,
      keepScreenOn: prefs.getBool(_keepScreenOnKey) ?? true,
      scrollbackLines: prefs.getInt(_scrollbackKey) ?? 10000,
      minFontSize: prefs.getDouble(_minFontSizeKey) ?? 8.0,
      adjustMode: prefs.getString(_adjustModeKey) ?? 'autoFit',
      directInputEnabled: prefs.getBool(_directInputEnabledKey) ?? false,
      showTerminalCursor: prefs.getBool(_showTerminalCursorKey) ?? true,
      invertPaneNavigation: prefs.getBool(_invertPaneNavKey) ?? false,
      showKeyOverlay: prefs.getBool(_showKeyOverlayKey) ?? true,
      keyOverlayModifier: prefs.getBool(_keyOverlayModifierKey) ?? true,
      keyOverlaySpecial: prefs.getBool(_keyOverlaySpecialKey) ?? true,
      keyOverlayArrow: prefs.getBool(_keyOverlayArrowKey) ?? true,
      keyOverlayShortcut: prefs.getBool(_keyOverlayShortcutKey) ?? true,
      keyOverlayPosition: prefs.getString(_keyOverlayPositionKey) ?? 'aboveKeyboard',
      imageRemotePath: prefs.getString(_imageRemotePathKey) ?? '/tmp/muxpod/',
      imageOutputFormat: prefs.getString(_imageOutputFormatKey) ?? 'original',
      imageJpegQuality: prefs.getInt(_imageJpegQualityKey) ?? 85,
      imageResizePreset: prefs.getString(_imageResizePresetKey) ?? 'original',
      imageMaxWidth: prefs.getInt(_imageMaxWidthKey) ?? 1920,
      imageMaxHeight: prefs.getInt(_imageMaxHeightKey) ?? 1080,
      imagePathFormat: prefs.getString(_imagePathFormatKey) ?? '{path}',
      imageAutoEnter: prefs.getBool(_imageAutoEnterKey) ?? false,
      imageBracketedPaste: prefs.getBool(_imageBracketedPasteKey) ?? false,
      fileViewers: _decodeFileViewers(prefs.getString(_fileViewersKey)),
      fileBrowserStartDir: prefs.getString(_fileBrowserStartDirKey) ??
          kFileBrowserStartClaudeCode,
      prefillCommandFromTerminal:
          prefs.getBool(_prefillCommandKey) ?? false,
      showHiddenFilesByDefault:
          prefs.getBool(_showHiddenFilesKey) ?? false,
    );
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  /// Set dark mode
  Future<void> setDarkMode(bool value) async {
    state = state.copyWith(darkMode: value);
    await _saveSetting(_darkModeKey, value);
  }

  /// Set font size
  Future<void> setFontSize(double value) async {
    state = state.copyWith(fontSize: value);
    await _saveSetting(_fontSizeKey, value);
  }

  /// Set font family
  Future<void> setFontFamily(String value) async {
    state = state.copyWith(fontFamily: value);
    await _saveSetting(_fontFamilyKey, value);
  }

  /// Set biometric authentication
  Future<void> setRequireBiometricAuth(bool value) async {
    state = state.copyWith(requireBiometricAuth: value);
    await _saveSetting(_biometricKey, value);
  }

  /// Set notifications
  Future<void> setEnableNotifications(bool value) async {
    state = state.copyWith(enableNotifications: value);
    await _saveSetting(_notificationsKey, value);
  }

  /// Set vibration
  Future<void> setEnableVibration(bool value) async {
    state = state.copyWith(enableVibration: value);
    await _saveSetting(_vibrationKey, value);
  }

  /// Set keep screen on
  Future<void> setKeepScreenOn(bool value) async {
    state = state.copyWith(keepScreenOn: value);
    await _saveSetting(_keepScreenOnKey, value);
  }

  /// Set scrollback line count
  Future<void> setScrollbackLines(int value) async {
    state = state.copyWith(scrollbackLines: value);
    await _saveSetting(_scrollbackKey, value);
  }

  /// Set minimum font size
  Future<void> setMinFontSize(double value) async {
    state = state.copyWith(minFontSize: value);
    await _saveSetting(_minFontSizeKey, value);
  }

  /// Set display adjustment mode
  Future<void> setAdjustMode(String value) async {
    state = state.copyWith(adjustMode: value);
    await _saveSetting(_adjustModeKey, value);
  }

  /// Set DirectInput mode
  Future<void> setDirectInputEnabled(bool value) async {
    state = state.copyWith(directInputEnabled: value);
    await _saveSetting(_directInputEnabledKey, value);
  }

  /// Toggle DirectInput mode
  Future<void> toggleDirectInput() async {
    await setDirectInputEnabled(!state.directInputEnabled);
  }

  /// Set terminal cursor display setting
  Future<void> setShowTerminalCursor(bool value) async {
    state = state.copyWith(showTerminalCursor: value);
    await _saveSetting(_showTerminalCursorKey, value);
  }

  /// Set pane navigation direction inversion
  Future<void> setInvertPaneNavigation(bool value) async {
    state = state.copyWith(invertPaneNavigation: value);
    await _saveSetting(_invertPaneNavKey, value);
  }

  // --- Key overlay settings setters ---
  Future<void> setShowKeyOverlay(bool value) async {
    state = state.copyWith(showKeyOverlay: value);
    await _saveSetting(_showKeyOverlayKey, value);
  }

  Future<void> setKeyOverlayModifier(bool value) async {
    state = state.copyWith(keyOverlayModifier: value);
    await _saveSetting(_keyOverlayModifierKey, value);
  }

  Future<void> setKeyOverlaySpecial(bool value) async {
    state = state.copyWith(keyOverlaySpecial: value);
    await _saveSetting(_keyOverlaySpecialKey, value);
  }

  Future<void> setKeyOverlayArrow(bool value) async {
    state = state.copyWith(keyOverlayArrow: value);
    await _saveSetting(_keyOverlayArrowKey, value);
  }

  Future<void> setKeyOverlayShortcut(bool value) async {
    state = state.copyWith(keyOverlayShortcut: value);
    await _saveSetting(_keyOverlayShortcutKey, value);
  }

  Future<void> setKeyOverlayPosition(String value) async {
    state = state.copyWith(keyOverlayPosition: value);
    await _saveSetting(_keyOverlayPositionKey, value);
  }

  // --- Image transfer settings setters ---
  Future<void> setImageRemotePath(String value) async {
    state = state.copyWith(imageRemotePath: value);
    await _saveSetting(_imageRemotePathKey, value);
  }

  Future<void> setImageOutputFormat(String value) async {
    state = state.copyWith(imageOutputFormat: value);
    await _saveSetting(_imageOutputFormatKey, value);
  }

  Future<void> setImageJpegQuality(int value) async {
    state = state.copyWith(imageJpegQuality: value);
    await _saveSetting(_imageJpegQualityKey, value);
  }

  Future<void> setImageResizePreset(String value) async {
    state = state.copyWith(imageResizePreset: value);
    await _saveSetting(_imageResizePresetKey, value);
  }

  Future<void> setImageMaxWidth(int value) async {
    state = state.copyWith(imageMaxWidth: value);
    await _saveSetting(_imageMaxWidthKey, value);
  }

  Future<void> setImageMaxHeight(int value) async {
    state = state.copyWith(imageMaxHeight: value);
    await _saveSetting(_imageMaxHeightKey, value);
  }

  Future<void> setImagePathFormat(String value) async {
    state = state.copyWith(imagePathFormat: value);
    await _saveSetting(_imagePathFormatKey, value);
  }

  Future<void> setImageAutoEnter(bool value) async {
    state = state.copyWith(imageAutoEnter: value);
    await _saveSetting(_imageAutoEnterKey, value);
  }

  Future<void> setImageBracketedPaste(bool value) async {
    state = state.copyWith(imageBracketedPaste: value);
    await _saveSetting(_imageBracketedPasteKey, value);
  }

  /// Replace the whole extension → viewer-type mapping (persisted as JSON).
  /// Keys are normalised to lower-case; entries with an unknown type are dropped.
  Future<void> setFileViewers(Map<String, String> value) async {
    final cleaned = <String, String>{};
    value.forEach((k, v) {
      final key = k.toLowerCase().trim();
      final type = FileViewerType.fromName(v);
      if (key.isNotEmpty && type != null) cleaned[key] = type.name;
    });
    state = state.copyWith(fileViewers: cleaned);
    await _saveSetting(_fileViewersKey, jsonEncode(cleaned));
  }

  /// Add or update a single mapping (`extension → viewer type`).
  Future<void> setFileViewer(String extension, FileViewerType type) async {
    final next = Map<String, String>.from(state.fileViewers);
    next[extension.toLowerCase().trim()] = type.name;
    await setFileViewers(next);
  }

  /// Remove the mapping for [extension].
  Future<void> removeFileViewer(String extension) async {
    final next = Map<String, String>.from(state.fileViewers)
      ..remove(extension.toLowerCase().trim());
    await setFileViewers(next);
  }

  /// Set where the file browser opens (`claudeCodeFolder` / `lastVisited`).
  Future<void> setFileBrowserStartDir(String value) async {
    final normalised = value == kFileBrowserStartLastVisited
        ? kFileBrowserStartLastVisited
        : kFileBrowserStartClaudeCode;
    state = state.copyWith(fileBrowserStartDir: normalised);
    await _saveSetting(_fileBrowserStartDirKey, normalised);
  }

  /// Toggle pre-filling the command popup from the terminal input line.
  Future<void> setPrefillCommandFromTerminal(bool value) async {
    state = state.copyWith(prefillCommandFromTerminal: value);
    await _saveSetting(_prefillCommandKey, value);
  }

  /// Toggle opening the file browser with hidden files visible by default.
  Future<void> setShowHiddenFilesByDefault(bool value) async {
    state = state.copyWith(showHiddenFilesByDefault: value);
    await _saveSetting(_showHiddenFilesKey, value);
  }

  /// Reload
  Future<void> reload() async {
    await _loadSettings();
  }
}

/// Settings provider
final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(() {
  return SettingsNotifier();
});

/// Dark mode provider (convenient access)
final darkModeProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).darkMode;
});
