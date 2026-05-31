/// A class that holds tmux version information and determines feature compatibility
class TmuxVersionInfo {
  final int major;
  final int minor;

  const TmuxVersionInfo(this.major, this.minor);

  /// Parses a version string in the format "tmux 3.4" or "tmux 2.9a"
  /// Returns null if parsing fails
  static TmuxVersionInfo? parse(String versionOutput) {
    final match = RegExp(r'tmux\s+(\d+)\.(\d+)').firstMatch(versionOutput);
    if (match == null) return null;
    return TmuxVersionInfo(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
    );
  }

  /// resize-window -x -y was added in tmux 2.9+
  bool get supportsResizeWindow => major > 2 || (major == 2 && minor >= 9);

  /// resize-pane -x -y was added in tmux 1.7+ (effectively supported in all versions)
  bool get supportsResizePaneToSize => major > 1 || (major == 1 && minor >= 7);

  @override
  String toString() => 'tmux $major.$minor';

  @override
  bool operator ==(Object other) =>
      other is TmuxVersionInfo && major == other.major && minor == other.minor;

  @override
  int get hashCode => Object.hash(major, minor);
}
