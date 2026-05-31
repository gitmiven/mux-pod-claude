import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shows the recent-commands picker. Tapping an entry closes the sheet and calls
/// [onSelected]. Shared by the command popup and the special-keys-bar history
/// button so behaviour matches.
///
/// [fallback] is shown immediately (and used if [load] yields nothing). When
/// [load] is provided it is awaited with a loading state — used to fetch Claude
/// Code's prompt history over SSH, with [fallback] (the app-recorded history) as
/// the safety net.
void showRecentCommandsSheet(
  BuildContext context, {
  List<String> fallback = const [],
  Future<List<String>> Function()? load,
  required void Function(String command) onSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => _RecentCommandsSheet(
      fallback: fallback,
      load: load,
      onSelected: (cmd) {
        Navigator.pop(sheetContext);
        onSelected(cmd);
      },
    ),
  );
}

class _RecentCommandsSheet extends StatefulWidget {
  final List<String> fallback;
  final Future<List<String>> Function()? load;
  final void Function(String command) onSelected;

  const _RecentCommandsSheet({
    required this.fallback,
    required this.load,
    required this.onSelected,
  });

  @override
  State<_RecentCommandsSheet> createState() => _RecentCommandsSheetState();
}

class _RecentCommandsSheetState extends State<_RecentCommandsSheet> {
  late List<String> _commands = widget.fallback;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final load = widget.load;
    if (load != null) {
      _loading = true;
      load().then((list) {
        if (!mounted) return;
        setState(() {
          _commands = list.isNotEmpty ? list : widget.fallback;
          _loading = false;
        });
      }).catchError((_) {
        if (!mounted) return;
        setState(() {
          _commands = widget.fallback;
          _loading = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
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
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_commands.isEmpty)
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
                itemCount: _commands.length,
                itemBuilder: (context, index) {
                  final cmd = _commands[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      cmd,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(fontSize: 13),
                    ),
                    onTap: () => widget.onSelected(cmd),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
