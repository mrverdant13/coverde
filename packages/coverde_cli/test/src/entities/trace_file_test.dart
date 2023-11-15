import 'package:collection/collection.dart';
import 'package:coverde/src/entities/cov_file.dart';
import 'package:coverde/src/entities/trace_file.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  // ARRANGE
  const covFilesCount = 10;

  Iterable<MapEntry<int, int>> buildCovLinesEntries(int linesCount) =>
      Iterable.generate(
        linesCount,
        (idx) => MapEntry(idx + 1, idx),
      );

  String buildRawCovFileString(int linesCount) => '''
SF:${path.joinAll(['path', 'to', 'source.${linesCount + 1}.file'])}
${buildCovLinesEntries(linesCount + 1).map((covLineEntry) => 'DA:${covLineEntry.key},${covLineEntry.value}').join('\n')}
end_of_record''';

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
    '''

GIVEN two trace file instances
├─ THAT hold the same data
WHEN they are compared with each other
THEN a positive result should be returned
''',
    () {
      // ARRANGE
      final sameTraceFile = TraceFile(
        sourceFilesCovData: covFiles,
      );

      // ACT
      final valueComparisonResult = traceFile == sameTraceFile;
      final hashComparisonResult = traceFile.hashCode == sameTraceFile.hashCode;

      // ASSERT
      expect(valueComparisonResult, isTrue);
      expect(hashComparisonResult, isTrue);
    },
  );

  test(
    '''

GIVEN a valid string representation of a trace file
WHEN the string is parsed
THEN a trace file instance should be returned
''',
    () async {
      // ACT
      final result = TraceFile.parse(
        traceFileString,
      );

      // ASSERT
      expect(result, traceFile);
    },
  );

  test(
    '''

GIVEN a trace file instance
WHEN source files coverage data is requested
THEN its actual collection of source files coverage data is returned
''',
    () async {
      // ACT
      final result = traceFile.sourceFilesCovData;

      // ASSERT

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
    '''

GIVEN a trace file instance
WHEN its total number of hit lines is requested
THEN the actual value should be returned
''',
    () async {
      // ARRANGE
      const expectedLinesHit = (covFilesCount * (covFilesCount - 1)) / 2;

      // ACT
      final result = traceFile.linesHit;

      // ASSERT
      expect(result, expectedLinesHit);
    },
  );

  test(
    '''

GIVEN a trace file instance
WHEN its total number of found lines is requested
THEN the actual value should be returned
''',
    () async {
      // ARRANGE
      const expectedLinesFound = (covFilesCount * (covFilesCount + 1)) / 2;

      // ACT
      final result = traceFile.linesFound;

      // ASSERT
      expect(result, expectedLinesFound);
    },
  );
}
