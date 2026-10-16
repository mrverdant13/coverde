import 'package:collection/collection.dart';
import 'package:coverde/src/features/reporting/models/coverage_branch.dart';
import 'package:coverde/src/features/reporting/models/coverage_function.dart';
import 'package:coverde/src/features/reporting/models/coverage_line.dart';
import 'package:coverde/src/features/reporting/models/coverage_rate.dart';
import 'package:meta/meta.dart';

/// {@template coverde.coverage_file}
/// Coverage for one source file.
///
/// [path] uses `/` separators, including when the trace was produced on
/// Windows.
/// {@endtemplate}
@immutable
final class CoverageFile {
  /// {@macro coverde.coverage_file}
  CoverageFile({
    required this.path,
    required this.raw,
    required Iterable<CoverageLine> lines,
    required this.functions,
    required this.branches,
  }) : lines = List<CoverageLine>.unmodifiable(lines);

  /// The source path from `SF:`, with `/` separators.
  final String path;

  /// The original LCOV record, including `end_of_record`.
  ///
  /// `SF:` still has the path as it appeared in the trace.
  final String raw;

  /// The last segment of [path].
  String get name {
    final slash = path.lastIndexOf('/');
    if (slash == -1) return path;
    return path.substring(slash + 1);
  }

  /// Instrumented lines from `DA:` records.
  final List<CoverageLine> lines;

  /// Function coverage, or null when the trace has no function records.
  final CoverageFunctions? functions;

  /// Branch coverage, or null when the trace has no branch records.
  final CoverageBranches? branches;

  /// Instrumented lines in this file.
  int get linesFound => lines.length;

  /// Instrumented lines executed at least once.
  int get linesHit => lines.where((line) => line.hits > 0).length;

  /// Line coverage from 0 to 100, or null when [linesFound] is 0.
  double? get lineRate => coverageRate(hit: linesHit, found: linesFound);

  /// Function coverage from 0 to 100.
  ///
  /// Null when [functions] is null or no functions were found.
  double? get functionRate =>
      optionalCoverageRate(hit: functions?.hit, found: functions?.found);

  /// Branch coverage from 0 to 100.
  ///
  /// Null when [branches] is null or no branches were found.
  double? get branchRate =>
      optionalCoverageRate(hit: branches?.hit, found: branches?.found);

  static const _linesEquality = ListEquality<CoverageLine>();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CoverageFile &&
        other.path == path &&
        other.raw == raw &&
        _linesEquality.equals(other.lines, lines) &&
        other.functions == functions &&
        other.branches == branches;
  }

  @override
  int get hashCode =>
      Object.hash(path, raw, _linesEquality.hash(lines), functions, branches);
}
