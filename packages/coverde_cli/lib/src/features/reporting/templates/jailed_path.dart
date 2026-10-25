import 'package:coverde/src/features/reporting/failures/coverage_report_failure.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:universal_io/io.dart';

/// Resolves [relativePath] inside [rootDirectory].
///
/// Throws [CoverageReportPathFailure] when [relativePath] is absolute, empty,
/// or leaves [rootDirectory]. An existing link on the path that resolves
/// outside [rootDirectory] leaves it too.
///
/// [canonicalizeExisting] replaces file-system resolution for an existing
/// path. Tests use it for a link target that this operating system cannot
/// create.
String resolveInsideRoot({
  required String rootDirectory,
  required String relativePath,
  required String description,
  @visibleForTesting String Function(String path)? canonicalizeExisting,
}) {
  final root = path.normalize(path.absolute(rootDirectory));
  final normalized = relativePath.trim().replaceAll(r'\', '/');
  if (normalized.isEmpty || normalized.endsWith('/')) {
    throw CoverageReportPathFailure(
      readableMessage: '$description `$relativePath` is not a file path.',
    );
  }
  if (normalized.startsWith('/') || path.isAbsolute(relativePath)) {
    throw CoverageReportPathFailure(
      readableMessage: '$description `$relativePath` must be relative.',
    );
  }
  final segments = normalized.split('/');
  if (segments.any((segment) => segment.isEmpty || segment == '..')) {
    throw CoverageReportPathFailure(
      readableMessage: '$description `$relativePath` leaves its directory.',
    );
  }
  final resolved = path.normalize(
    path.join(root, path.joinAll(segments.where((segment) => segment != '.'))),
  );
  if (!path.equals(resolved, root) && !path.isWithin(root, resolved)) {
    // Segment checks already reject `..`. This remains if normalization
    // still leaves the root.
    // coverage:ignore-start
    throw CoverageReportPathFailure(
      readableMessage: '$description `$relativePath` leaves its directory.',
    );
    // coverage:ignore-end
  }
  if (path.equals(resolved, root)) {
    throw CoverageReportPathFailure(
      readableMessage: '$description `$relativePath` is not a file path.',
    );
  }
  _rejectLinkedEscape(
    root: root,
    resolved: resolved,
    relativePath: relativePath,
    description: description,
    canonicalizeExisting: canonicalizeExisting ?? _canonicalizeOnDisk,
  );
  return resolved;
}

String _canonicalizeOnDisk(String filePath) {
  return File(filePath).resolveSymbolicLinksSync();
}

void _rejectLinkedEscape({
  required String root,
  required String resolved,
  required String relativePath,
  required String description,
  required String Function(String path) canonicalizeExisting,
}) {
  final canonicalRoot = _canonicalExisting(
    filePath: root,
    relativePath: relativePath,
    description: description,
    canonicalizeExisting: canonicalizeExisting,
  );
  if (canonicalRoot == null) return;
  var lexical = root;
  var canonical = canonicalRoot;
  for (final segment in path.split(path.relative(resolved, from: root))) {
    lexical = path.join(lexical, segment);
    final next = _canonicalExisting(
      filePath: lexical,
      relativePath: relativePath,
      description: description,
      canonicalizeExisting: canonicalizeExisting,
    );
    if (next == null) {
      _requireInside(
        root: canonicalRoot,
        candidate: canonical,
        relativePath: relativePath,
        description: description,
      );
      return;
    }
    _requireInside(
      root: canonicalRoot,
      candidate: next,
      relativePath: relativePath,
      description: description,
    );
    canonical = next;
  }
}

String? _canonicalExisting({
  required String filePath,
  required String relativePath,
  required String description,
  required String Function(String path) canonicalizeExisting,
}) {
  if (FileSystemEntity.typeSync(filePath, followLinks: false) ==
      FileSystemEntityType.notFound) {
    return null;
  }
  try {
    return path.normalize(canonicalizeExisting(filePath));
  } on FileSystemException {
    throw CoverageReportPathFailure(
      readableMessage: '$description `$relativePath` leaves its directory.',
    );
  }
}

void _requireInside({
  required String root,
  required String candidate,
  required String relativePath,
  required String description,
}) {
  if (path.equals(root, candidate) || path.isWithin(root, candidate)) return;
  throw CoverageReportPathFailure(
    readableMessage: '$description `$relativePath` leaves its directory.',
  );
}

/// The `/`-separated path of [resolvedPath] relative to [rootDirectory].
String relativeReportPath({
  required String rootDirectory,
  required String resolvedPath,
}) {
  return path
      .relative(
        path.normalize(resolvedPath),
        from: path.normalize(path.absolute(rootDirectory)),
      )
      .replaceAll(r'\', '/');
}

/// The `../` prefix from a report file back to the destination root.
///
/// [relativePath] uses `/`. The result is empty for a file in the root and
/// ends with `/` otherwise, so it can be prefixed to a root asset name.
String pathToRootPrefix(String relativePath) {
  final depth = relativePath.split('/').length - 1;
  if (depth <= 0) return '';
  return '${List<String>.filled(depth, '..').join('/')}/';
}
