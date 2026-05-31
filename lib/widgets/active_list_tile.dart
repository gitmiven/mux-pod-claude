import 'package:flutter/material.dart';

/// Common ListTile that expresses active state with a left end bar
///
/// Provides a consistent active state representation in list displays of sessions/windows/panes, etc.
/// - When active: left bar with primary color + bold title + primary color
/// - When inactive: no bar + normal text
class ActiveListTile extends StatelessWidget {
  final bool isActive;
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showLeftBar;
  final Color? leftBarColor;
  final double leftBarWidth;

  const ActiveListTile({
    super.key,
    required this.isActive,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.showLeftBar = true,
    this.leftBarColor,
    this.leftBarWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final barColor = leftBarColor ?? colorScheme.primary;

    return Container(
      decoration: isActive && showLeftBar
          ? BoxDecoration(
              border: Border(
                left: BorderSide(color: barColor, width: leftBarWidth),
              ),
            )
          : null,
      child: ListTile(
        leading: leading,
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? colorScheme.primary : colorScheme.onSurface,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.38),
                ),
              )
            : null,
        trailing: trailing,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  /// Helper that returns icon color based on active state
  static Color iconColor(BuildContext context, {required bool isActive}) {
    final colorScheme = Theme.of(context).colorScheme;
    return isActive
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.6);
  }
}
