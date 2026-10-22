import 'package:collection/collection.dart';
import 'package:coverde/src/entities/coverage_line.dart';
import 'package:coverde/src/entities/coverage_rate.dart';
import 'package:coverde/src/entities/coverage_trace_entry.dart';
import 'package:coverde/src/utils/path.dart';
import 'package:meta/meta.dart';

/// {@template coverde.coverage_file}
/// Coverage for one source file.
///
/// [path] keeps the root and separator of the trace path.
/// {@endtemplate}
@immutable
final class CoverageFile {
  /// {@macro coverde.coverage_file}
  CoverageFile({
    required this.path,
    required Iterable<CoverageTraceEntry> entries,
    required Iterable<CoverageLine> lines,
  }) : entries = List<CoverageTraceEntry>.unmodifiable(entries),
       lines = List<CoverageLine>.unmodifiable(lines);

  /// The normalized source path from `SF:`.
  final String path;

  /// Record lines in trace order.
  ///
  /// An `SF:` line is a [CoverageSourceEntry]. A line the parser understands
  /// is a [CoveragePreservedEntry]. Any other non-blank line is a
  /// [CoverageUnrecognizedEntry].
  final List<CoverageTraceEntry> entries;

  /// The last segment of [path].
  String get name {
    final slash = coveragePathSlashForm(path);
    final separator = slash.lastIndexOf('/');
    if (separator == -1) return path;
    return slash.substring(separator + 1);
  }

  /// Instrumented lines from `DA:` records.
  final List<CoverageLine> lines;

  /// Instrumented lines in this file.
  int get linesFound => lines.length;

  /// Instrumented lines executed at least once.
  int get linesHit => lines.where((line) => line.hasBeenHit).length;

  /// Line coverage from 0 to 100, or null when [linesFound] is 0.
  double? get lineRate => coverageRate(hit: linesHit, found: linesFound);

  /// Writes [entries] as LCOV text.
  ///
  /// Every `SF:` line uses [path], or [sourcePath] when a caller rewrites it.
  /// [sourcePath] is normalized, so the written separator is the one that
  /// path already uses.
  String renderTrace({String? sourcePath}) {
    final writtenPath =
        sourcePath == null ? path : normalizeCoveragePath(sourcePath);
    return [
      for (final entry in entries)
        switch (entry) {
          CoverageSourceEntry() => 'SF:$writtenPath',
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
        _unrecognizedEquality.equals(
          other._unrecognizedEntries,
          _unrecognizedEntries,
        );
  }

  @override
  int get hashCode => Object.hash(
    path,
    _linesEquality.hash(lines),
    _unrecognizedEquality.hash(_unrecognizedEntries),
  );
}
