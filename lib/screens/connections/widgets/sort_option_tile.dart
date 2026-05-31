import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../providers/connection_provider.dart';

/// Sort option tile
class SortOptionTile extends StatelessWidget {
  final String title;
  final ConnectionSortOption option;
  final ConnectionSortOption currentOption;
  final VoidCallback onTap;

  const SortOptionTile({
    super.key,
    required this.title,
    required this.option,
    required this.currentOption,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = option == currentOption;
    return ListTile(
      title: Text(
        title,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          color: isSelected ? colorScheme.primary : colorScheme.onSurface,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: colorScheme.primary, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
