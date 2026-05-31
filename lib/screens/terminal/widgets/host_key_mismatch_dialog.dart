import 'package:flutter/material.dart';

import '../../../services/ssh/host_key_verifier.dart';

/// Dialog that warns when the host key has changed and allows the user to choose
/// between abort or re-trust (FR-004/005).
///
/// Displays both the previously trusted fingerprint and the newly presented fingerprint.
/// Does not display any secret information (password/passphrase/private key) (FR-015).
class HostKeyMismatchDialog extends StatelessWidget {
  final SshHostKeyChangedError change;

  const HostKeyMismatchDialog({super.key, required this.change});

  /// Shows the dialog. Returns true = re-trust and continue / false or null = abort.
  static Future<bool?> show(
    BuildContext context,
    SshHostKeyChangedError change,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HostKeyMismatchDialog(change: change),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: Icon(Icons.gpp_maybe, color: theme.colorScheme.error, size: 36),
      title: const Text('Host identity changed'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The identity of ${change.host}:${change.port} does not match the '
            'one trusted previously. This can happen after a legitimate server '
            'rebuild or key rotation — but it can also indicate interception.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _FingerprintRow(
            label: 'Previously trusted',
            value: change.storedFingerprint,
          ),
          const SizedBox(height: 8),
          _FingerprintRow(
            label: 'Now presented',
            value: change.presentedFingerprint,
          ),
          const SizedBox(height: 8),
          _FingerprintRow(label: 'Key type', value: change.keyType),
          const SizedBox(height: 16),
          Text(
            'Only re-trust if you expected this change and can verify the new '
            'fingerprint out-of-band.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abort'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Re-trust'),
        ),
      ],
    );
  }
}

class _FingerprintRow extends StatelessWidget {
  final String label;
  final String value;

  const _FingerprintRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SelectableText(
          value,
          style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
      ],
    );
  }
}
