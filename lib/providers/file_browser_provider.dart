import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/file_browser/file_browser_start.dart';
import '../services/sftp/file_entry.dart';
import '../services/sftp/sftp_browser_service.dart';
import '../services/ssh/ssh_client.dart';
import '../services/tmux/tmux_parser.dart';
import 'settings_provider.dart';
import 'ssh_provider.dart';
import 'tmux_provider.dart';
import '../services/logging/app_log.dart';

/// File browser state
class FileBrowserState {
  final String currentPath;
  final List<FileEntry> entries;
  final bool isLoading;
  final String? error;
  final SortOption sortOption;
  final bool sortAscending;
  final bool showHidden;

  const FileBrowserState({
    this.currentPath = '/',
    this.entries = const [],
    this.isLoading = false,
    this.error,
    this.sortOption = SortOption.name,
    this.sortAscending = true,
    this.showHidden = false,
  });

  FileBrowserState copyWith({
    String? currentPath,
    List<FileEntry>? entries,
    bool? isLoading,
    String? error,
    SortOption? sortOption,
    bool? sortAscending,
    bool? showHidden,
  }) {
    return FileBrowserState(
      currentPath: currentPath ?? this.currentPath,
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      sortOption: sortOption ?? this.sortOption,
      sortAscending: sortAscending ?? this.sortAscending,
      showHidden: showHidden ?? this.showHidden,
    );
  }

  /// List of entries with sort/filter applied
  List<FileEntry> get displayEntries {
    final service = _cachedBrowserService;
    final filtered = service.filterHidden(entries, showHidden);
    return service.sortEntries(filtered, sortOption, sortAscending);
  }

  static final _cachedBrowserService = SftpBrowserService();
}

/// File browser Notifier
///
/// Tied 1:1 to a tmux pane, using the pane's CWD as the initial directory.
/// Uses AutoDisposeNotifier and is automatically destroyed when the screen is closed.
class FileBrowserNotifier extends Notifier<FileBrowserState> {
  final SftpBrowserService _browserService = SftpBrowserService();
  final LastPathStore _lastPathStore = LastPathStore();

  /// Connection this browser session belongs to, for the per-connection
  /// "last visited" memory. Null disables remembering.
  String? _connectionId;

  /// Version number for race condition prevention
  int _listVersion = 0;

  /// SSH connection state monitoring
  StreamSubscription<SshConnectionState>? _connectionSub;

  @override
  FileBrowserState build() {
    ref.onDispose(() {
      _connectionSub?.cancel();
    });
    return const FileBrowserState();
  }

  /// Initialize file browser
  ///
  /// Uses the CWD of the pane associated with [paneId] as the initial directory.
  /// Falls back to home directory if CWD cannot be retrieved.
  Future<void> initialize(String? connectionId, String? paneId) async {
    // Clear previous error state
    _log('initialize START (connectionId=$connectionId, paneId=$paneId)');
    state = const FileBrowserState();
    _connectionId = connectionId;

    final tmuxState = ref.read(tmuxProvider);

    // The "Claude Code folder" — the pane's current working directory.
    String? claudeCodePath;
    if (paneId != null) {
      claudeCodePath = _findPaneById(tmuxState, paneId)?.currentPath;
    }

    // Monitor SSH connection state
    _startConnectionMonitoring();

    // Resolve the start directory per the configured mode.
    final mode = ref.read(settingsProvider).fileBrowserStartDir;
    String? lastPath;
    if (mode == kFileBrowserStartLastVisited && connectionId != null) {
      lastPath = await _lastPathStore.get(connectionId);
    }
    final candidates = startPathCandidates(
      mode: mode,
      lastPath: lastPath,
      claudeCodePath: claudeCodePath,
    );

    // Try each candidate; the first that loads wins.
    for (final path in candidates) {
      await loadDirectory(path);
      if (state.error == null) return;
      _log('initialize candidate failed ($path), trying next');
    }

    // Nothing loaded (or no candidate) → home directory.
    await _loadHomeDirectory();
  }

