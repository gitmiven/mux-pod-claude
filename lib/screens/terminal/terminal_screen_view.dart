part of 'terminal_screen.dart';

mixin _TerminalScreenView on _TerminalScreenLogic {
  /// Error overlay
  Widget _buildErrorOverlay(String? error) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final queuedCount = _inputQueue.length;
    final isWaitingForNetwork = _sshState.isWaitingForNetwork;

    return Container(
      color: isDark ? Colors.black87 : Colors.white.withValues(alpha: 0.95),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isWaitingForNetwork ? Icons.signal_wifi_off : Icons.error_outline,
              color: isWaitingForNetwork ? DesignColors.warning : colorScheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              isWaitingForNetwork
                  ? 'Waiting for network...'
                  : (error ?? 'Connection error'),
              style: TextStyle(color: colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),

            // Queuing state
            if (queuedCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: DesignColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.keyboard,
                      size: 16,
                      color: DesignColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$queuedCount chars queued',
                      style: TextStyle(
                        color: DesignColors.primary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _inputQueue.clear();
                        setState(() {});
                      },
                      child: Icon(
                        Icons.clear,
                        size: 16,
                        color: DesignColors.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () {
                    ref.read(sshProvider.notifier).reconnectNow();
                  },
                  child: const Text('Retry Now'),
                ),
                if (_sshState.isReconnecting) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Breadcrumb navigation header at top
  Widget _buildBreadcrumbHeader(TmuxState tmuxState) {
    final currentSession = tmuxState.activeSessionName ?? '';
    final activeWindow = tmuxState.activeWindow;
    final currentWindow = activeWindow?.name ?? '';
    final activePane = tmuxState.activePane;
    final colorScheme = Theme.of(context).colorScheme;

    // Place SafeArea outside to reserve space for status bar
    return SafeArea(
      bottom: false,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.9),
          border: Border(
            bottom: BorderSide(color: colorScheme.outline, width: 1),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            // Breadcrumb navigation
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Session name (tap to switch)
                    _buildBreadcrumbItem(
                      currentSession,
                      icon: Icons.folder,
                      isActive: true,
                      onTap: () => _showSessionSelector(tmuxState),
                    ),
                    _buildBreadcrumbSeparator(),
                    // Window name (tap to switch)
                    _buildBreadcrumbItem(
                      currentWindow,
                      icon: Icons.tab,
                      isSelected: true,
                      onTap: () => _showWindowSelector(tmuxState),
                    ),
                    // Display if pane exists
                    if (activePane != null) ...[
                      _buildBreadcrumbSeparator(),
                      _buildBreadcrumbItem(
                        'Pane ${activePane.index}',
                        icon: Icons.terminal,
                        isActive: false,
                        onTap: () => _showPaneSelector(tmuxState),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Scroll mode indicator
            if (_terminalMode == TerminalMode.scroll)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: DesignColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: DesignColors.warning.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.unfold_more, size: 12, color: DesignColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      'Scroll',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: DesignColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            // Zoom indicator
            if (_zoomScale != 1.0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: DesignColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(_zoomScale * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: DesignColors.warning,
                  ),
                ),
              ),
            // Latency / Reconnect indicator (scope polling updates with ValueListenableBuilder)
            ValueListenableBuilder<_TerminalViewData>(
              valueListenable: _viewNotifier,
              builder: (context, viewData, _) => _buildConnectionIndicator(viewData.latency),
            ),
            // File browser button
            IconButton(
              onPressed: _handleFileBrowser,
              icon: Icon(
                Icons.folder_outlined,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              tooltip: 'File Browser',
            ),
            // Settings button
            IconButton(
              onPressed: _showTerminalMenu,
              icon: Icon(
                Icons.settings,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  /// Display session selection dialog
  void _showSessionSelector(TmuxState tmuxState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.6;
        final sessions = [...tmuxState.sessions]
          ..sort(TmuxSession.byRecencyDesc);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.folder, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Select Session',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: colorScheme.outline),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    // Order most-recently-active first (matches the startup
                    // list's "recent" feel); sort a copy so tmuxState's order is
                    // left untouched for other consumers.
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final isActive = session.name == tmuxState.activeSessionName;
                      return TmuxSessionTile(
                        session: session,
                        isActive: isActive,
                        onTap: () {
                          Navigator.pop(context);
                          _selectSession(session.name);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _scrollToBottomKey.currentState?.show();
    });
  }

  /// Display window selection dialog
  void _showWindowSelector(TmuxState tmuxState) {
    final session = tmuxState.activeSession;
    if (session == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.6;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.tab, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Select Window',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.open_in_full, color: colorScheme.primary),
                        tooltip: 'Resize Window',
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          Future.delayed(const Duration(milliseconds: 200), () {
                            if (mounted) _showResizeWindowChooser(tmuxState);
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.add, color: colorScheme.primary),
                        tooltip: 'New Window',
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          Future.delayed(const Duration(milliseconds: 200), () {
                            if (mounted) _showCreateWindowDialog(session);
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: colorScheme.outline),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: session.windows.length,
                    itemBuilder: (context, index) {
                      final window = session.windows[index];
                      final isActive = window.index == tmuxState.activeWindowIndex;
                      return TmuxWindowTile(
                        window: window,
                        isActive: isActive,
                        onTap: () {
                          Navigator.pop(context);
                          _selectWindow(session.name, window.index);
                        },
                        onResize: () {
                          Navigator.pop(context);
                          _handleResizeWindow(window);
                        },
                        onClose: () {
                          Navigator.pop(context);
                          _confirmAndKillWindow(
                            sessionName: session.name,
                            windowIndex: window.index,
                            windowName: window.name,
                            isLastWindow: session.windows.length == 1,
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _scrollToBottomKey.currentState?.show();
    });
  }

  /// Display window creation dialog
  void _showCreateWindowDialog(TmuxSession session) {
    final existingNames = session.windows.map((w) => w.name).toList();
    showDialog<String>(
      context: context,
      builder: (dialogContext) => NewWindowDialog(
        existingWindowNames: existingNames,
      ),
    ).then((windowName) {
      if (windowName != null) {
        _createWindow(windowName.isEmpty ? null : windowName);
      }
    });
  }

  /// Display confirm close pane dialog
  void _confirmAndKillPane({
    required String paneId,
    required String paneTitle,
    required bool isLastPane,
    required bool isLastWindow,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
              isDark ? DesignColors.surfaceDark : DesignColors.surfaceLight,
          title: Text(
            'Close Pane?',
            style: TextStyle(
              color: isDark
                  ? DesignColors.textPrimary
                  : DesignColors.textPrimaryLight,
            ),
          ),
          content: Text(
            isLastPane && isLastWindow
                ? 'This is the last pane in the last window. Closing it will end the session and disconnect from the server.'
                : isLastPane
                    ? 'This is the last pane in this window. Closing it will also close the window.'
                    : 'Are you sure you want to close pane "$paneTitle"?',
            style: TextStyle(
              color: isDark
                  ? DesignColors.textSecondary
                  : DesignColors.textSecondaryLight,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark
                      ? DesignColors.textSecondary
                      : DesignColors.textSecondaryLight,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                // Re-validate pane exists before execution
                final currentWindow = ref.read(tmuxProvider).activeWindow;
                if (currentWindow == null ||
                    !currentWindow.panes.any((p) => p.id == paneId)) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('This pane no longer exists')),
                    );
                  }
                  return;
                }
                _killPane(
                  paneId: paneId,
                  isLastPane: isLastPane,
                  isLastWindow: isLastWindow,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Dialog to graphically select pane for resizing
  void _showResizePaneChooser(TmuxState tmuxState) {
    final window = tmuxState.activeWindow;
    if (window == null || window.panes.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return ResizePaneChooserDialog(
          panes: window.panes,
          activePaneId: tmuxState.activePaneId,
          onResize: (selectedPane) {
            Navigator.pop(dialogContext);
            _handleResizePane(selectedPane);
          },
        );
      },
    );
  }

  /// Dialog to graphically select window for resizing
  void _showResizeWindowChooser(TmuxState tmuxState) {
    final session = tmuxState.activeSession;
    if (session == null || session.windows.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return ResizeWindowChooserDialog(
          windows: session.windows,
          activeWindowIndex: tmuxState.activeWindowIndex,
          onResize: (selectedWindow) {
            Navigator.pop(dialogContext);
            _handleResizeWindow(selectedWindow);
          },
        );
      },
    );
  }

  /// Display pane selection dialog
  void _showPaneSelector(TmuxState tmuxState) {
    final window = tmuxState.activeWindow;
    if (window == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.7;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.terminal, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Select Pane',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.open_in_full, color: colorScheme.primary),
                        tooltip: 'Resize Pane',
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          Future.delayed(const Duration(milliseconds: 200), () {
                            if (mounted) _showResizePaneChooser(tmuxState);
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: colorScheme.outline),
                // Visual display of pane layout
                PaneLayoutVisualizer(
                  panes: window.panes,
                  activePaneId: tmuxState.activePaneId,
                  onPaneSelected: (paneId) {
                    Navigator.pop(sheetContext);
                    _selectPane(paneId);
                  },
                  onSplitRequested: (paneId, direction) {
                    Navigator.pop(sheetContext);
                    _splitPane(paneId, direction);
                  },
                ),
                Divider(height: 1, color: colorScheme.outline),
                // Pane list
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: window.panes.length,
                    itemBuilder: (context, index) {
                      final pane = window.panes[index];
                      final isActive = pane.id == tmuxState.activePaneId;
                      // Display title first, then command name, then pane index
                      final paneTitle = pane.title?.isNotEmpty == true
                          ? pane.title!
                          : (pane.currentCommand?.isNotEmpty == true
                              ? pane.currentCommand!
                              : 'Pane ${pane.index}');
                      return TmuxPaneTile(
                        pane: pane,
                        paneTitle: paneTitle,
                        isActive: isActive,
                        onTap: () {
                          Navigator.pop(context);
                          _selectPane(pane.id);
                        },
                        onLongPress: () {
                          Navigator.pop(context);
                          _confirmAndKillPane(
                            paneId: pane.id,
                            paneTitle: paneTitle,
                            isLastPane: window.panes.length == 1,
                            isLastWindow:
                                (tmuxState.activeSession?.windows.length ??
                                        0) ==
                                    1,
                          );
                        },
                        onResize: () {
                          Navigator.pop(context);
                          _handleResizePane(pane);
                        },
                        onClose: () {
                          Navigator.pop(context);
                          _confirmAndKillPane(
                            paneId: pane.id,
                            paneTitle: paneTitle,
                            isLastPane: window.panes.length == 1,
                            isLastWindow:
                                (tmuxState.activeSession?.windows.length ??
                                        0) ==
                                    1,
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _scrollToBottomKey.currentState?.show();
    });
  }

  Widget _buildBreadcrumbItem(
    String label, {
    IconData? icon,
    bool isActive = false,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: isSelected
            ? BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.05)),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 12,
                color: isActive
                    ? colorScheme.primary
                    : (isSelected ? colorScheme.onSurface : colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label.isEmpty ? '...' : label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: isActive || isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isActive
                    ? colorScheme.primary
                    : (isSelected ? colorScheme.onSurface : colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down,
                size: 14,
                color: isActive
                    ? colorScheme.primary.withValues(alpha: 0.7)
                    : colorScheme.onSurface.withValues(alpha: 0.38),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbSeparator() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '/',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w300,
          color: colorScheme.onSurface.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  /// Display terminal menu
  void _showTerminalMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final menuBgColor = isDark ? DesignColors.surfaceDark : DesignColors.surfaceLight;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.white38 : Colors.black38;
    final inactiveIconColor = isDark ? Colors.white60 : Colors.black45;

    showModalBottomSheet(
      context: context,
      backgroundColor: menuBgColor,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.tune, color: DesignColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Terminal Options',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF2A2B36) : Colors.grey.shade300),
              // Mode switching (Normal / Scroll & Select)
              ListTile(
                leading: Icon(
                  _terminalMode == TerminalMode.scroll
                      ? Icons.unfold_more
                      : Icons.keyboard,
                  color: _terminalMode == TerminalMode.scroll
                      ? DesignColors.warning
                      : inactiveIconColor,
                ),
                title: Text(
                  _terminalMode == TerminalMode.scroll
                      ? 'Scroll & Select Mode'
                      : 'Normal Mode',
                  style: TextStyle(
                    color: _terminalMode == TerminalMode.scroll
                        ? DesignColors.warning
                        : textColor,
                    fontWeight: _terminalMode == TerminalMode.scroll
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  _terminalMode == TerminalMode.scroll
                      ? 'Tap to return to normal mode'
                      : 'Tap to enable text selection',
                  style: TextStyle(color: mutedTextColor, fontSize: 12),
                ),
                trailing: Switch(
                  value: _terminalMode == TerminalMode.scroll,
                  onChanged: (value) {
                    final newMode = value
                        ? TerminalMode.scroll
                        : TerminalMode.normal;
                    setState(() {
                      _terminalMode = newMode;
                      _scrollModeSource = value ? ScrollModeSource.manual : ScrollModeSource.none;
                    });
                    if (newMode == TerminalMode.scroll) {
                      _enterTmuxCopyMode();
                    } else {
                      _cancelTmuxCopyMode();
                      _applyBufferedUpdate();
                    }
                    Navigator.pop(context);
                  },
                  activeThumbColor: DesignColors.warning,
                ),
                onTap: () {
                  final isScrolling = _terminalMode == TerminalMode.scroll;
                  final newMode = isScrolling
                      ? TerminalMode.normal
                      : TerminalMode.scroll;
                  setState(() {
                    _terminalMode = newMode;
                    _scrollModeSource = isScrolling ? ScrollModeSource.none : ScrollModeSource.manual;
                  });
                  if (newMode == TerminalMode.scroll) {
                    _enterTmuxCopyMode();
                  } else {
                    _cancelTmuxCopyMode();
                    _applyBufferedUpdate();
                  }
                  Navigator.pop(context);
                },
              ),
              // Reset zoom
              ListTile(
                leading: Icon(
                  Icons.zoom_out_map,
                  color: _zoomScale != 1.0 ? DesignColors.warning : inactiveIconColor,
                ),
                title: Text(
                  'Reset Zoom',
                  style: TextStyle(
                    color: _zoomScale != 1.0 ? textColor : mutedTextColor,
                  ),
                ),
                subtitle: Text(
                  _zoomScale != 1.0
                      ? 'Current: ${(_zoomScale * 100).toStringAsFixed(0)}%'
                      : 'Pinch to zoom in/out',
                  style: TextStyle(color: mutedTextColor, fontSize: 12),
                ),
                enabled: _zoomScale != 1.0,
                onTap: _zoomScale != 1.0
                    ? () {
                        _ansiTextViewKey.currentState?.resetZoom();
                        setState(() {
                          _zoomScale = 1.0;
                        });
                        Navigator.pop(context);
                      }
                    : null,
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF2A2B36) : Colors.grey.shade300),
              // Go to settings screen
              ListTile(
                leading: Icon(
                  Icons.settings,
                  color: inactiveIconColor,
                ),
                title: Text(
                  'Settings',
                  style: TextStyle(color: textColor),
                ),
                subtitle: Text(
                  'Font, theme, and other options',
                  style: TextStyle(color: mutedTextColor, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF2A2B36) : Colors.grey.shade300),
              // Disconnect button
              ListTile(
                leading: Icon(
                  Icons.power_settings_new,
                  color: DesignColors.error,
                ),
                title: Text(
                  'Disconnect',
                  style: TextStyle(
                    color: DesignColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Close SSH connection',
                  style: TextStyle(color: mutedTextColor, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDisconnectConfirmation();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ).then((_) {
      _scrollToBottomKey.currentState?.show();
    });
  }

  /// Display confirm close window dialog
  void _confirmAndKillWindow({
    required String sessionName,
    required int windowIndex,
    required String windowName,
    required bool isLastWindow,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? DesignColors.surfaceDark : DesignColors.surfaceLight,
          title: Text(
            'Close Window?',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: Text(
            isLastWindow
                ? 'This is the last window in the session. Closing it will end the session and disconnect from the server.'
                : 'Are you sure you want to close window "$windowName"?',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                final wasActive = windowIndex == ref.read(tmuxProvider).activeWindowIndex;
                _killWindow(
                  sessionName: sessionName,
                  windowIndex: windowIndex,
                  wasActiveWindow: wasActive,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Display disconnect confirmation dialog
  void _showDisconnectConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? DesignColors.surfaceDark : DesignColors.surfaceLight,
          title: Text(
            'Disconnect?',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: Text(
            'Are you sure you want to disconnect from the server?',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                await _disconnect();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Disconnect'),
            ),
          ],
        );
      },
    );
  }

  /// Connection status indicator (display latency or reconnect state)
  Widget _buildConnectionIndicator(int latency) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: colorScheme.outline, width: 1),
        ),
      ),
      child: _sshState.isReconnecting
          ? _buildReconnectingIndicator()
          : _buildLatencyIndicator(latency),
    );
  }

  /// Latency display
  Widget _buildLatencyIndicator(int latency) {
    // Determine color based on latency
    Color indicatorColor;
    if (latency < 100) {
      indicatorColor = DesignColors.success; // Green: good
    } else if (latency < 300) {
      indicatorColor = DesignColors.primary; // Cyan: normal
    } else if (latency < 500) {
      indicatorColor = DesignColors.warning; // Orange: slightly slow
    } else {
      indicatorColor = DesignColors.error; // Red: slow
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.bolt,
          size: 10,
          color: indicatorColor.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 4),
        Text(
          '${latency}ms',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: indicatorColor.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  /// Reconnecting indicator
  Widget _buildReconnectingIndicator() {
    final attempt = _sshState.reconnectAttempt;
    final isWaitingForNetwork = _sshState.isWaitingForNetwork;
    final nextRetryAt = _sshState.nextRetryAt;
    final queuedCount = _inputQueue.length;

    // Calculate seconds until next retry
    String? countdownText;
    if (nextRetryAt != null && !isWaitingForNetwork) {
      final remaining = nextRetryAt.difference(DateTime.now()).inSeconds;
      if (remaining > 0) {
        countdownText = '${remaining}s';
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Spinner or no-signal icon
        if (isWaitingForNetwork)
          Icon(
            Icons.signal_wifi_off,
            size: 12,
            color: DesignColors.warning.withValues(alpha: 0.8),
          )
        else
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: DesignColors.warning.withValues(alpha: 0.8),
            ),
          ),
        const SizedBox(width: 6),

        // Status text
        Text(
          isWaitingForNetwork
              ? 'Offline'
              : 'Reconnecting${attempt > 1 ? ' ($attempt)' : ''}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: DesignColors.warning.withValues(alpha: 0.8),
          ),
        ),

        // Countdown
        if (countdownText != null) ...[
          const SizedBox(width: 4),
          Text(
            countdownText,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              color: DesignColors.textMuted,
            ),
          ),
        ],

        // Queuing state
        if (queuedCount > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: DesignColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$queuedCount chars',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                color: DesignColors.primary,
              ),
            ),
          ),
        ],

        // Reconnect now button
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            ref.read(sshProvider.notifier).reconnectNow();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(
                color: DesignColors.warning.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Retry',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                color: DesignColors.warning,
              ),
            ),
          ),
        ),
      ],
    );
  }


  void _showInputDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => InputDialogContent(
        initialValue: _savedCommandInput,
        onValueChanged: (value) {
          // Save input in real-time
          _savedCommandInput = value;
        },
        onSend: (value) async {
          await _sendMultilineText(value);
          // Clear input on successful send
          _savedCommandInput = '';
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
      ),
    ).then((_) {
      _scrollToBottomKey.currentState?.show();
    });
  }

  /// Pane indicator at top right
  ///
  /// Display layout based on actual pane size ratios
  Widget _buildPaneIndicator(TmuxState tmuxState) {
    final window = tmuxState.activeWindow;
    final panes = window?.panes ?? [];
    final activePaneId = tmuxState.activePaneId;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    if (panes.isEmpty) {
      return const SizedBox.shrink();
    }

    // Size of entire indicator
    const double indicatorSize = 48.0;

    return GestureDetector(
      onTap: () => _showPaneSelector(tmuxState),
      child: Opacity(
        opacity: 0.5,
        child: Container(
          width: indicatorSize,
          height: indicatorSize,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.black12,
            borderRadius: BorderRadius.circular(4),
          ),
          child: CustomPaint(
            size: Size(indicatorSize - 4, indicatorSize - 4),
            painter: PaneLayoutPainter(
              panes: panes,
              activePaneId: activePaneId,
              activeColor: colorScheme.primary,
              isDark: isDark,
            ),
          ),
        ),
      ),
    );
  }
}
