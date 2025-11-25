import 'package:collection/collection.dart';
import 'package:coverde/src/entities/cov_file.dart';
import 'package:coverde/src/entities/trace_file.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

Iterable<MapEntry<int, int>> buildCovLinesEntries(int linesCount) {
  return Iterable.generate(
    linesCount,
    (idx) => MapEntry(idx + 1, idx),
  );
}

String buildRawCovFileString(int linesCount) {
  final buf = StringBuffer()
    ..writeln('SF:${path.joinAll([
          'path',
          'to',
          'source.${linesCount + 1}.file',
        ])}');
  final covLinesEntries = buildCovLinesEntries(linesCount + 1);
  for (final covLineEntry in covLinesEntries) {
    buf.writeln('DA:${covLineEntry.key},${covLineEntry.value}');
  }
  buf.writeln('end_of_record');
  return buf.toString();
}

TraceFile buildTraceFile(int covFilesCount) {
  final covFiles = Iterable.generate(covFilesCount, buildRawCovFileString)
      .map(CovFile.parse);
  final traceFile = TraceFile(
    sourceFilesCovData: covFiles,
  );
  return traceFile;
}

void main() {
  group('$TraceFile', () {
    group('isEmpty', () {
      test('| returns `true` when no source files coverage data is found', () {
        final traceFile = buildTraceFile(0);
        expect(traceFile.isEmpty, isTrue);
      });
    });

    const covFilesCount = 10;

    final covFiles = Iterable.generate(covFilesCount, buildRawCovFileString)
        .map(CovFile.parse);

    final traceFile = TraceFile(
      sourceFilesCovData: covFiles,
    );
    final traceFileString = Iterable.generate(
      covFilesCount,
      buildRawCovFileString,
    ).join('\n');

    test(
      '| supports value comparison',
      () {
        final sameTraceFile = TraceFile(
          sourceFilesCovData: covFiles,
        );

        final valueComparisonResult = traceFile == sameTraceFile;
        final hashComparisonResult =
            traceFile.hashCode == sameTraceFile.hashCode;

        expect(valueComparisonResult, isTrue);
        expect(hashComparisonResult, isTrue);
      },
    );

    test(
      '| parses valid string representation',
      () async {
        final result = TraceFile.parse(
          traceFileString,
        );

        expect(result, traceFile);
      },
    );

    test(
      'sourceFilesCovData '
      '| returns source files coverage data',
      () async {
        final result = traceFile.sourceFilesCovData;

        expect(result, isA<UnmodifiableListView<CovFile>>());
        expect(result.length, covFiles.length);
        expect(
          result,
          predicate<UnmodifiableListView<CovFile>>(
            (r) => r.foldIndexed(
              true,
              (idx, containSameElements, element) =>
                  containSameElements && element == covFiles.elementAt(idx),
            ),
          ),
        );
      },
    );

    test(
      'linesHit '
      '| returns total number of hit lines',
      () async {
        const expectedLinesHit = (covFilesCount * (covFilesCount - 1)) / 2;

        final result = traceFile.linesHit;

        expect(result, expectedLinesHit);
      },
    );

    test(
      'linesFound'
      '| returns total number of found lines',
      () async {
        const expectedLinesFound = (covFilesCount * (covFilesCount + 1)) / 2;

        final result = traceFile.linesFound;

        expect(result, expectedLinesFound);
      },
    );
  });
}
