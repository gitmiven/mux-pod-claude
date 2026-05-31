import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../providers/active_session_provider.dart';
import '../../../providers/connection_provider.dart';
import '../../../services/keychain/secure_storage.dart';
import '../../../services/ssh/ssh_client.dart';
import '../../../services/tmux/tmux_commands.dart';
import '../../../services/tmux/tmux_parser.dart';
import '../../../theme/design_colors.dart';
import '../../../services/logging/app_log.dart';
import 'new_session_dialog.dart';

/// Connection card (expandable, tmux session display)
class ConnectionCard extends ConsumerStatefulWidget {
  final Connection connection;
  final void Function(String? sessionName) onConnect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ConnectionCard({
    super.key,
    required this.connection,
    required this.onConnect,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  ConsumerState<ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends ConsumerState<ConnectionCard> {
  bool _isExpanded = false;
  bool _isLoadingSessions = false;
  List<TmuxSession> _sessions = [];
  String? _sessionError;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    // Get session info for this connection from active sessions
    final activeSessionsState = ref.watch(activeSessionsProvider);
    final activeSessions =
        activeSessionsState.getSessionsForConnection(widget.connection.id);
    final hasActiveSessions = activeSessions.isNotEmpty;

    // Connection status determination (check if there are active sessions or lastConnectedAt)
    final isConnected = hasActiveSessions || widget.connection.lastConnectedAt != null;
    final statusColor = hasActiveSessions
        ? DesignColors.success
        : (isConnected ? Colors.orange : (isDark ? DesignColors.textMuted : DesignColors.textMutedLight));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? DesignColors.surfaceDark : DesignColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? DesignColors.borderDark : DesignColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Card Header
          InkWell(
            onTap: () => _toggleExpand(),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Status Icon
                  Stack(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: hasActiveSessions
                              ? (isDark ? DesignColors.connectingCardDark : DesignColors.connectingCardLight)
                              : (isDark ? DesignColors.borderDark : DesignColors.borderLight),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: hasActiveSessions
                                ? (isDark ? DesignColors.connectingCardBorderDark : DesignColors.connectingCardBorderLight)
                                : Colors.transparent,
                          ),
                        ),
                        child: Icon(
                          Icons.dns,
                          size: 20,
                          color: hasActiveSessions
                              ? colorScheme.primary
                              : (isDark ? DesignColors.textSecondary : DesignColors.textSecondaryLight),
                        ),
                      ),
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? DesignColors.surfaceDark : DesignColors.surfaceLight,
                              width: 2,
                            ),
                            boxShadow: hasActiveSessions
                                ? [
                                    BoxShadow(
                                      color: statusColor.withValues(alpha: 0.6),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Connection Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.connection.name,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.connection.host} • ${widget.connection.username}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: isDark ? DesignColors.textMuted : DesignColors.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Expand Icon
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: isDark ? DesignColors.textMuted : DesignColors.textMutedLight,
                  ),
                ],
              ),
            ),
          ),
          // Expanded Content - Sessions List
          if (_isExpanded) _buildExpandedContent(activeSessions, isDark, colorScheme),
        ],
      ),
    );
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    // Fetch session info when expanding
    if (_isExpanded && _sessions.isEmpty && !_isLoadingSessions) {
      _fetchSessions();
    }
  }

  Future<void> _fetchSessions() async {
    setState(() {
      _isLoadingSessions = true;
      _sessionError = null;
    });

    try {
      final connection = widget.connection;
      final storage = SecureStorageService();

      // Get authentication options
      SshConnectOptions options;
      if (connection.authMethod == 'key' && connection.keyId != null) {
        final privateKey = await storage.getPrivateKey(connection.keyId!);
        final passphrase = await storage.getPassphrase(connection.keyId!);
        options = SshConnectOptions(privateKey: privateKey, passphrase: passphrase, tmuxPath: connection.tmuxPath);
      } else {
        final password = await storage.getPassword(connection.id);
        options = SshConnectOptions(password: password, tmuxPath: connection.tmuxPath);
      }

      // Connect via SSH and get session list
      final sshClient = SshClient();
      await sshClient.connect(
        host: connection.host,
        port: connection.port,
        username: connection.username,
        options: options,
      );

      final cmd = TmuxCommands.listSessions();
      AppLog.d('_fetchSessions: tmuxPath=${sshClient.tmuxPath}, cmd="$cmd"');
      final result = await sshClient.execWithExitCode(cmd);
      AppLog.d('_fetchSessions: stdout="${result.stdout.trim()}", stderr="${result.stderr.trim()}", exitCode=${result.exitCode}');
      if (result.exitCode != null && result.exitCode != 0) {
        throw SshConnectionError(
          result.stderr.isNotEmpty ? result.stderr.trim() : 'tmux command failed (exit code: ${result.exitCode})',
        );
      }
      final sessions = TmuxParser.parseSessions(result.stdout);
      AppLog.d('_fetchSessions: parsed ${sessions.length} sessions');

      // Disconnect
      await sshClient.disconnect();

      if (!mounted) return;

      setState(() {
        _sessions = sessions;
        _isLoadingSessions = false;
      });

      // Update ActiveSessionsProvider
      ref.read(activeSessionsProvider.notifier).updateSessionsForConnection(
            connectionId: connection.id,
            connectionName: connection.name,
            host: connection.host,
            tmuxSessions: sessions,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSessions = false;
        _sessionError = e.toString();
      });
    }
  }

  Widget _buildExpandedContent(List<ActiveSession> activeSessions, bool isDark, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15161C) : const Color(0xFFF8F9FA),
        border: Border(top: BorderSide(color: isDark ? DesignColors.borderDark : DesignColors.borderLight)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sessions Section Header with Reload Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  'ACTIVE SESSIONS',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? DesignColors.textMuted : DesignColors.textMutedLight,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: Icon(
                      Icons.refresh,
                      color: isDark ? DesignColors.textMuted : DesignColors.textMutedLight,
                    ),
                    onPressed: _isLoadingSessions ? null : _fetchSessions,
                    tooltip: 'Reload sessions',
                  ),
                ),
              ],
            ),
          ),
          // Sessions List
          if (_isLoadingSessions)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_sessionError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _sessionError!,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: DesignColors.error,
                ),
              ),
            )
          else if (_sessions.isEmpty && activeSessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'No tmux sessions found',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: isDark ? DesignColors.textMuted : DesignColors.textMutedLight,
                ),
              ),
            )
          else
            // Session list (use _sessions or activeSessions)
            ..._buildSessionItems(isDark, colorScheme),
          // New Session Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: OutlinedButton.icon(
              onPressed: _showNewSessionDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Session'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.primary.withValues(alpha: 0.8),
                side: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  style: BorderStyle.solid,
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                minimumSize: const Size(double.infinity, 0),
              ),
            ),
          ),
          Divider(color: isDark ? DesignColors.borderDark : DesignColors.borderLight, height: 1),
          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? DesignColors.textSecondary : DesignColors.textSecondaryLight,
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: DesignColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showNewSessionDialog() async {
    final sessionName = await showDialog<String>(
      context: context,
      builder: (context) => NewSessionDialog(
        existingSessionNames: _sessions.map((s) => s.name).toList(),
      ),
    );

    if (sessionName != null && sessionName.isNotEmpty) {
      widget.onConnect(sessionName);
    }
  }

  List<Widget> _buildSessionItems(bool isDark, ColorScheme colorScheme) {
    // Use _sessions (fetch result)
    final sessions = _sessions;
    if (sessions.isEmpty) return [];

    return sessions.map((session) {
      final isAttached = session.attached;
      return InkWell(
        onTap: () => widget.onConnect(session.name),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.terminal,
                size: 16,
                color: isAttached ? colorScheme.primary : (isDark ? DesignColors.textMuted : DesignColors.textMutedLight),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${session.windowCount} windows',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: isDark ? DesignColors.textMuted : DesignColors.textMutedLight,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isAttached
                      ? (isDark ? DesignColors.connectedCardDark.withValues(alpha: 0.5) : DesignColors.connectedCardLight)
                      : (isDark ? DesignColors.borderDark : DesignColors.borderLight),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isAttached
                        ? (isDark ? DesignColors.connectedCardBorderDark.withValues(alpha: 0.7) : DesignColors.connectedCardBorderLight)
                        : (isDark ? DesignColors.borderDark : DesignColors.borderLight),
                  ),
                ),
                child: Text(
                  isAttached ? 'Attached' : 'Detached',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isAttached
                        ? (isDark ? DesignColors.connectedCardTextDark : DesignColors.connectedCardTextLight)
                        : (isDark ? DesignColors.textMuted : DesignColors.textMutedLight),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}
