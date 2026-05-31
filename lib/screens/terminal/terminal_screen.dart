import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../providers/active_session_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/ssh_provider.dart';
import '../../providers/tmux_provider.dart';
import '../../services/keychain/secure_storage.dart';
import '../../services/network/network_monitor.dart';
import '../../services/ssh/host_key_verifier.dart' show SshHostKeyChangedError;
import '../../services/ssh/input_queue.dart';
import '../../services/ssh/ssh_client.dart' show SshConnectOptions;
import '../../services/tmux/pane_navigator.dart';
import '../../services/terminal/font_calculator.dart';
import '../../services/terminal/input_line_extractor.dart';
import '../../services/tmux/tmux_commands.dart';
import '../../services/tmux/tmux_parser.dart';
import '../../services/tmux/tmux_version.dart';
import '../../widgets/dialogs/resize_dialog.dart';
import '../../theme/design_colors.dart';
import '../../services/terminal/tmux_key_display.dart';
import '../../widgets/key_overlay_widget.dart';
import '../../widgets/scroll_to_bottom_button.dart';
import '../../widgets/special_keys_bar.dart';
import '../../widgets/image_transfer_confirm_dialog.dart';
import '../../widgets/tmux_tiles.dart';
import '../../providers/terminal_display_provider.dart';
import '../../providers/image_transfer_provider.dart';
import '../file_browser/file_browser_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../settings/settings_screen.dart';
import 'widgets/ansi_text_view.dart';
import 'widgets/host_key_mismatch_dialog.dart';
import 'widgets/input_dialog_content.dart';
import 'widgets/new_window_dialog.dart';
import 'widgets/pane_layout_visualizer.dart';
import 'widgets/resize_pane_chooser_dialog.dart';
import 'widgets/resize_window_chooser_dialog.dart';
import '../../services/logging/app_log.dart';

part 'terminal_screen_logic.dart';
part 'terminal_screen_view.dart';

/// Source of scroll mode
enum ScrollModeSource {
  /// Normal mode (not scroll mode)
  none,

  /// User manually enabled from UI
  manual,

  /// Auto-detected tmux copy-mode
  tmux,
}

/// Terminal display data frequently updated via polling
///
/// Managed with ValueNotifier to avoid parent widget setstate().
/// This prevents parent rebuild while BottomSheet is displayed,
/// ensuring stable operation even with isDismissible: true.
class _TerminalViewData {
  final String content;
  final int latency;
  final int paneWidth;
  final int paneHeight;

  const _TerminalViewData({
    this.content = '',
    this.latency = 0,
    this.paneWidth = 80,
    this.paneHeight = 24,
  });

  _TerminalViewData copyWith({
    String? content,
    int? latency,
    int? paneWidth,
    int? paneHeight,
  }) =>
      _TerminalViewData(
        content: content ?? this.content,
        latency: latency ?? this.latency,
        paneWidth: paneWidth ?? this.paneWidth,
        paneHeight: paneHeight ?? this.paneHeight,
      );
}

/// Terminal screen (complies with HTML design specification)
class TerminalScreen extends ConsumerStatefulWidget {
  final String connectionId;
  final String? sessionName;

  /// Restoration: last opened window index
  final int? lastWindowIndex;

  /// Restoration: last opened pane ID
  final String? lastPaneId;

  /// Deep link: specify by window name (search by name, not index)
  final String? deepLinkWindowName;

  /// Deep link: pane index
  final int? deepLinkPaneIndex;

