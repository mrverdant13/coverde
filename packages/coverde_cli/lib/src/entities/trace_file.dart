import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:coverde/src/entities/cov_base.dart';
import 'package:coverde/src/entities/cov_dir.dart';
import 'package:coverde/src/entities/cov_file.dart';
import 'package:meta/meta.dart';
import 'package:universal_io/io.dart';

/// {@template trace_file}
/// # Trace File Data
///
/// A trace file (often named `lcov.info`) is made up of several human-readable
/// lines of text, divided into blocks of coverage data related to different
/// source files.
/// {@endtemplate}
@immutable
class TraceFile extends CovComputable {
  /// Create a trace file instance.
  ///
  /// {@macro trace_file}
  @visibleForTesting
  TraceFile({
    required Iterable<CovFile> sourceFilesCovData,
  }) : _sourceFilesCovData = Iterable.castFrom(sourceFilesCovData);

  /// Create a source file coverage data instance from the content string of a
  /// file coverage data block.
  ///
  /// {@macro trace_file}
  ///
  /// **Note:** This method loads the entire content into memory.\
  /// For large files, consider using [parseStreaming] instead.
  factory TraceFile.parse(String traceFileContent) {
    final filesCovDataStr = traceFileContent
        .split(CovFile.endOfRecordTag)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => '$s\n${CovFile.endOfRecordTag}');
    final sourceFilesCovData = filesCovDataStr
        .map(CovFile.parse)
        .where((fileCovData) => fileCovData.linesFound > 0);
    return TraceFile(
      sourceFilesCovData: sourceFilesCovData,
    );
  }

  /// Create a trace file instance by parsing a file using streaming.
  ///
  /// This method processes the file line-by-line, which is more
  /// memory-efficient for large trace files compared to [TraceFile.parse].
  ///
  /// {@macro trace_file}
  static Future<TraceFile> parseStreaming(File file) async {
    final sourceFilesCovData = <CovFile>[];
    final lines =
        file.openRead().transform(utf8.decoder).transform(const LineSplitter());

    final currentBlockBuffer = StringBuffer();
    final completer = Completer<void>();

    late final StreamSubscription<String> linesSubscription;
    linesSubscription = lines.listen(
      (line) {
        try {
          final trimmedLine = line.trim();
          if (trimmedLine.isEmpty) return;
          currentBlockBuffer.writeln(line);

          // Check if we've reached the end of a record block
          if (trimmedLine == CovFile.endOfRecordTag) {
            final blockContent = currentBlockBuffer.toString().trim();
            if (blockContent.isNotEmpty) {
              final covFile = CovFile.parse(blockContent);
              if (covFile.linesFound > 0) sourceFilesCovData.add(covFile);
            }
            currentBlockBuffer.clear();
          }
        } catch (error, stackTrace) {
          if (completer.isCompleted) return;
          completer.completeError(error, stackTrace);
        }
      },
      onDone: () {
        final blockContent = currentBlockBuffer.toString().trim();
        if (blockContent.isNotEmpty) {
          final covFile = CovFile.parse(blockContent);
          if (covFile.linesFound > 0) sourceFilesCovData.add(covFile);
        }
        if (completer.isCompleted) return;
        completer.complete();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (completer.isCompleted) return;
        completer.completeError(error, stackTrace);
      },
      cancelOnError: true,
    );
    try {
      await completer.future;
    } finally {
      await linesSubscription.cancel();
    }

    return TraceFile(sourceFilesCovData: sourceFilesCovData);
  }

  final Iterable<CovFile> _sourceFilesCovData;

  /// Create a coverage tree.
  late final CovDir asTree = CovDir.tree(covFiles: sourceFilesCovData);

  /// Check if any name of the files included by this trace file match any of
  /// the provided [patterns].
  bool includeFileThatMatchPatterns(List<String> patterns) => patterns
      .map(RegExp.new)
      .any((p) => _sourceFilesCovData.any((f) => p.hasMatch(f.source.path)));

  /// The coverage data related to the referenced source files.
  UnmodifiableListView<CovFile> get sourceFilesCovData =>
      UnmodifiableListView<CovFile>(_sourceFilesCovData);

  /// Whether the trace file is empty.
  bool get isEmpty => _sourceFilesCovData.isEmpty;

  @override
  int get linesHit => _sourceFilesCovData.map((e) => e.linesHit).sum;

  @override
  int get linesFound => _sourceFilesCovData.map((e) => e.linesFound).sum;

  static const _sourceFilesCovDataEquality = IterableEquality<CovFile>();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TraceFile &&
        _sourceFilesCovDataEquality.equals(
          other._sourceFilesCovData,
          _sourceFilesCovData,
        );
  }

  @override
  int get hashCode => _sourceFilesCovDataEquality.hash(_sourceFilesCovData);
}
