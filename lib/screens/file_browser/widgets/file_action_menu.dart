import 'package:flutter/material.dart';

import '../../../services/sftp/file_entry.dart';
import '../../../theme/design_colors.dart';

/// Action menu for files/directories
enum FileAction {
  open,
  rename,
  delete,
}

/// BottomSheet that displays the action menu
class FileActionMenu {
  /// Displays the action menu and returns the selected action
  static Future<FileAction?> show(
    BuildContext context,
    FileEntry entry,
  ) {
    return showModalBottomSheet<FileAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FileActionMenuContent(entry: entry),
    );
  }
}

class _FileActionMenuContent extends StatelessWidget {
  final FileEntry entry;

  const _FileActionMenuContent({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? DesignColors.textPrimary : DesignColors.textPrimaryLight;
    final subtitleColor = isDark ? DesignColors.textMuted : DesignColors.textMutedLight;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: subtitleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // File info header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    entry.isDirectory ? Icons.folder : Icons.insert_drive_file,
                    color: entry.isDirectory ? DesignColors.secondary : subtitleColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _buildInfoText(),
                          style: TextStyle(color: subtitleColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 4),

            // Action list
            if (entry.isDirectory)
              _buildActionTile(
                context,
                icon: Icons.folder_open,
                label: '開く',
                action: FileAction.open,
                textColor: textColor,
              ),
            _buildActionTile(
              context,
              icon: Icons.edit,
              label: '名前を変更',
              action: FileAction.rename,
              textColor: textColor,
            ),
            _buildActionTile(
              context,
              icon: Icons.delete_outline,
              label: '削除',
              action: FileAction.delete,
              textColor: DesignColors.error,
              iconColor: DesignColors.error,
            ),
          ],
        ),
      ),
    );
  }

  String _buildInfoText() {
    final parts = <String>[entry.fullPath];
    if (!entry.isDirectory && entry.size != null) {
      parts.add(entry.formattedSize);
    }
    return parts.join('    ');
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required FileAction action,
    required Color textColor,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? textColor, size: 22),
      title: Text(
        label,
        style: TextStyle(color: textColor, fontSize: 15),
      ),
      onTap: () => Navigator.pop(context, action),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
