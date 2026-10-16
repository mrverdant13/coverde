import 'package:collection/collection.dart';
import 'package:coverde/src/entities/coverage_branch.dart';
import 'package:coverde/src/entities/coverage_function.dart';
import 'package:coverde/src/entities/coverage_line.dart';
import 'package:coverde/src/entities/coverage_rate.dart';
import 'package:coverde/src/entities/coverage_trace_entry.dart';
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
    required Iterable<CoverageTraceEntry> entries,
    required Iterable<CoverageLine> lines,
    required this.functions,
    required this.branches,
  }) : entries = List<CoverageTraceEntry>.unmodifiable(entries),
       lines = List<CoverageLine>.unmodifiable(lines);

  /// The source path from `SF:`, with `/` separators.
  final String path;

  /// Record lines in trace order.
  ///
  /// An `SF:` line is a [CoverageSourceEntry]. A line the parser understands
  /// is a [CoveragePreservedEntry]. Any other non-blank line is a
  /// [CoverageUnrecognizedEntry].
  final List<CoverageTraceEntry> entries;

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

  /// Writes [entries] as LCOV text.
  ///
  /// Each [CoverageSourceEntry] keeps the separator from its own path. [path]
  /// replaces every source path, and a source entry without one uses this
  /// file's path.
  String renderTrace({String? path}) {
    final replacement = path;
    return [
      for (final entry in entries)
        switch (entry) {
          CoverageSourceEntry(:final path) =>
            'SF:${replacement ?? path ?? this.path}',
          CoveragePreservedEntry(:final text) => text,
          CoverageUnrecognizedEntry(:final text) => text,
        },
    ].join('\n');
  }

  static const _linesEquality = ListEquality<CoverageLine>();
  static const _unrecognizedEquality =
      ListEquality<CoverageUnrecognizedEntry>();

  List<CoverageUnrecognizedEntry> get _unrecognizedEntries =>
      entries.whereType<CoverageUnrecognizedEntry>().toList();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CoverageFile &&
        other.path == path &&
        _linesEquality.equals(other.lines, lines) &&
        other.functions == functions &&
        other.branches == branches &&
        _unrecognizedEquality.equals(
          other._unrecognizedEntries,
          _unrecognizedEntries,
        );
  }

  @override
  int get hashCode => Object.hash(
    path,
    _linesEquality.hash(lines),
    functions,
    branches,
    _unrecognizedEquality.hash(_unrecognizedEntries),
  );
}
