import 'package:collection/collection.dart';
import 'package:coverde/src/entities/cov_base.dart';
import 'package:coverde/src/entities/cov_dir.dart';
import 'package:coverde/src/entities/cov_file.dart';
import 'package:meta/meta.dart';

/// {@template tracefile}
/// # Tracefile Data
///
/// A tracefile (often named `lcov.info`) is made up of several human-readable
/// lines of text, divided into blocks of coverage data related to different
/// source files.
/// {@endtemplate}
@immutable
class Tracefile extends CovComputable {
  /// Create a tracefile instance.
  ///
  /// {@macro tracefile}
  @visibleForTesting
  Tracefile({
    required Iterable<CovFile> sourceFilesCovData,
  }) : _sourceFilesCovData = Iterable.castFrom(sourceFilesCovData);

  /// Create a source file coverage data instance from the content string of a
  /// file coverage data block.
  ///
  /// {@macro tracefile}
  factory Tracefile.parse(String tracefileContent) {
    final filesCovDataStr = tracefileContent
        .split(CovFile.endOfRecordTag)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => '$s\n${CovFile.endOfRecordTag}');
    final sourceFilesCovData = filesCovDataStr
        .map(CovFile.parse)
        .where((fileCovData) => fileCovData.linesFound > 0);
    return Tracefile(
      sourceFilesCovData: sourceFilesCovData,
    );
  }

  final Iterable<CovFile> _sourceFilesCovData;

  /// Create a coverage tree.
  late final CovDir asTree = CovDir.tree(covFiles: sourceFilesCovData);

  /// Check if any name of the files included by this tracefile match any of the
  /// provided [patterns].
  bool includeFileThatMatchPatterns(List<String> patterns) => patterns
      .map(RegExp.new)
      .any((p) => _sourceFilesCovData.any((f) => p.hasMatch(f.source.path)));

  /// The coverage data related to the referenced source files.
  UnmodifiableListView<CovFile> get sourceFilesCovData =>
      UnmodifiableListView<CovFile>(_sourceFilesCovData);

  @override
  int get linesHit => _sourceFilesCovData.map((e) => e.linesHit).sum;

  @override
  int get linesFound => _sourceFilesCovData.map((e) => e.linesFound).sum;

  static const _sourceFilesCovDataEquality = IterableEquality<CovFile>();

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
  int get hashCode => _sourceFilesCovDataEquality.hash(_sourceFilesCovData);
}
