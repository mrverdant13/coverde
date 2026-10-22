final _unc = RegExp(r'^[/\\]{2}([^/\\]+)[/\\]([^/\\]+)(.*)$');
final _driveRelative = RegExp(r'^([A-Za-z]:)([^/\\].*)$');
final _driveRoot = RegExp(r'^([A-Za-z]:)[/\\](.*)$');
final _rooted = RegExp(r'^([/\\])(.*)$');
final _bareDrive = RegExp(r'^[A-Za-z]:$');
final _separators = RegExp(r'[/\\]');

/// The root of a coverage source path.
enum CoveragePathRoot {
  /// No drive, UNC root, or leading slash.
  relative,

  /// A leading `/` that is not a UNC root.
  posixAbsolute,

  /// A drive root, such as `C:/` or `C:\`.
  drive,

  /// A path relative to the current directory on a drive, such as `C:a.dart`.
  driveRelative,

  /// A UNC root, such as `//server/share` or `\\server\share`.
  unc,
}

/// A coverage path normalized below its own root.
///
/// `.`, `..`, and empty segments are removed below that root. A drive root,
/// a drive-relative prefix, and a UNC root stay. The separator is the one
/// [raw] already uses. When both `\` and `/` appear, the first of those two
/// is kept and the other is rewritten to match it.
String normalizeCoveragePath(String raw) {
  final trimmed = raw.trim();
  final separator = _separator(trimmed);
  final unc = _unc.firstMatch(trimmed);
  if (unc != null) {
    final sep = separator!;
    final root = '$sep$sep${unc.group(1)}$sep${unc.group(2)}';
    final tail = _parts(unc.group(3)!, keepLeadingParent: false);
    if (tail.isEmpty) return root;
    return '$root$sep${tail.join(sep)}';
  }
  final driveRelative = _driveRelative.firstMatch(trimmed);
  if (driveRelative != null) {
    final tail = _parts(driveRelative.group(2)!, keepLeadingParent: true);
    final prefix = driveRelative.group(1)!;
    // `C:src/..` is still the current directory on that drive.
    if (tail.isEmpty) return '$prefix.';
    return '$prefix${tail.join(separator ?? '/')}';
  }
  final driveRoot = _driveRoot.firstMatch(trimmed);
  if (driveRoot != null) {
    final sep = separator!;
    final tail = _parts(driveRoot.group(2)!, keepLeadingParent: false);
    final prefix = driveRoot.group(1)!;
    if (tail.isEmpty) return '$prefix$sep';
    return '$prefix$sep${tail.join(sep)}';
  }
  final rooted = _rooted.firstMatch(trimmed);
  if (rooted != null) {
    final sep = separator!;
    final tail = _parts(rooted.group(2)!, keepLeadingParent: false);
    if (tail.isEmpty) return sep;
    return '$sep${tail.join(sep)}';
  }
  final tail = _parts(trimmed, keepLeadingParent: true);
  if (tail.isEmpty) return '.';
  return tail.join(separator ?? '/');
}

/// [path] with `\` written as `/`.
///
/// Splits, globs, and the directory tree use this so `\` is a separator on
/// every host. The stored coverage path keeps the separator it already had.
String coveragePathSlashForm(String path) => path.replaceAll(r'\', '/');

/// The root class of [raw].
CoveragePathRoot coveragePathRoot(String raw) {
  final normalized = normalizeCoveragePath(raw);
  if (_unc.hasMatch(normalized)) return CoveragePathRoot.unc;
  if (_driveRelative.hasMatch(normalized)) {
    return CoveragePathRoot.driveRelative;
  }
  if (_driveRoot.hasMatch(normalized) || _bareDrive.hasMatch(normalized)) {
    return CoveragePathRoot.drive;
  }
  if (normalized.startsWith('/')) return CoveragePathRoot.posixAbsolute;
  return CoveragePathRoot.relative;
}

/// Whether [path] names a file the host can open.
///
/// Relative paths can. A Windows root cannot on a POSIX host. A POSIX
/// absolute path cannot on a Windows host.
bool hostCanResolveCoveragePath(String path, {required bool windowsHost}) {
  return switch (coveragePathRoot(path)) {
    CoveragePathRoot.relative => true,
    CoveragePathRoot.posixAbsolute => !windowsHost,
    CoveragePathRoot.drive ||
    CoveragePathRoot.driveRelative ||
    CoveragePathRoot.unc => windowsHost,
  };
}

/// The first of `\` and `/` in [path], or null when it has neither.
String? _separator(String path) {
  final backslash = path.indexOf(r'\');
  final slash = path.indexOf('/');
  if (backslash < 0 && slash < 0) return null;
  if (backslash < 0) return '/';
  if (slash < 0) return r'\';
  return backslash < slash ? r'\' : '/';
}

/// The segments of [raw] below its root.
///
/// Empty segments and `.` are dropped. `..` pops a segment. When
/// [keepLeadingParent] is false, `..` cannot remove the root above [raw].
List<String> _parts(String raw, {required bool keepLeadingParent}) {
  final out = <String>[];
  for (final part in raw.split(_separators)) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (out.isNotEmpty && out.last != '..') {
        out.removeLast();
      } else if (keepLeadingParent) {
        out.add('..');
      }
      continue;
    }
    out.add(part);
  }
  return out;
}
