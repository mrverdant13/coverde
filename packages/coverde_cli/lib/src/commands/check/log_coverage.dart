import 'package:collection/collection.dart';
import 'package:coverde/src/commands/report/failures.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/utils/path.dart';
import 'package:io/ansi.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:universal_io/io.dart';

/// Prints the coverage [document] the way `coverde value` did.
///
/// [FileCoverageLogLevel.lineContent] reads each source file that has an
/// uncovered line and throws when that file cannot be opened.
void logCoverage({
  required Logger logger,
  required CoverageDocument document,
  required FileCoverageLogLevel fileCoverageLogLevel,
}) {
  switch (fileCoverageLogLevel) {
    case FileCoverageLogLevel.none:
      break;
    case FileCoverageLogLevel.overview:
      for (final file in document.files) {
        logger.info(file.coverageDataString);
      }
    case FileCoverageLogLevel.lineNumbers:
      for (final file in document.files) {
        logger.info(file.coverageDataString);
        final uncoveredLineNumbers = file.uncoveredLineNumbers;
        if (uncoveredLineNumbers.isNotEmpty) {
          final message = 'UNCOVERED: ${uncoveredLineNumbers.join(', ')}';
          logger.info('└ ${wrapWith(message, [red, styleBold])}');
        }
      }
    case FileCoverageLogLevel.lineContent:
      for (final file in document.files) {
        logger.info(file.coverageDataString);
        if (file.uncoveredLineNumbers.isEmpty) continue;
        final sourceLines = () {
          if (!hostCanResolveCoveragePath(
            file.path,
            windowsHost: Platform.isWindows,
          )) {
            throw CoverdeReportUnresolvedCoveragePathFailure(
              sourcePath: file.path,
            );
          }
          final source = File(file.path).absolute;
          try {
            return source.readAsLinesSync();
          } on FileSystemException catch (exception, stackTrace) {
            Error.throwWithStackTrace(
              CoverdeReportFileReadFailure.fromFileSystemException(
                filePath: source.path,
                exception: exception,
              ),
              stackTrace,
            );
          }
        }();
        final sourceLinesCount = sourceLines.length;
        final lineNumberColumnWidth = '$sourceLinesCount'.length;
        final uncoveredLineRanges = file.uncoveredLineRanges(
          sourceLines: sourceLines,
        );
        final indexedUncoveredLineRanges = uncoveredLineRanges.indexed;
        for (final (index, uncoveredLineRange) in indexedUncoveredLineRanges) {
          if (index > 0) {
            logger.info('├   ${'•' * lineNumberColumnWidth} | •••');
          }
          for (final lineWithStatus in uncoveredLineRange) {
            final FileLineCoverageDetails(:lineNumber, :content, :status) =
                lineWithStatus;
            final styles = switch (status) {
              FileLineCoverageStatus.covered => [green, styleBold],
              FileLineCoverageStatus.uncovered => [red, styleBold],
              FileLineCoverageStatus.neutral => <AnsiCode>[],
            };
            final markerSegment = wrapWith(status.marker, styles);
            final lineNumberSegment = wrapWith(
              '$lineNumber'.padLeft(lineNumberColumnWidth),
              styles,
            );
            final contentSegment = wrapWith(content, styles);
            logger.info(
              '├ $markerSegment $lineNumberSegment | $contentSegment',
            );
          }
        }
        logger.info('');
      }
  }
  if (fileCoverageLogLevel != FileCoverageLogLevel.none) logger.info('');

  final lineRate = document.lineRate;
  final summary = lineRate == null
      ? 'n/a - ${document.linesHit}/${document.linesFound}'
      : '${lineRate.toStringAsFixed(2)}% - '
            '${document.linesHit}/${document.linesFound}';
  logger
    ..info(wrapWith('GLOBAL:', [blue, styleBold]))
    ..info(wrapWith(summary, [blue, styleBold]));
}

extension on CoverageFile {
  String get coverageDataString {
    final rate = lineRate;
    if (rate == null) return '$path (n/a - $linesHit/$linesFound)';
    final color = rate < 100 ? lightRed : lightGreen;
    final summary = '(${rate.toStringAsFixed(2)}% - $linesHit/$linesFound)';
    return '$path ${color.wrap(summary)}';
  }

  Iterable<int> get uncoveredLineNumbers {
    return lines.where((line) => !line.hasBeenHit).map((line) => line.number);
  }

  Iterable<Iterable<FileLineCoverageDetails>> uncoveredLineRanges({
    required Iterable<String> sourceLines,
  }) {
    const maxGap = 5;
    const surroundingLines = 2;
    final sourceLinesCount = sourceLines.length;
    final ranges = lines
        .where((line) => !line.hasBeenHit)
        .map((line) => line.number)
        .splitBetween((a, b) => b - a > maxGap)
        .map(
          (group) => (
            start: (group.first - surroundingLines).clamp(1, sourceLinesCount),
            end: (group.last + surroundingLines).clamp(1, sourceLinesCount),
          ),
        )
        .map((range) {
          final rangeLines = <FileLineCoverageDetails>[];
          for (
            var lineNumber = range.start;
            lineNumber <= range.end;
            lineNumber++
          ) {
            final content = sourceLines.elementAt(lineNumber - 1);
            final covLine = lines.singleWhereOrNull(
              (line) => line.number == lineNumber,
            );
            final status = switch (covLine?.hasBeenHit) {
              null => FileLineCoverageStatus.neutral,
              true => FileLineCoverageStatus.covered,
              false => FileLineCoverageStatus.uncovered,
            };
            rangeLines.add(
              FileLineCoverageDetails(
                lineNumber: lineNumber,
                content: content,
                status: status,
              ),
            );
          }
          return rangeLines;
        });
    return ranges;
  }
}
