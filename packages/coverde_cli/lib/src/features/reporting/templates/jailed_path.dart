import 'package:coverde/src/features/reporting/failures/coverage_report_failure.dart';
import 'package:path/path.dart' as path;

/// Resolves [relativePath] inside [rootDirectory].
///
/// Throws [CoverageReportPathFailure] when [relativePath] is absolute, empty,
/// or leaves [rootDirectory].
String resolveInsideRoot({
  required String rootDirectory,
  required String relativePath,
  required String description,
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
  return resolved;
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
