import 'package:path/path.dart' as p;

/// A path that uses `/` separators.
///
/// `\` becomes `/`. `.`, `..`, and empty segments are removed the same way
/// POSIX `Context.normalize` removes them.
String normalizePosixPath(String raw) {
  return p.posix.normalize(raw.trim().replaceAll(r'\', '/'));
}
