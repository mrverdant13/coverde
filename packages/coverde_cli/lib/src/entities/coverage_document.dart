import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:coverde/src/entities/build_coverage_tree.dart';
import 'package:coverde/src/entities/coverage_directory.dart';
import 'package:coverde/src/entities/coverage_file.dart';
import 'package:coverde/src/entities/coverage_line.dart';
import 'package:coverde/src/entities/coverage_rate.dart';
import 'package:coverde/src/entities/coverage_trace_entry.dart';
import 'package:coverde/src/entities/coverage_trace_format_failure.dart';
import 'package:coverde/src/utils/path.dart';
import 'package:meta/meta.dart';
import 'package:universal_io/io.dart';

part 'parse_coverage_document.dart';

/// {@template coverde.coverage_document}
/// Line coverage parsed from an LCOV trace.
/// {@endtemplate}
@immutable
final class CoverageDocument {
  /// {@macro coverde.coverage_document}
  CoverageDocument({
    required this.traceModifiedAt,
    required Iterable<CoverageFile> files,
  }) : files = List<CoverageFile>.unmodifiable(files);

  /// Parses [trace] into a coverage document.
  ///
  /// [traceModifiedAt] is stored as given. The trace text does not carry a
  /// timestamp.
  ///
  /// Throws [CoverageTraceFormatFailure] when [trace] is not valid line
  /// coverage for this document.
  factory CoverageDocument.parse(String trace, {DateTime? traceModifiedAt}) {
    return _parseCoverageDocument(trace, traceModifiedAt: traceModifiedAt);
  }

  /// Parses [file] line by line.
  ///
  /// Records are built as each `end_of_record` arrives. The whole trace is
  /// not held as one string. A trailing record with no `end_of_record` is
  /// still parsed.
  ///
  /// Throws [CoverageTraceFormatFailure] when [file] is not valid line
  /// coverage for this document, and [FileSystemException] when [file] cannot
  /// be read.
  static Future<CoverageDocument> parseStreaming(
    File file, {
    DateTime? traceModifiedAt,
  }) {
    return _parseCoverageDocumentStreaming(
      file,
      traceModifiedAt: traceModifiedAt,
    );
  }

  /// When the trace file was last modified, if the caller knows.
  final DateTime? traceModifiedAt;

  /// Source files, in the order their records first appear in the trace.
  final List<CoverageFile> files;

  /// Whether the trace contains no coverage records.
  bool get isEmpty => files.isEmpty;

  /// Directory tree for [files].
  ///
  /// The root [CoverageDirectory.path] is the shared parent prefix, or empty
  /// when the files do not share one. Built on first use. Line totals below
  /// are summed from [files], not from this tree.
  late final CoverageDirectory tree = buildCoverageTree(files);

  /// Instrumented lines across [files].
  int get linesFound => _sum(files.map((file) => file.linesFound));

  /// Instrumented lines executed at least once.
  int get linesHit => _sum(files.map((file) => file.linesHit));

  /// Line coverage from 0 to 100, or null when [linesFound] is 0.
  double? get lineRate => coverageRate(hit: linesHit, found: linesFound);

  static const _filesEquality = ListEquality<CoverageFile>();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CoverageDocument &&
        other.traceModifiedAt == traceModifiedAt &&
        _filesEquality.equals(other.files, files);
  }

  @override
  int get hashCode => Object.hash(traceModifiedAt, _filesEquality.hash(files));
}

int _sum(Iterable<int> values) {
  var total = 0;
  for (final value in values) {
    total += value;
  }
  return total;
}
