import 'package:path/path.dart' as p;

final _windows = p.Context(style: p.Style.windows);
final _unc = RegExp(r'^[/\\]{2}([^/\\]+)[/\\]([^/\\]+)(.*)$');
final _driveRelative = RegExp(r'^([A-Za-z]:)([^/\\].*)$');
final _driveRoot = RegExp(r'^[A-Za-z]:[/\\]');

/// A path that uses `/` separators.
///
/// `\` becomes `/`. `.`, `..`, and empty segments are removed below the
/// path root. A drive root, a drive-relative prefix, and a UNC root stay.
String normalizePosixPath(String raw) {
  final trimmed = raw.trim();
  final unc = _unc.firstMatch(trimmed);
  if (unc != null) {
    final root = '//${unc.group(1)}/${unc.group(2)}';
    final tail = _belowRoot(unc.group(3)!);
    return tail.isEmpty ? root : '$root/$tail';
  }
  final driveRelative = _driveRelative.firstMatch(trimmed);
  if (driveRelative != null) {
    final tail = p.posix.normalize(
      driveRelative.group(2)!.replaceAll(r'\', '/'),
    );
    return '${driveRelative.group(1)}$tail';
  }
  if (_driveRoot.hasMatch(trimmed)) {
    return _windows.normalize(trimmed).replaceAll(r'\', '/');
  }
  return p.posix.normalize(trimmed.replaceAll(r'\', '/'));
}

/// Normalizes [rawTail] without letting `..` remove the root above it.
String _belowRoot(String rawTail) {
  final slashed = rawTail.replaceAll(r'\', '/').replaceFirst(RegExp('^/+'), '');
  if (slashed.isEmpty) return '';
  final normalized = p.posix.normalize(slashed);
  if (normalized == '.') return '';
  final parts = normalized.split('/');
  var start = 0;
  while (start < parts.length && parts[start] == '..') {
    start++;
  }
  return parts.skip(start).join('/');
}
