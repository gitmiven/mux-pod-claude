part of 'terminal_screen.dart';

mixin _TerminalScreenLogic on ConsumerState<TerminalScreen> {
  final _secureStorage = SecureStorageService();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _ansiTextViewKey = GlobalKey<AnsiTextViewState>();
  final _scrollToBottomKey = GlobalKey<ScrollToBottomButtonState>();
  final _terminalScrollController = ScrollController();

  // Connection state (managed locally)
  bool _isConnecting = false;
  String? _connectionError;
  SshState _sshState = const SshState();

  // Terminal display data frequently updated via polling (managed with ValueNotifier)
  // Avoid parent setstate() and rebuild only subtree with ValueListenableBuilder
  final _viewNotifier = ValueNotifier<_TerminalViewData>(const _TerminalViewData());

  // Key overlay
  final KeyOverlayState _keyOverlayState = KeyOverlayState();
  Timer? _keyOverlayTimer;

  // Polling timer
  Timer? _pollTimer;
  Timer? _treeRefreshTimer;
  bool _isPolling = false;
  bool _isDisposed = false;

  // Frame skipping (optimization for high-frequency updates)
  static const _minFrameInterval = Duration(milliseconds: 16); // ~60fps
  DateTime _lastFrameTime = DateTime.now();
  bool _pendingUpdate = false;
  String _pendingContent = '';
  int _pendingLatency = 0;

  // Adaptive polling
  int _currentPollingInterval = 100;
  static const int _minPollingInterval = 50;
  static const int _maxPollingInterval = 2000;

  // Selection state preservation (suppress updates during scroll mode)
  String _bufferedContent = '';
  int _bufferedLatency = 0;
  bool _hasBufferedUpdate = false;

  // Initial scroll completion flag
  bool _hasInitialScrolled = false;

  // Terminal mode
  TerminalMode _terminalMode = TerminalMode.normal;

  // Scroll mode source (none / manual / tmux)
  ScrollModeSource _scrollModeSource = ScrollModeSource.none;

  // Zoom scale
  double _zoomScale = 1.0;

  // EnterCommand input content preservation (retained even when bottom sheet is closed)
  String _savedCommandInput = '';

  // Input queue (preserve input during disconnection)
  final _inputQueue = InputQueue();

  // Background state
  bool _isInBackground = false;

  // Local cache of directInput setting (avoid ref.watch)
  bool _directInputEnabled = true;

  // Window creation flag (prevent rapid tapping)
  bool _isCreatingWindow = false;

  // Resizing flag (mutual exclusion control)
  bool _isResizing = false;

  // Auto-resize debounce timer (on screen size change)
  Timer? _autoResizeDebounceTimer;

  // tmux version information (for resize feature determination)
  TmuxVersionInfo? _tmuxVersion;

  // Riverpod listeners
  ProviderSubscription<SshState>? _sshSubscription;
  ProviderSubscription<TmuxState>? _tmuxSubscription;
  ProviderSubscription<AppSettings>? _settingsSubscription;
  ProviderSubscription<AsyncValue<NetworkStatus>>? _networkSubscription;

  /// Stop polling when moving to background
  void _pausePolling() {
    _isInBackground = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    _treeRefreshTimer?.cancel();
    _treeRefreshTimer = null;
    WakelockPlus.disable();
  }

  /// Resume polling when returning to foreground
  void _resumePolling() {
    if (!_isInBackground || _isDisposed) return;
    _isInBackground = false;
    _startPolling();
    _startTreeRefresh();
    _applyKeepScreenOn();
  }

  /// Apply keep screen on setting
  void _applyKeepScreenOn() {
    final settings = ref.read(settingsProvider);
    if (settings.keepScreenOn) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  /// Set up provider listeners
  void _setupListeners() {
    // Monitor SSH state changes
    _sshSubscription = ref.listenManual<SshState>(
      sshProvider,
      (previous, next) {
        if (!mounted || _isDisposed) return;
        // Display warning dialog when host key mismatch is detected (FR-004, includes reconnect/deep link).
        if (next.hostKeyChange != null &&
            previous?.hostKeyChange != next.hostKeyChange) {
          _handleHostKeyChange(next.hostKeyChange!);
        }
        setState(() {
          _sshState = next;
        });
      },
      fireImmediately: true,
    );

    // Monitor tmux state changes
    // Note: parent setstate() is not needed. Breadcrumb and pane indicators
    // directly watch tmuxProvider in Consumer widget, so only subtree rebuilds.
    _tmuxSubscription = ref.listenManual<TmuxState>(
      tmuxProvider,
      (previous, next) {
        // Consumer widgets directly watch tmuxProvider,
        // so parent setstate() is not needed (removed for BottomSheet stability)
      },
      fireImmediately: true,
    );

    // Monitor settings changes (for keep screen on / directInput)
    _settingsSubscription = ref.listenManual<AppSettings>(
      settingsProvider,
      (previous, next) {
        if (!mounted || _isDisposed) return;
        if (previous?.keepScreenOn != next.keepScreenOn) {
          _applyKeepScreenOn();
        }
        if (previous?.directInputEnabled != next.directInputEnabled) {
          setState(() {
            _directInputEnabled = next.directInputEnabled;
          });
        }
      },
      fireImmediately: false,
    );

    // Explicitly set initial value
    _directInputEnabled = ref.read(settingsProvider).directInputEnabled;

    // Monitor network state changes (update only when actual connection state changes)
    _networkSubscription = ref.listenManual<AsyncValue<NetworkStatus>>(
      networkStatusProvider,
      (previous, next) {
        if (!mounted || _isDisposed) return;
        final prevStatus = previous?.value;
        final nextStatus = next.value;
        if (prevStatus != nextStatus) {
          setState(() {});
        }
      },
      fireImmediately: true,
    );

    // Set up handler for successful reconnection
    final sshNotifier = ref.read(sshProvider.notifier);
    sshNotifier.onReconnectSuccess = _onReconnectSuccess;
  }

  /// Handler for successful reconnection
  Future<void> _onReconnectSuccess() async {
    if (!mounted || _isDisposed) return;

    // Reset polling flag
    _isPolling = false;

    // Resume polling
    _startPolling();

    // Re-fetch session tree
    _startTreeRefresh();

    // Flush queued input
    await _flushInputQueue();

    // Update UI
    if (mounted) setState(() {});
  }

  /// Flush queued input
  Future<void> _flushInputQueue() async {
    if (_inputQueue.isEmpty) return;

    final queuedInput = _inputQueue.flush();
    if (queuedInput.isNotEmpty) {
      await _sendKeyData(queuedInput);
    }
  }

  /// Flag to prevent duplicate host key mismatch dialog display
  bool _hostKeyDialogOpen = false;

  /// Handle when host key mismatch is detected (FR-004/005).
  ///
  /// Display warning dialog. If user chooses to re-trust, set re-trust flag and
  /// re-run connection flow. If user cancels, clear warning and exit connection screen.
  Future<void> _handleHostKeyChange(SshHostKeyChangedError change) async {
    if (_hostKeyDialogOpen || !mounted || _isDisposed) return;
    _hostKeyDialogOpen = true;
    try {
      final reTrust = await HostKeyMismatchDialog.show(context, change);
      if (!mounted || _isDisposed) return;
      final sshNotifier = ref.read(sshProvider.notifier);
      if (reTrust == true) {
        // Explicitly re-trust → re-run full connection flow (supports both initial connect and auto-reconnect).
        sshNotifier.retrustNextConnect();
        await _connectAndSetup();
      } else {
        // Cancel: clear warning and exit connection screen.
        sshNotifier.clearHostKeyChange();
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      }
    } finally {
      _hostKeyDialogOpen = false;
    }
  }

  /// Connect via SSH and set up tmux session
  Future<void> _connectAndSetup() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isConnecting = true;
      _connectionError = null;
    });

    try {
      // 1. Get connection info
      final connection = ref.read(connectionsProvider.notifier).getById(widget.connectionId);
      if (connection == null) {
        throw Exception('Connection not found');
      }

      // 2. Get authentication options
      final options = await _getAuthOptions(connection);
      if (!mounted || _isDisposed) {
        return;
      }

      // 3. SSH connection (do not start shell - use exec only)
      final sshNotifier = ref.read(sshProvider.notifier);
      await sshNotifier.connectWithoutShell(connection, options);
      if (!mounted || _isDisposed) {
        return;
      }
      // If host key mismatch detected, abort setup (dialog displayed by listener - FR-004).
      if (ref.read(sshProvider).hostKeyChange != null) {
        setState(() => _isConnecting = false);
        return;
      }

      // 3.5. Get tmux version (for resize feature determination)
      try {
        final versionOutput = await sshNotifier.client?.exec(TmuxCommands.version());
        if (versionOutput != null) {
          _tmuxVersion = TmuxVersionInfo.parse(versionOutput);
        }
      } catch (_) {
        _tmuxVersion = null;
      }

      // 4. Fetch entire session tree
      await _refreshSessionTree();
      if (!mounted || _isDisposed) {
        return;
      }

      final tmuxState = ref.read(tmuxProvider);
      final sessions = tmuxState.sessions;

      // 5. Select or create session
      String sessionName;
      if (widget.sessionName != null) {
        // Session name is specified
        final existingIndex = sessions.indexWhere(
          (s) => s.name == widget.sessionName,
        );
        if (existingIndex >= 0) {
          // Connect to existing session
          sessionName = sessions[existingIndex].name;
        } else {
          // Create new session
          final sshClient = ref.read(sshProvider.notifier).client;
          await sshClient?.exec(TmuxCommands.newSession(
            name: widget.sessionName!,
            detached: true,
          ));
          if (!mounted || _isDisposed) return;
          await _refreshSessionTree();
          if (!mounted || _isDisposed) return;
          sessionName = widget.sessionName!;
        }
      } else if (sessions.isNotEmpty) {
        // If no session name specified, connect to first session
        sessionName = sessions.first.name;
      } else {
        // If no sessions exist, create new one with auto-generated name
        final sshClient = ref.read(sshProvider.notifier).client;
        sessionName = 'muxpod-${DateTime.now().millisecondsSinceEpoch}';
        await sshClient?.exec(TmuxCommands.newSession(name: sessionName, detached: true));
        if (!mounted || _isDisposed) return;
        await _refreshSessionTree();
        if (!mounted || _isDisposed) return;
      }

      // 6. Set active session/window/pane
      ref.read(tmuxProvider.notifier).setActiveSession(sessionName);

      // 6.1 Restore deep link or saved window/pane position
      if (widget.deepLinkWindowName != null) {
        // Deep link: search by window name
        final tmuxState = ref.read(tmuxProvider);
        final session = tmuxState.activeSession;
        if (session != null) {
          final targetName = widget.deepLinkWindowName!;
          // Search by window name (also handles "index:name" format names)
          TmuxWindow? window;
          for (final w in session.windows) {
            if (w.name == targetName || w.name.endsWith(':$targetName')) {
              window = w;
              break;
            }
          }
          if (window != null) {
            ref.read(tmuxProvider.notifier).setActiveWindow(window.index);

            // If pane index is specified
            if (widget.deepLinkPaneIndex != null && widget.deepLinkPaneIndex! < window.panes.length) {
              final pane = window.panes[widget.deepLinkPaneIndex!];
              ref.read(tmuxProvider.notifier).setActivePane(pane.id);
            }
          }
        }
      } else if (widget.lastWindowIndex != null) {
        // Normal restoration: search by index
        final tmuxState = ref.read(tmuxProvider);
        final session = tmuxState.activeSession;
        if (session != null) {
          // Check if specified window exists
          final window = session.windows.firstWhere(
            (w) => w.index == widget.lastWindowIndex,
            orElse: () => session.windows.first,
          );
          ref.read(tmuxProvider.notifier).setActiveWindow(window.index);

          // Restore if pane ID is specified and exists
          if (widget.lastPaneId != null) {
            final pane = window.panes.firstWhere(
              (p) => p.id == widget.lastPaneId,
              orElse: () => window.panes.first,
            );
            ref.read(tmuxProvider.notifier).setActivePane(pane.id);
          }
        }
      }

      // 7. Notify TerminalDisplayProvider of pane info (for font size calculation)
      final activePane = ref.read(tmuxProvider).activePane;
      if (activePane != null) {
        AppLog.d('[Terminal] Pane size: ${activePane.width}x${activePane.height}');
        ref.read(terminalDisplayProvider.notifier).updatePane(activePane);
        _viewNotifier.value = _viewNotifier.value.copyWith(
          paneWidth: activePane.width,
          paneHeight: activePane.height,
        );

        // Send focus-in to pane (so apps like Claude Code can detect focus)
        await sshNotifier.client?.exec(TmuxCommands.sendKeys(activePane.id, '\x1b[I', literal: true));
      }

      // 8. Start 100ms polling
      _startPolling();

      // 9. Update session tree every 5 seconds
      _startTreeRefresh();

      if (!mounted) return;
      setState(() {
        _isConnecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _connectionError = e.toString();
      });
      _showErrorSnackBar(e.toString());
    }
  }

  /// Fetch and update entire session tree
  Future<void> _refreshSessionTree() async {
    if (_isDisposed) {
      return;
    }
    final sshClient = ref.read(sshProvider.notifier).client;
    if (sshClient == null || !sshClient.isConnected) {
      return;
    }

    try {
      final cmd = TmuxCommands.listAllPanes();
      final output = await sshClient.exec(cmd);
      if (!mounted || _isDisposed) return;
      ref.read(tmuxProvider.notifier).parseAndUpdateFullTree(output);
    } catch (_) {
      // Silently ignore tree update errors (retry on next poll)
    }
  }

  /// Update session tree every 10 seconds
  void _startTreeRefresh() {
    _treeRefreshTimer?.cancel();
    _treeRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        // Skip to avoid SSH conflicts during polling
        if (!_isPolling) {
          _refreshSessionTree();
        }
      },
    );
  }

  /// Execute capture-pane via adaptive polling to update terminal content
  ///
  /// Dynamically adjust polling interval based on content change frequency:
  /// - High-frequency updates (htop etc): 50ms
  /// - Normal: 100ms
  /// - Idle: 500ms
  void _startPolling() {
    _pollTimer?.cancel();
    _scheduleNextPoll();
  }

  /// Schedule next polling
  void _scheduleNextPoll() {
    if (_isDisposed) return;
    _pollTimer?.cancel();
    _pollTimer = Timer(
      Duration(milliseconds: _currentPollingInterval),
      () async {
        await _pollPaneContent();
        _scheduleNextPoll();
      },
    );
  }

  /// Boost polling immediately after key input (improve responsiveness during idle)
  void _boostPolling() {
    _currentPollingInterval = _minPollingInterval;
    _pollTimer?.cancel();
    _scheduleNextPoll();
  }

  /// Update polling interval
  void _updatePollingInterval() {
    final ansiTextViewState = _ansiTextViewKey.currentState;
    if (ansiTextViewState != null) {
      final recommended = ansiTextViewState.recommendedPollingInterval;
      // Limit polling interval upper bound to 500ms while detecting tmux copy-mode
      // Improve copy-mode termination detection delay to max 0.5 seconds
      final maxInterval = _scrollModeSource == ScrollModeSource.tmux ? 500 : _maxPollingInterval;
      _currentPollingInterval = recommended.clamp(
        _minPollingInterval,
        maxInterval,
      );
    }
  }

  /// Fetch pane content via polling
  Future<void> _pollPaneContent() async {
    if (_isPolling || _isDisposed) return; // Previous polling still running or disposed
    _isPolling = true;

    try {
      final sshNotifier = ref.read(sshProvider.notifier);
      final sshClient = sshNotifier.client;

      // Attempt auto-reconnect if connection is lost
      if (sshClient == null || !sshClient.isConnected) {
        // Start reconnect if not already reconnecting
        final currentState = ref.read(sshProvider);
        if (!currentState.isReconnecting) {
          _attemptReconnect();
        }
        _isPolling = false;
        return;
      }

      // Get target from tmux_provider
      final target = ref.read(tmuxProvider.notifier).currentTarget;
      if (target == null) {
        _isPolling = false;
        return;
      }

      final startTime = DateTime.now();

      // Combine 3 commands into 1 (persistent shell executes 1 command at a time)
      // Get capture-pane + cursor position + pane mode in 1 call
      // Output format: [pane content]\n[cursor info]\n[pane mode]
      final combinedCommand =
          '${TmuxCommands.capturePane(target, escapeSequences: true, startLine: -1000)}; '
          '${TmuxCommands.getCursorPosition(target)}; '
          '${TmuxCommands.getPaneMode(target)}';

      final combinedOutput = await sshClient.execPersistent(
        combinedCommand,
        timeout: const Duration(seconds: 2),
      );

      // Split output (last line is pane mode, before that is cursor info)
      final lines = combinedOutput.split('\n');
      final paneModeOutput = lines.isNotEmpty ? lines.removeLast() : '';
      final cursorOutput = lines.isNotEmpty ? lines.removeLast() : '';
      final output = lines.join('\n');

      // Remove trailing newline from capture-pane output
      final processedOutput = output.endsWith('\n')
          ? output.substring(0, output.length - 1)
          : output;

      final endTime = DateTime.now();

      // Skip if already unmounted
      if (!mounted || _isDisposed) return;

      // Update cursor position and pane size
      if (cursorOutput.isNotEmpty) {
        final parts = cursorOutput.trim().split(',');
        if (parts.length >= 4) {
          final x = int.tryParse(parts[0]);
          final y = int.tryParse(parts[1]);
          final w = int.tryParse(parts[2]);
          final h = int.tryParse(parts[3]);

          // Detect pane size update
          if (w != null && h != null && (w != _viewNotifier.value.paneWidth || h != _viewNotifier.value.paneHeight)) {
            _viewNotifier.value = _viewNotifier.value.copyWith(paneWidth: w, paneHeight: h);
            // Notify for font size recalculation
            final currentActivePane = ref.read(tmuxProvider).activePane;
            if (currentActivePane != null) {
              ref.read(terminalDisplayProvider.notifier).updatePane(
                    currentActivePane.copyWith(width: w, height: h),
                  );
            }
          }

          final activePaneId = ref.read(tmuxProvider).activePaneId;
          if (activePaneId != null && x != null && y != null) {
            ref.read(tmuxProvider.notifier).updateCursorPosition(activePaneId, x, y);
          }
        }
      }

      // Update latency
      final latency = endTime.difference(startTime).inMilliseconds;

      // Update if there is difference (throttling applied)
      final currentView = _viewNotifier.value;
      if (processedOutput != currentView.content || latency != currentView.latency) {
        // Buffer updates only during manual scroll mode to preserve selection state
        // During tmux copy-mode, capture-pane returns content at scroll position, so display real-time
        if (_terminalMode == TerminalMode.scroll && _scrollModeSource == ScrollModeSource.manual) {
          _bufferedContent = processedOutput;
          _bufferedLatency = latency;
          _hasBufferedUpdate = true;
          // Update latency only (does not affect selection)
          if (mounted && !_isDisposed) {
            _viewNotifier.value = currentView.copyWith(latency: latency);
          }
        } else {
          _scheduleUpdate(processedOutput, latency);
        }
      }

      // Auto-switch mode based on tmux copy-mode detection
      if (mounted && !_isDisposed) {
        final paneMode = paneModeOutput.trim();
        final isTmuxCopyMode = paneMode.isNotEmpty;

        if (isTmuxCopyMode && _scrollModeSource == ScrollModeSource.none) {
          // Entered tmux copy-mode → auto-switch to scroll mode
          setState(() {
            _terminalMode = TerminalMode.scroll;
            _scrollModeSource = ScrollModeSource.tmux;
          });
        } else if (!isTmuxCopyMode && _scrollModeSource == ScrollModeSource.tmux) {
          // Exited tmux copy-mode → auto-return to normal mode
          setState(() {
            _terminalMode = TerminalMode.normal;
            _scrollModeSource = ScrollModeSource.none;
          });
          _applyBufferedUpdate();
        }
      }

      // Update adaptive polling interval
      _updatePollingInterval();
    } catch (e) {
      // Attempt auto-reconnect on communication error
      if (!_isDisposed) {
        final currentState = ref.read(sshProvider);
        if (!currentState.isReconnecting) {
          _attemptReconnect();
        }
      }
    } finally {
      _isPolling = false;
    }
  }

  /// Apply buffered updates (called when exiting scroll mode)
  void _applyBufferedUpdate() {
    if (_hasBufferedUpdate) {
      _scheduleUpdate(_bufferedContent, _bufferedLatency);
      _hasBufferedUpdate = false;
      _bufferedContent = '';
      _bufferedLatency = 0;
    }
  }

  /// Schedule update considering frame skipping
  ///
  /// Perform throttling to avoid updating every frame during high-frequency updates (htop etc).
  /// Consecutive updates within 16ms (~60fps) are deferred to next frame.
  void _scheduleUpdate(String content, int latency) {
    _pendingContent = content;
    _pendingLatency = latency;

    // Do nothing if update is already scheduled
    if (_pendingUpdate) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastFrameTime);

    if (elapsed >= _minFrameInterval) {
      // Enough time has elapsed, update immediately
      _applyUpdate();
    } else {
      // Frame skip: update in next frame
      _pendingUpdate = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isDisposed) return;
        _pendingUpdate = false;
        _applyUpdate();
      });
    }
  }

  /// Apply pending updates
  void _applyUpdate() {
    if (!mounted || _isDisposed) return;
    _lastFrameTime = DateTime.now();
    // ValueNotifier update (avoid parent setstate(), only rebuild ValueListenableBuilder)
    _viewNotifier.value = _viewNotifier.value.copyWith(
      content: _pendingContent,
      latency: _pendingLatency,
    );

    // Scroll to bottom on first content received
    if (!_hasInitialScrolled && _pendingContent.isNotEmpty) {
      _hasInitialScrolled = true;
      _scrollToCaret();
    }
  }

  /// Attempt auto-reconnect
  Future<void> _attemptReconnect() async {
    if (_isDisposed) return;

    final sshNotifier = ref.read(sshProvider.notifier);
    final success = await sshNotifier.reconnect();

    if (!mounted || _isDisposed) return;

    if (!success) {
      // Retry on reconnect failure (until max retries reached)
      final currentState = ref.read(sshProvider);
      if (currentState.reconnectAttempt < 5) {
        // Will be retried on next poll
      }
    }
  }

  /// Get authentication options
  Future<SshConnectOptions> _getAuthOptions(Connection connection) async {
    if (connection.authMethod == 'key' && connection.keyId != null) {
      final privateKey = await _secureStorage.getPrivateKey(connection.keyId!);
      final passphrase = await _secureStorage.getPassphrase(connection.keyId!);
      return SshConnectOptions(privateKey: privateKey, passphrase: passphrase);
    } else {
      final password = await _secureStorage.getPassword(connection.id);
      return SshConnectOptions(password: password);
    }
  }

  /// Display error SnackBar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _connectAndSetup,
        ),
      ),
    );
  }

  /// Show scroll button on scroll
  void _onTerminalScroll() {
    _scrollToBottomKey.currentState?.show();
  }

  /// Send special key + display overlay
  void _sendSpecialKeyWithOverlay(String tmuxKey) {
    _sendSpecialKey(tmuxKey);
    _showKeyOverlay(tmuxKey);
  }

  /// Send literal key + display shortcut key overlay
  void _sendKeyWithOverlay(String key) {
    _sendKey(key);
    if (TmuxKeyDisplay.isShortcutKey(key)) {
      _showKeyOverlay(key);
    }
  }

  /// Overlay display logic
  void _showKeyOverlay(String key) {
    final settings = ref.read(settingsProvider);
    if (!settings.showKeyOverlay) return;

    final category = TmuxKeyDisplay.categoryOf(key);
    if (category == null) return;

    final enabled = switch (category) {
      KeyOverlayCategory.modifier => settings.keyOverlayModifier,
      KeyOverlayCategory.special => settings.keyOverlaySpecial,
      KeyOverlayCategory.arrow => settings.keyOverlayArrow,
      KeyOverlayCategory.shortcut => settings.keyOverlayShortcut,
    };
    if (!enabled) return;

    _keyOverlayState.show(TmuxKeyDisplay.displayText(key));
    _keyOverlayTimer?.cancel();
    _keyOverlayTimer = Timer(const Duration(milliseconds: 1500), () {
      _keyOverlayState.hide();
    });
  }

  /// Handle key input from AnsiTextView
  void _handleKeyInput(KeyInputEvent event) {
    // For special keys, send in tmux format (with overlay)
    if (event.isSpecialKey && event.tmuxKeyName != null) {
      _sendSpecialKeyWithOverlay(event.tmuxKeyName!);
    } else {
      // Regular characters sent as literals
      _sendKeyData(event.data);
    }
  }

  /// Pane switching via two-finger swipe
  void _handleTwoFingerSwipe(SwipeDirection direction) {
    final tmuxState = ref.read(tmuxProvider);
    final window = tmuxState.activeWindow;
    final activePane = tmuxState.activePane;
    if (window == null || activePane == null) return;

    // Invert swipe direction based on settings
    final settings = ref.read(settingsProvider);
    final actualDirection = settings.invertPaneNavigation
        ? direction.inverted
        : direction;

    final targetPane = PaneNavigator.findAdjacentPane(
      panes: window.panes,
      current: activePane,
      direction: actualDirection,
    );

    if (targetPane != null) {
      _selectPane(targetPane.id);
    }
  }

  /// Get navigable directions from current pane
  Map<SwipeDirection, bool>? _getNavigableDirections() {
    final tmuxState = ref.read(tmuxProvider);
    final window = tmuxState.activeWindow;
    final activePane = tmuxState.activePane;
    if (window == null || activePane == null) return null;

    final rawDirections = PaneNavigator.getNavigableDirections(
      panes: window.panes,
      current: activePane,
    );

    // If inversion setting is enabled, swap direction keys
    final settings = ref.read(settingsProvider);
    if (settings.invertPaneNavigation) {
      return {
        for (final dir in SwipeDirection.values)
          dir: rawDirections[dir.inverted] ?? false,
      };
    }

    return rawDirections;
  }

  /// Send key data via tmux send-keys
  Future<void> _sendKeyData(String data) async {
    final sshClient = ref.read(sshProvider.notifier).client;

    // Add to queue if connection is lost
    if (sshClient == null || !sshClient.isConnected) {
      final wasOverflow = _inputQueue.isOverflow;
      _inputQueue.enqueue(data);
      if (!wasOverflow && _inputQueue.isOverflow && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Input queue is full; some keystrokes may be lost.'),
          ),
        );
      }
      if (mounted) setState(() {}); // Update queuing state
      return;
    }

    final target = ref.read(tmuxProvider.notifier).currentTarget;
    if (target == null) return;

    try {
      // Send escape sequences and special keys as literals
      await sshClient.exec(TmuxCommands.sendKeys(target, data, literal: true));
      _boostPolling();
    } catch (_) {
      // Silently ignore key send errors
    }
  }

  /// Select session
  Future<void> _selectSession(String sessionName) async {
    final sshClient = ref.read(sshProvider.notifier).client;
    if (sshClient == null) return;

    // Update active session in tmux_provider
    ref.read(tmuxProvider.notifier).setActiveSession(sessionName);

    // Set active pane as selected state (execute select-pane command)
    final activePaneId = ref.read(tmuxProvider).activePaneId;
    if (activePaneId != null) {
      await _selectPane(activePaneId);
    } else {
      // Clear and re-fetch terminal content
      _viewNotifier.value = _viewNotifier.value.copyWith(content: '');
      _hasInitialScrolled = false;
    }
  }

  /// Select window
  Future<void> _selectWindow(String sessionName, int windowIndex) async {
    final sshClient = ref.read(sshProvider.notifier).client;
    if (sshClient == null || !sshClient.isConnected) return;

    // Also switch session if different
    final currentSession = ref.read(tmuxProvider).activeSessionName;
    if (currentSession != sessionName) {
      ref.read(tmuxProvider.notifier).setActiveSession(sessionName);
    }

    try {
      // Execute tmux select-window
      await sshClient.exec(TmuxCommands.selectWindow(sessionName, windowIndex));
    } catch (e) {
      // Ignore if SSH connection is closed
      AppLog.d('[Terminal] Failed to select window: $e');
      return;
    }
    if (!mounted || _isDisposed) return;

    // Update active window in tmux_provider
    ref.read(tmuxProvider.notifier).setActiveWindow(windowIndex);

    // Set active pane as selected state (execute select-pane command)
    final activePaneId = ref.read(tmuxProvider).activePaneId;
    if (activePaneId != null) {
      await _selectPane(activePaneId);
    } else {
      // Clear and re-fetch terminal content
      _viewNotifier.value = _viewNotifier.value.copyWith(content: '');
      _hasInitialScrolled = false;
    }
  }

  /// Select pane
  Future<void> _selectPane(String paneId) async {
    final sshClient = ref.read(sshProvider.notifier).client;
    if (sshClient == null || !sshClient.isConnected) return;

    final oldPaneId = ref.read(tmuxProvider).activePaneId;

    try {
      // Send focus-out to previous pane
      if (oldPaneId != null && oldPaneId != paneId) {
        await sshClient.exec(TmuxCommands.sendKeys(oldPaneId, '\x1b[O', literal: true));
      }

      // Execute tmux select-pane
      await sshClient.exec(TmuxCommands.selectPane(paneId));

      // Send focus-in to new pane (so apps like Claude Code can detect focus)
      await sshClient.exec(TmuxCommands.sendKeys(paneId, '\x1b[I', literal: true));
    } catch (e) {
      // Ignore if SSH connection is closed
      AppLog.d('[Terminal] Failed to select pane: $e');
      return;
    }
    if (!mounted || _isDisposed) return;

    // Update active pane in tmux_provider
    ref.read(tmuxProvider.notifier).setActivePane(paneId);

    // Notify TerminalDisplayProvider of pane info (for font size calculation)
    final activePane = ref.read(tmuxProvider).activePane;
    final tmuxState = ref.read(tmuxProvider);
    if (activePane != null) {
      ref.read(terminalDisplayProvider.notifier).updatePane(activePane);
      _viewNotifier.value = _viewNotifier.value.copyWith(
        paneWidth: activePane.width,
        paneHeight: activePane.height,
        content: '',
      );
      // Reset initial scroll flag when switching panes
      // Scroll to bottom on next content received
      _hasInitialScrolled = false;

      // Auto-resize: resize tmux pane to screen size when pane is selected
      final settings = ref.read(settingsProvider);
      if (settings.isAutoResize) {
        await _executeAutoResize(activePane);
      }

      // Save session info (for restoration)
      final sessionName = tmuxState.activeSessionName;
      final windowIndex = tmuxState.activeWindowIndex;
      if (sessionName != null && windowIndex != null) {
        ref.read(activeSessionsProvider.notifier).updateLastPane(
              connectionId: widget.connectionId,
              sessionName: sessionName,
              windowIndex: windowIndex,
              paneId: paneId,
            );
      }
    }
  }

  /// Scroll to caret position
  ///
  /// Called on initial display after pane/window switch,
  /// Scroll so cursor line appears near center of screen
  void _scrollToCaret() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || _isDisposed) return;
      _ansiTextViewKey.currentState?.scrollToCaret();
    });
  }

  /// Create new window
  Future<void> _createWindow(String? windowName) async {
    if (_isCreatingWindow) return;
    _isCreatingWindow = true;
    try {
      final sshClient = ref.read(sshProvider.notifier).client;
      if (sshClient == null || !sshClient.isConnected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SSH connection is not available')),
          );
        }
        return;
      }
      final session = ref.read(tmuxProvider).activeSession;
      if (session == null) return;

      await sshClient.exec(TmuxCommands.newWindow(
        sessionName: session.name,
        windowName: windowName,
      ));
      await _refreshSessionTree();
      if (!mounted) return;

      // Detect window with active=1 and auto-switch
      final updatedSession = ref.read(tmuxProvider).activeSession;
      final activeWindow =
          updatedSession?.windows.where((w) => w.active).firstOrNull;
      if (activeWindow != null) {
        ref.read(tmuxProvider.notifier).setActiveWindow(activeWindow.index);
        _viewNotifier.value = _viewNotifier.value.copyWith(content: '');
        _hasInitialScrolled = false;
        final activePaneId = ref.read(tmuxProvider).activePaneId;
        if (activePaneId != null) {
          await _selectPane(activePaneId);
        }
      }
      _boostPolling();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create window: $e')),
        );
      }
    } finally {
      _isCreatingWindow = false;
    }
  }

  /// Split pane
  Future<void> _splitPane(String paneId, SplitDirection direction) async {
    final sshClient = ref.read(sshProvider.notifier).client;
    if (sshClient == null || !sshClient.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SSH connection is not available')),
        );
      }
      return;
    }

    try {
      final command = direction == SplitDirection.horizontal
          ? TmuxCommands.splitWindowHorizontal(target: paneId)
          : TmuxCommands.splitWindowVertical(target: paneId);
      await sshClient.exec(command);
      await _refreshSessionTree();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to split pane: $e')),
        );
      }
    }
  }

  /// Auto-resize: resize tmux pane to fit screen size
  Future<void> _executeAutoResize(TmuxPane pane) async {
    if (_isResizing) return;
    if (_tmuxVersion != null && !_tmuxVersion!.supportsResizePaneToSize) return;

    final displayState = ref.read(terminalDisplayProvider);
    final settings = ref.read(settingsProvider);

    final fontSize = settings.fontSize;
    final targetCols = FontCalculator.calculateMaxCols(
      screenWidth: displayState.screenWidth,
      fontSize: fontSize,
      fontFamily: settings.fontFamily,
    );
    final targetRows = FontCalculator.calculateMaxRows(
      screenHeight: displayState.screenHeight,
      fontSize: fontSize,
      fontFamily: settings.fontFamily,
    );

    AppLog.d('[AutoResize] screenWidth=${displayState.screenWidth} '
        'screenHeight=${displayState.screenHeight} '
        'fontSize=$fontSize '
        'fontFamily=${settings.fontFamily} '
        'pane=${pane.id} current=${pane.width}x${pane.height} '
        'target=${targetCols}x$targetRows');

    // Skip if same as existing size
    if (pane.width == targetCols && pane.height == targetRows) return;

    _isResizing = true;
    _pollTimer?.cancel();
    try {
      final sshClient = ref.read(sshProvider.notifier).client;
      if (sshClient == null || !sshClient.isConnected) return;
      await sshClient.exec(
        TmuxCommands.resizePaneToSize(pane.id, cols: targetCols, rows: targetRows),
      );
      await _refreshSessionTree();
      final updatedPane = ref.read(tmuxProvider).activePane;
      if (updatedPane != null) {
        ref.read(terminalDisplayProvider.notifier).updatePane(updatedPane);
      }
    } catch (e) {
      AppLog.d('[AutoResize] Failed: $e');
    } finally {
      _isResizing = false;
      if (mounted && !_isDisposed) _startPolling();
    }
  }

  /// Resize pane
  Future<void> _handleResizePane(TmuxPane pane) async {
    if (_isResizing) return;

    final displayState = ref.read(terminalDisplayProvider);
    final settings = ref.read(settingsProvider);
    final tmuxState = ref.read(tmuxProvider);

    // Get all panes in current window
    final activeWindow = tmuxState.activeWindow;
    final allPanes = activeWindow?.panes ?? [pane];

    final result = await showDialog<ResizeResult>(
      context: context,
      builder: (context) => ResizePaneDialog(
        targetPane: pane,
        allPanesInWindow: allPanes,
        currentCols: pane.width,
        currentRows: pane.height,
        screenWidth: displayState.screenWidth,
        screenHeight: displayState.screenHeight,
        fontSize: displayState.calculatedFontSize,
        fontFamily: settings.fontFamily,
      ),
    );

    if (result == null || !mounted) return;

    _isResizing = true;
    _pollTimer?.cancel();
    try {
      final sshClient = ref.read(sshProvider.notifier).client;
      if (sshClient == null) return;
      await sshClient.exec(
        TmuxCommands.resizePaneToSize(pane.id, cols: result.cols, rows: result.rows),
      );
      await _refreshSessionTree();
      // Explicitly call updatePane to recalculate font
      final activePane = ref.read(tmuxProvider).activePane;
      if (activePane != null) {
        ref.read(terminalDisplayProvider.notifier).updatePane(activePane);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resize failed: $e')),
        );
      }
    } finally {
      _isResizing = false;
      if (mounted && !_isDisposed) _startPolling();
    }
  }

  /// Resize window
  Future<void> _handleResizeWindow(TmuxWindow window) async {
    if (_isResizing) return;

    final displayState = ref.read(terminalDisplayProvider);
    final settings = ref.read(settingsProvider);

    // Estimate window size as max value of pane width+left
    final panes = window.panes;
    int windowCols = 80;
    int windowRows = 24;
    if (panes.isNotEmpty) {
      windowCols = panes.map((p) => p.left + p.width).reduce((a, b) => a > b ? a : b);
      windowRows = panes.map((p) => p.top + p.height).reduce((a, b) => a > b ? a : b);
    }

    final result = await showDialog<ResizeResult>(
      context: context,
      builder: (context) => ResizeWindowDialog(
        window: window,
        panes: panes,
        currentCols: windowCols,
        currentRows: windowRows,
        screenWidth: displayState.screenWidth,
        screenHeight: displayState.screenHeight,
        fontSize: displayState.calculatedFontSize,
        fontFamily: settings.fontFamily,
        supportsResizeWindow: _tmuxVersion?.supportsResizeWindow ?? false,
      ),
    );

    if (result == null || !mounted) return;

    _isResizing = true;
    _pollTimer?.cancel();
    try {
      final sshClient = ref.read(sshProvider.notifier).client;
      if (sshClient == null) return;
      final tmuxState = ref.read(tmuxProvider);
      final target = '${tmuxState.activeSessionName}:${window.index}';
      await sshClient.exec(
        TmuxCommands.resizeWindow(target, cols: result.cols, rows: result.rows),
      );
      await _refreshSessionTree();
      final activePane = ref.read(tmuxProvider).activePane;
      if (activePane != null) {
        ref.read(terminalDisplayProvider.notifier).updatePane(activePane);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resize failed: $e')),
        );
      }
    } finally {
      _isResizing = false;
      if (mounted && !_isDisposed) _startPolling();
    }
  }

  /// Close pane (execute kill-pane via SSH)
  Future<void> _killPane({
    required String paneId,
    required bool isLastPane,
    required bool isLastWindow,
  }) async {
    final sshClient = ref.read(sshProvider.notifier).client;
    if (sshClient == null || !sshClient.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SSH connection is not available')),
        );
      }
      return;
    }

    // Stop polling (avoid SSH conflicts)
    _pollTimer?.cancel();

    try {
      await sshClient.exec(TmuxCommands.killPane(paneId));
      await _refreshSessionTree();
      if (!mounted || _isDisposed) return;

      // Check if session terminated (if was last pane of last window)
      if (isLastPane && isLastWindow) {
        final sessionsOutput =
            await sshClient.exec('tmux list-sessions 2>/dev/null || true');
        if (!mounted || _isDisposed) return;
        if (sessionsOutput.trim().isEmpty) {
          await _disconnect();
          return;
        }
      }

      // If was last pane → sync to new window auto-selected by tmux
      if (isLastPane) {
        final newTmuxState = ref.read(tmuxProvider);
        final newSession = newTmuxState.activeSession;
        if (newSession != null) {
          final newActiveWindow =
              newSession.windows.where((w) => w.active).firstOrNull ??
                  newSession.windows.firstOrNull;
          if (newActiveWindow != null) {
            await _selectWindow(newSession.name, newActiveWindow.index);
          }
        }
      } else {
        // Sync to remaining panes in same window
        final newTmuxState = ref.read(tmuxProvider);
        final activeWindow = newTmuxState.activeWindow;
        if (activeWindow != null) {
          final newActivePane =
              activeWindow.panes.where((p) => p.active).firstOrNull ??
                  activeWindow.panes.firstOrNull;
          if (newActivePane != null) {
            await _selectPane(newActivePane.id);
          }
        }
      }
    } catch (e) {
      AppLog.d('[Terminal] Failed to kill pane: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to close pane: $e')),
        );
      }
    } finally {
      // Resume polling
      if (mounted && !_isDisposed) {
        _startPolling();
      }
    }
  }

  /// Close window
  Future<void> _killWindow({
    required String sessionName,
    required int windowIndex,
    required bool wasActiveWindow,
  }) async {
    final sshClient = ref.read(sshProvider.notifier).client;
    if (sshClient == null || !sshClient.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SSH connection is not available')),
        );
      }
      return;
    }

    try {
      AppLog.d('[Terminal] Killing window: $sessionName:$windowIndex');
      await sshClient.exec(TmuxCommands.killWindow(sessionName, windowIndex));
      await _refreshSessionTree();

      if (!mounted || _isDisposed) return;

      // Check if session terminated: verify directly with list-sessions
      final sessionsOutput = await sshClient.exec('tmux list-sessions 2>/dev/null || true');
      if (sessionsOutput.trim().isEmpty) {
        AppLog.d('[Terminal] Last window closed, session terminated. Disconnecting...');
        await _disconnect();
        return;
      }

      // If active window was closed, sync to new window auto-selected by tmux
      if (wasActiveWindow) {
        final newTmuxState = ref.read(tmuxProvider);
        final newSession = newTmuxState.activeSession;
        if (newSession != null) {
          final newActiveWindow = newSession.windows.where((w) => w.active).firstOrNull
              ?? newSession.windows.firstOrNull;
          if (newActiveWindow != null) {
            await _selectWindow(newSession.name, newActiveWindow.index);
          }
        }
      }
    } catch (e) {
      AppLog.d('[Terminal] Failed to kill window: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to close window: $e')),
        );
      }
    }
  }

  /// Disconnect SSH and return to previous screen
  Future<void> _disconnect() async {
    // Stop polling
    _pollTimer?.cancel();
    _treeRefreshTimer?.cancel();

    // Disconnect SSH
    await ref.read(sshProvider.notifier).disconnect();

    // Return to previous screen
    if (mounted) {
      Navigator.pop(context);
    }
  }

  /// Send key via tmux send-keys
  ///
  /// [key] key to send
  /// [literal] if true, send as literal (-l flag)
  Future<void> _sendKey(String key, {bool literal = true}) async {
    final sshClient = ref.read(sshProvider.notifier).client;

    // Add to queue if connection lost (literals only)
    if (sshClient == null || !sshClient.isConnected) {
      if (literal) {
        final wasOverflow = _inputQueue.isOverflow;
        _inputQueue.enqueue(key);
        if (!wasOverflow && _inputQueue.isOverflow && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Input queue is full; some keystrokes may be lost.'),
            ),
          );
        }
        if (mounted) setState(() {}); // Update queuing state
      }
      return;
    }

    final target = ref.read(tmuxProvider.notifier).currentTarget;
    if (target == null) return;

    try {
      await sshClient.exec(TmuxCommands.sendKeys(target, key, literal: literal));
      _boostPolling();
    } catch (_) {
      // Silently ignore key send errors (state updated during polling)
    }
  }

  /// Enter tmux copy-mode
  Future<void> _enterTmuxCopyMode() async {
    final sshClient = ref.read(sshProvider.notifier).client;
    if (sshClient == null || !sshClient.isConnected) return;
    final target = ref.read(tmuxProvider.notifier).currentTarget;
    if (target == null) return;
    try {
      await sshClient.exec(TmuxCommands.enterCopyMode(target));
      _boostPolling();
    } catch (_) {}
  }

  /// Exit tmux copy-mode
  Future<void> _cancelTmuxCopyMode() async {
    final sshClient = ref.read(sshProvider.notifier).client;
    if (sshClient == null || !sshClient.isConnected) return;
    final target = ref.read(tmuxProvider.notifier).currentTarget;
    if (target == null) return;
    try {
      await sshClient.exec(TmuxCommands.cancelCopyMode(target));
      _boostPolling();
    } catch (_) {}
  }

  /// Send tmux special key (Ctrl+C, Escape, etc)
  Future<void> _sendSpecialKey(String tmuxKey) async {
    final sshClient = ref.read(sshProvider.notifier).client;

    // Special keys are not sent if connection is lost (not queued)
    if (sshClient == null || !sshClient.isConnected) return;

    final target = ref.read(tmuxProvider.notifier).currentTarget;
    if (target == null) return;

    try {
      // Special keys sent in tmux format, not literal
      await sshClient.exec(TmuxCommands.sendKeys(target, tmuxKey, literal: false));
      _boostPolling();
    } catch (_) {
      // Silently ignore key send errors (state updated during polling)
    }
  }

  ProviderSubscription? _imageTransferSub;

  /// Initialize image transfer state listener (once only)
  void _ensureImageTransferListener() {
    if (_imageTransferSub != null) return;
    _imageTransferSub = ref.listenManual(imageTransferProvider, (prev, next) async {

      if (next.phase == ImageTransferPhase.confirming &&
          next.pickedImageBytes != null &&
          next.pendingRemotePath != null &&
          (prev?.phase == ImageTransferPhase.picking)) {
        if (!mounted) return;
        final settings = ref.read(settingsProvider);
        final options = await ImageTransferConfirmDialog.show(
          context,
          remotePath: next.pendingRemotePath!,
          imageBytes: next.pickedImageBytes!,
          imageName: next.pickedImageName,
          settings: settings,
        );

        if (options != null) {
          final uploadedPath = await ref
              .read(imageTransferProvider.notifier)
              .confirmAndUpload(options: options);

          if (uploadedPath != null && mounted) {
            await _injectImagePath(uploadedPath, options);
          }
        } else {
          ref.read(imageTransferProvider.notifier).cancel();
        }
      }

      if (next.phase == ImageTransferPhase.error && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'Image transfer failed'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }

      if (next.phase == ImageTransferPhase.completed &&
          next.lastUploadedPath != null &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded: ${next.lastUploadedPath}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  /// Open file browser
  void _handleFileBrowser() {
    final activePaneId = ref.read(tmuxProvider).activePaneId;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FileBrowserScreen(
          connectionId: widget.connectionId,
          paneId: activePaneId,
        ),
      ),
    );
  }

  /// Start image transfer flow
  void _handleImageTransfer() {
    _ensureImageTransferListener();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(imageTransferProvider.notifier).pickImage(
                      ImageSource.gallery,
                    );
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(imageTransferProvider.notifier).pickImage(
                      ImageSource.camera,
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Inject uploaded image path to terminal
  Future<void> _injectImagePath(String remotePath, ImageTransferOptions options) async {
    final sshClient = ref.read(sshProvider.notifier).client;
    if (sshClient == null || !sshClient.isConnected) return;

    final activePaneId = ref.read(tmuxProvider).activePaneId;
    if (activePaneId == null) return;

    // Apply path format (from options)
    final formattedPath = options.pathFormat.replaceAll('{path}', remotePath);

    if (options.bracketedPaste) {
      sshClient.write('\x1b[200~$formattedPath\x1b[201~');
    } else {
      await sshClient.exec(
        TmuxCommands.sendKeys(activePaneId, formattedPath, literal: true),
      );
    }

    if (options.autoEnter) {
      await sshClient.exec(
        TmuxCommands.sendKeys(activePaneId, 'Enter'),
      );
    }

    _boostPolling();
  }
  /// Sends multi-line text to the active pane using tmux load-buffer +
  /// paste-buffer so the entire payload is delivered atomically in one
  /// SSH round-trip.  Bracketed paste mode (`-p`) tells the receiving
  /// shell to treat the block as literal data, preventing `\`-continuation
  /// and prompt-redraw races that plagued the previous per-line approach.
  Future<void> _sendMultilineText(String text) async {
    if (text.isEmpty) return;

    final target = ref.read(tmuxProvider.notifier).currentTarget;
    if (target == null) return;

    // Pass text as-is: bracketed paste preserves whatever newlines are
    // present. The caller decides whether a trailing Enter is desired.
    final payload = text;

    final sshClient = ref.read(sshProvider.notifier).client;
    if (sshClient == null || !sshClient.isConnected) {
      // Multi-line paste via send-keys would re-introduce the race condition
      // fixed by PR #51. Reject the operation and ask the user to retry
      // once connected rather than silently queuing via the legacy path.
      if (text.contains('\n') && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Multi-line send requires a live connection; please retry.',
            ),
          ),
        );
      } else {
        _inputQueue.enqueue(text);
        if (mounted) setState(() {});
      }
      return;
    }

    try {
      await sshClient.exec(
        TmuxCommands.loadBufferAndPaste(target, payload),
      );
      _boostPolling();
    } catch (e) {
      AppLog.d('[Terminal] paste-buffer send failed: $e');
      // Retry without bracketed paste for tmux < 2.6 which does not
      // support the -p flag.
      try {
        await sshClient.exec(
          TmuxCommands.loadBufferAndPasteNoBracketed(target, payload),
        );
        _boostPolling();
      } catch (e2) {
        AppLog.d('[Terminal] paste-buffer (no-bracketed) send failed: $e2');
        // TODO: surface a SnackBar after repeated failures.
      }
    }
  }

}