  /// Load directory
  Future<void> loadDirectory(String path) async {
    final version = ++_listVersion;
    _log('loadDirectory START (path=$path, version=$version)');

    state = state.copyWith(
      isLoading: true,
      error: null,
      currentPath: path,
      entries: path != state.currentPath ? const [] : null,
    );

    try {
      final sshClient = _getSshClient();
      _log('loadDirectory openSftp START');
      final sftp = await sshClient.openSftp();
      _log('loadDirectory openSftp OK');
      final entries = await _browserService.listDirectory(sftp, path);
      _log('loadDirectory listDirectory OK (entries=${entries.length})');

      // Race condition prevention: discard results from old requests
      if (version != _listVersion) {
        _log('loadDirectory STALE (version=$version, current=$_listVersion)');
        return;
      }

      state = state.copyWith(
        entries: entries,
        isLoading: false,
        currentPath: path,
      );

      // Remember where we are (per connection) for "open at last visited".
      final connectionId = _connectionId;
      if (connectionId != null) {
        unawaited(_lastPathStore.set(connectionId, path));
      }
    } catch (e) {
      _log('loadDirectory ERROR: $e');
      if (version != _listVersion) return;
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Navigate to subdirectory
  Future<void> navigateToDirectory(String path) async {
    await loadDirectory(path);
  }

  /// Navigate to parent directory
  Future<void> navigateUp() async {
    final parent = _getParentPath(state.currentPath);
    if (parent != state.currentPath) {
      await loadDirectory(parent);
    }
  }

  /// Change sort option
  void setSort(SortOption option, {bool? ascending}) {
    if (option == state.sortOption && ascending == null) {
      state = state.copyWith(sortAscending: !state.sortAscending);
    } else {
      state = state.copyWith(
        sortOption: option,
        sortAscending: ascending ?? true,
      );
    }
  }

  /// Toggle hidden file display
  void toggleShowHidden() {
    state = state.copyWith(showHidden: !state.showHidden);
  }

  /// Delete file or directory
  Future<bool> delete(FileEntry entry) async {
    _log('delete START (path=${entry.fullPath})');
    try {
      final sshClient = _getSshClient();
      _log('delete openSftp START');
      final sftp = await sshClient.openSftp();
      _log('delete openSftp OK');
      if (entry.isDirectory) {
        await _browserService.deleteDirectory(sftp, entry.fullPath);
      } else {
        await _browserService.deleteFile(sftp, entry.fullPath);
      }
      _log('delete operation OK');
    } catch (e) {
      _log('delete ERROR: $e');
      state = state.copyWith(error: 'Delete failed: $e');
      return false;
    }
    await loadDirectory(state.currentPath);
    return true;
  }

  /// Rename file or directory
  Future<bool> rename(FileEntry entry, String newName) async {
    _log('rename START (path=${entry.fullPath}, newName=$newName)');
    try {
      final parentDir = _getParentPath(entry.fullPath);
      final newPath = parentDir.endsWith('/')
          ? '$parentDir$newName'
          : '$parentDir/$newName';

      final sshClient = _getSshClient();
      _log('rename openSftp START');
      final sftp = await sshClient.openSftp();
      _log('rename openSftp OK');
      await _browserService.rename(sftp, entry.fullPath, newPath);
      _log('rename operation OK');
    } catch (e) {
      _log('rename ERROR: $e');
      state = state.copyWith(error: 'Rename failed: $e');
      return false;
    }
    await loadDirectory(state.currentPath);
    return true;
  }

  /// Create new folder
  Future<bool> createDirectory(String name) async {
    _log('createDirectory START (name=$name)');
    try {
      final newPath = state.currentPath.endsWith('/')
          ? '${state.currentPath}$name'
          : '${state.currentPath}/$name';

      final sshClient = _getSshClient();
      _log('createDirectory openSftp START');
      final sftp = await sshClient.openSftp();
      _log('createDirectory openSftp OK');
      await _browserService.createDirectory(sftp, newPath);
      _log('createDirectory operation OK');
    } catch (e) {
      _log('createDirectory ERROR: $e');
      state = state.copyWith(error: 'Create directory failed: $e');
      return false;
    }
    await loadDirectory(state.currentPath);
    return true;
  }

  /// Reload current directory
  Future<void> refresh() async {
    await loadDirectory(state.currentPath);
  }

  /// Downloads [entry] to a temp file and returns its local path (for opening
  /// in an external app). Throws on failure / oversize.
  Future<String> downloadToTemp(FileEntry entry) async {
    final sshClient = _getSshClient();
    final sftp = await sshClient.openSftp();
    final dir = await getTemporaryDirectory();
    final dest = File(p.join(dir.path, entry.name));
    await _browserService.downloadToFile(sftp, entry.fullPath, dest);
    return dest.path;
  }

  // --- Private methods ---

  SshClient _getSshClient() {
    final client = ref.read(sshProvider.notifier).client;
    if (client == null || !client.isConnected) {
      throw StateError('SSH connection is not available');
    }
    return client;
  }

  Future<void> _loadHomeDirectory() async {
    _log('_loadHomeDirectory START');
    try {
      final sshClient = _getSshClient();
      _log('_loadHomeDirectory openSftp START');
      final sftp = await sshClient.openSftp();
      _log('_loadHomeDirectory openSftp OK');
      String homePath;
      try {
        homePath = await _browserService.getHomeDirectory(sftp);
        _log('_loadHomeDirectory getHomeDirectory OK (path=$homePath)');
      } catch (e) {
        _log('_loadHomeDirectory getHomeDirectory ERROR: $e');
        homePath = '/';
      }
      await loadDirectory(homePath);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to get home directory: $e',
      );
    }
  }

  void _startConnectionMonitoring() {
    _connectionSub?.cancel();
    final client = ref.read(sshProvider.notifier).client;
    if (client == null) return;

    _connectionSub = client.connectionStateStream.listen((connState) {
      if (connState == SshConnectionState.disconnected ||
          connState == SshConnectionState.error) {
        state = state.copyWith(
          error: 'SSH connection lost',
          isLoading: false,
        );
      }
    });
  }

  TmuxPane? _findPaneById(TmuxState tmuxState, String paneId) {
    for (final session in tmuxState.sessions) {
      for (final window in session.windows) {
        for (final pane in window.panes) {
          if (pane.id == paneId) return pane;
        }
      }
    }
    return null;
  }

  String _getParentPath(String path) {
    if (path == '/') return '/';
    final normalized = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final lastSlash = normalized.lastIndexOf('/');
    if (lastSlash <= 0) return '/';
    return normalized.substring(0, lastSlash);
  }

  static int _sftpOpenCount = 0;
  static int _sftpCloseCount = 0;

  void _log(String message) {
    if (message.contains('openSftp OK')) _sftpOpenCount++;
    if (message.contains('sftp.close()')) _sftpCloseCount++;
    AppLog.d('[FileBrowser] $message (open=$_sftpOpenCount, close=$_sftpCloseCount, leaked=${_sftpOpenCount - _sftpCloseCount})');
  }
}

/// File browser Provider
final fileBrowserProvider =
    NotifierProvider<FileBrowserNotifier, FileBrowserState>(
  FileBrowserNotifier.new,
);
