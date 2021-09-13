import 'dart:collection';
import 'package:meta/meta.dart';

import 'package:collection/collection.dart';
import 'package:cov_utils/src/entities/source_file_cov_data.dart';

/// {@template tracefile}
/// # Tracefile Data
///
/// A tracefile (often named `lcov.info`) is made up of several human-readable
/// lines of text, divided into blocks of coverage data related to different
/// source files.
/// {@endtemplate}
@immutable
class Tracefile {
  /// Create a tracefile instance.
  ///
  /// {@macro tracefile}
  @visibleForTesting
  Tracefile({
    required Iterable<SourceFileCovData> sourceFilesCovData,
  }) : _sourceFilesCovData = Iterable.castFrom(sourceFilesCovData);

  /// Create a source file coverage data instance from the content string of a
  /// file coverage data block.
  ///
  /// {@macro tracefile}
  factory Tracefile.parse(String tracefileContent) {
    final filesCovDataStr = tracefileContent
        .split(SourceFileCovData.endOfRecordTag)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => '$s\n${SourceFileCovData.endOfRecordTag}');
    final sourceFilesCovData = filesCovDataStr.map(
      (d) => SourceFileCovData.parse(d),
    );
    return Tracefile(
      sourceFilesCovData: sourceFilesCovData,
    );
  }

  final Iterable<SourceFileCovData> _sourceFilesCovData;

  /// The coverage data related to the referenced source files.
  UnmodifiableListView<SourceFileCovData> get sourceFilesCovData =>
      UnmodifiableListView<SourceFileCovData>(_sourceFilesCovData);

  /// Number of hit lines from all referenced source files.
  int get linesHit => _sourceFilesCovData.fold(
        0,
        (linesHit, element) => linesHit += element.linesHit,
      );

  /// Number of found lines from all referenced source files.
  int get linesFound => _sourceFilesCovData.fold(
        0,
        (linesFound, element) => linesFound += element.linesFound,
      );

  /// Coverage percentage for all referenced source files.
  ///
  /// From **0.00** to **100.00**.
  double get coveragePercentage {
    var linesHit = 0;
    var linesFound = 0;
    for (final sourceFileCovData in _sourceFilesCovData) {
      linesHit += sourceFileCovData.linesHit;
      linesFound += sourceFileCovData.linesFound;
    }
    return (linesHit * 100) / linesFound;
  }

  static const _sourceFilesCovDataEquality =
      IterableEquality<SourceFileCovData>();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Tracefile &&
        _sourceFilesCovDataEquality.equals(
          other._sourceFilesCovData,
          _sourceFilesCovData,
        );
  }

  @override
  int get hashCode => _sourceFilesCovData.fold(
        0,
        (hash, sourceFileCovData) => hash ^ sourceFileCovData.hashCode,
      );
}
