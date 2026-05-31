import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shows the recent-commands picker: a modal list of [commands] (most-recent
/// first). Tapping one closes the sheet and invokes [onSelected]. Shared by the
/// command popup and the special-keys-bar history button so behaviour matches.
void showRecentCommandsSheet(
  BuildContext context, {
  required List<String> commands,
  required void Function(String command) onSelected,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.history, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Recent commands',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (commands.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No recent commands yet',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: commands.length,
                itemBuilder: (context, index) {
                  final cmd = commands[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      cmd,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(fontSize: 13),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onSelected(cmd);
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
