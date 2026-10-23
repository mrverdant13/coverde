import 'package:collection/collection.dart';
import 'package:coverde/src/entities/coverage_file.dart';
import 'package:coverde/src/utils/coverage.dart';
import 'package:meta/meta.dart';

/// {@template coverde.coverage_directory}
/// One directory in the coverage tree.
///
/// [path] is empty when the files in a root do not share a parent. A
/// single-child chain collapses into one node. Child directories keep the
/// order of their first file in the trace.
/// {@endtemplate}
@immutable
final class CoverageDirectory {
  /// {@macro coverde.coverage_directory}
  CoverageDirectory({
    required this.path,
    required Iterable<CoverageDirectory> directories,
    required Iterable<CoverageFile> files,
  }) : directories = List<CoverageDirectory>.unmodifiable(directories),
       files = List<CoverageFile>.unmodifiable(files);

  /// The directory path, using the coverage-path separator rules.
  final String path;

  /// The last segment of [path], or empty when [path] is empty or `/`.
  String get name {
    if (path.isEmpty) return '';
    final slash = path.lastIndexOf('/');
    if (slash == -1) return path;
    return path.substring(slash + 1);
  }

  /// Immediate child directories, in the order they first appear in the trace.
  final List<CoverageDirectory> directories;

  /// Source files whose parent directory is [path], in trace order.
  final List<CoverageFile> files;

  /// Instrumented lines in this directory and its descendants.
  late final int linesFound = _sum(
    directories.map((directory) => directory.linesFound),
    files.map((file) => file.linesFound),
  );

  /// Instrumented lines executed at least once.
  late final int linesHit = _sum(
    directories.map((directory) => directory.linesHit),
    files.map((file) => file.linesHit),
  );

  /// Line coverage from 0 to 100, or null when [linesFound] is 0.
  double? get lineRate => coverageRate(hit: linesHit, found: linesFound);

  static const _directoriesEquality = ListEquality<CoverageDirectory>();
  static const _filesEquality = ListEquality<CoverageFile>();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CoverageDirectory &&
        other.path == path &&
        _directoriesEquality.equals(other.directories, directories) &&
        _filesEquality.equals(other.files, files);
  }

  @override
  int get hashCode => Object.hash(
    path,
    _directoriesEquality.hash(directories),
    _filesEquality.hash(files),
  );
}

int _sum(Iterable<int> left, Iterable<int> right) {
  var total = 0;
  for (final value in left) {
    total += value;
  }
  for (final value in right) {
    total += value;
  }
  return total;
}
