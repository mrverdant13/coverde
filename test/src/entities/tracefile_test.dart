import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:cov_utils/src/entities/cov_file.dart';
import 'package:cov_utils/src/entities/tracefile.dart';
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
SF:path/to/source.${linesCount + 1}.file
${buildCovLinesEntries(linesCount + 1).map((covLineEntry) => 'DA:${covLineEntry.key},${covLineEntry.value}').join('\n')}
end_of_record''';

  final covFiles = Iterable.generate(covFilesCount, buildRawCovFileString)
      .map((s) => CovFile.parse(s));

  final tracefile = Tracefile(
    sourceFilesCovData: covFiles,
  );
  final tracefileString = Iterable.generate(
    covFilesCount,
    buildRawCovFileString,
  ).join('\n');

  test(
    '''

GIVEN two tracefile instances
├─ THAT hold the same data
WHEN they are compared with each other
THEN a positive result should be returned
''',
    () {
      // ARRANGE
      final sameTracefile = Tracefile(
        sourceFilesCovData: covFiles,
      );

      // ACT
      final valueComparisonResult = tracefile == sameTracefile;
      final hashComparisonResult = tracefile.hashCode == sameTracefile.hashCode;

      // ASSERT
      expect(valueComparisonResult, isTrue);
      expect(hashComparisonResult, isTrue);
    },
  );

  test(
    '''

GIVEN a valid string representation of a tracefile
WHEN the string is parsed
THEN a tracefile instance should be returned
''',
    () async {
      // ACT
      final result = Tracefile.parse(
        tracefileString,
      );

      // ASSERT
      expect(result, tracefile);
    },
  );

  test(
    '''

GIVEN a tracefile instance
WHEN source files coverage data is requested
THEN its actual collection of source files coverage data is returned
''',
    () async {
      // ACT
      final result = tracefile.sourceFilesCovData;

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

GIVEN a tracefile instance
WHEN its total number of hit lines is requested
THEN the actual value should be returned
''',
    () async {
      // ARRANGE
      const expectedLinesHit = (covFilesCount * (covFilesCount - 1)) / 2;

      // ACT
      final result = tracefile.linesHit;

      // ASSERT
      expect(result, expectedLinesHit);
    },
  );

  test(
    '''

GIVEN a tracefile instance
WHEN its total number of found lines is requested
THEN the actual value should be returned
''',
    () async {
      // ARRANGE
      const expectedLinesFound = (covFilesCount * (covFilesCount + 1)) / 2;

      // ACT
      final result = tracefile.linesFound;

      // ASSERT
      expect(result, expectedLinesFound);
    },
  );
}