  const TerminalScreen({
    super.key,
    required this.connectionId,
    this.sessionName,
    this.lastWindowIndex,
    this.lastPaneId,
    this.deepLinkWindowName,
    this.deepLinkPaneIndex,
  });

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen>
    with WidgetsBindingObserver, _TerminalScreenLogic, _TerminalScreenView {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Show scroll button on scroll
    _terminalScrollController.addListener(_onTerminalScroll);

    // Set up listeners in next frame (for ref usage)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _setupListeners();
      _connectAndSetup();
      _applyKeepScreenOn();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _pausePolling();
        break;
      case AppLifecycleState.resumed:
        _resumePolling();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final settings = ref.read(settingsProvider);
    if (!settings.isAutoResize) return;

    // Debounce: suppress continuous size changes from screen rotation/folding
    _autoResizeDebounceTimer?.cancel();
    _autoResizeDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || _isDisposed) return;
      final activePane = ref.read(tmuxProvider).activePane;
      if (activePane != null) {
        _executeAutoResize(activePane);
      }
    });
  }

  @override
  @override
  void deactivate() {
    // ref.read is safe until deactivate (at dispose, already removed from _elements)
    final sshNotifier = ref.read(sshProvider.notifier);
    sshNotifier.onReconnectSuccess = null;
    sshNotifier.onDisconnectDetected = null;

    // Disconnect SSH even if popped without _disconnect() via popUntil etc
    if (sshNotifier.checkConnection()) {
      sshNotifier.disconnect();
    }
    super.deactivate();
  }

  @override
  void dispose() {
    // First set _isDisposed to stop async processing
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    // Disable WakeLock
    WakelockPlus.disable();
    // Cancel Riverpod subscriptions
    _sshSubscription?.close();
    _sshSubscription = null;
    _tmuxSubscription?.close();
    _tmuxSubscription = null;
    _settingsSubscription?.close();
    _settingsSubscription = null;
    _networkSubscription?.close();
    _networkSubscription = null;
    _imageTransferSub?.close();
    _imageTransferSub = null;
    // Stop timers
    _pollTimer?.cancel();
    _pollTimer = null;
    _treeRefreshTimer?.cancel();
    _treeRefreshTimer = null;
    // Key overlay
    _keyOverlayTimer?.cancel();
    _keyOverlayTimer = null;
    _keyOverlayState.dispose();
    _autoResizeDebounceTimer?.cancel();
    _autoResizeDebounceTimer = null;
    // Dispose ValueNotifier
    _viewNotifier.dispose();
    // Remove listener and dispose scroll controller
    _terminalScrollController.removeListener(_onTerminalScroll);
    _terminalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use local state (do not use ref.watch)
    // Note: tmuxProvider is obtained via ref.watch in each Consumer
    // This prevents parent build() from being called during polling, stabilizing BottomSheet
    final sshState = _sshState;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              // Breadcrumb: directly watch tmuxProvider in Consumer (parent rebuild not needed)
              Consumer(
                builder: (context, ref, _) {
                  final tmuxState = ref.watch(tmuxProvider);
                  return _buildBreadcrumbHeader(tmuxState);
                },
              ),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _terminalMode == TerminalMode.scroll
                          ? DesignColors.warning
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Terminal display: ValueListenableBuilder + Consumer
                      // Polling updates rebuild only this subtree via ValueNotifier
                      RepaintBoundary(
                        child: ValueListenableBuilder<_TerminalViewData>(
                          valueListenable: _viewNotifier,
                          builder: (context, viewData, _) {
                            return Consumer(
                              builder: (context, ref, _) {
                                final cursor = ref.watch(tmuxProvider.select((s) => (
                                  x: s.activePane?.cursorX ?? 0,
                                  y: s.activePane?.cursorY ?? 0,
                                )));
                                return AnsiTextView(
                                  key: _ansiTextViewKey,
                                  text: viewData.content,
                                  paneWidth: viewData.paneWidth,
                                  paneHeight: viewData.paneHeight,
                                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                                  foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                                  onKeyInput: _handleKeyInput,
                                  onTap: () {
                                    _scrollToBottomKey.currentState?.show();
                                  },
                                  mode: _terminalMode,
                                  zoomEnabled: true,
                                  onZoomChanged: (scale) {
                                    setState(() {
                                      _zoomScale = scale;
                                    });
                                  },
                                  verticalScrollController: _terminalScrollController,
                                  cursorX: cursor.x,
                                  cursorY: cursor.y,
                                  onArrowSwipe: _sendSpecialKeyWithOverlay,
                                  onTwoFingerSwipe: _handleTwoFingerSwipe,
                                  navigableDirections: _getNavigableDirections(),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      // Pane indicator: directly watch tmuxProvider in Consumer
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Consumer(
                          builder: (context, ref, _) {
                            final tmuxState = ref.watch(tmuxProvider);
                            return _buildPaneIndicator(tmuxState);
                          },
                        ),
                      ),
                      // Scroll button: bottom right of terminal area
                      Positioned(
                        bottom: 8,
                        right: 16,
                        child: ScrollToBottomButton(
                          key: _scrollToBottomKey,
                          onPressed: () {
                            _ansiTextViewKey.currentState?.scrollToBottom();
                          },
                        ),
                      ),
                      // Key overlay
                      KeyOverlayWidget(
                        overlayState: _keyOverlayState,
                        position: _keyOverlayPosition,
                      ),
                    ],
                  ),
                ),
              ),
              // Image upload progress bar
              Consumer(
                builder: (context, ref, _) {
                  final transfer = ref.watch(imageTransferProvider);
                  final isActive = transfer.phase == ImageTransferPhase.uploading ||
                      transfer.phase == ImageTransferPhase.converting;
                  if (!isActive) return const SizedBox.shrink();
                  return LinearProgressIndicator(
                    value: transfer.uploadProgress > 0 ? transfer.uploadProgress : null,
                    minHeight: 3,
                    backgroundColor: Colors.transparent,
                  );
                },
              ),
              SpecialKeysBar(
                onKeyPressed: _sendKeyWithOverlay,
                onSpecialKeyPressed: _sendSpecialKeyWithOverlay,
                onInputTap: _showInputDialog,
                directInputEnabled: _directInputEnabled,
                onDirectInputToggle: () {
                  ref.read(settingsProvider.notifier).toggleDirectInput();
                },
                onImagePickRequested: _handleImageTransfer,
              ),
            ],
          ),
          // Loading overlay
          if (_isConnecting || sshState.isConnecting)
            Container(
              color: isDark ? Colors.black54 : Colors.white70,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          // Error overlay
          if (_connectionError != null || sshState.hasError)
            _buildErrorOverlay(sshState.error ?? _connectionError),
        ],
      ),
    );
  }

  // --- Key overlay wrapper ---

  KeyOverlayPosition get _keyOverlayPosition {
    final pos = ref.read(settingsProvider).keyOverlayPosition;
    return switch (pos) {
      'center' => KeyOverlayPosition.center,
      'belowHeader' => KeyOverlayPosition.belowHeader,
      _ => KeyOverlayPosition.aboveKeyboard,
    };
  }

}
