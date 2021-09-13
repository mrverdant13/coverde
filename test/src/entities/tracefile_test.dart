import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:cov_utils/src/entities/source_file_cov_data.dart';
import 'package:cov_utils/src/entities/tracefile.dart';
import 'package:test/test.dart';

void main() {
  // ARRANGE
  const sourceFilesCount = 10;
  String buildSourceFile(int index) => 'lib/file_$index.dart';
  String buildSourceFilesCovDataString(int idx) => '''
${SourceFileCovData.sourceFileTag}${buildSourceFile(idx)}
${SourceFileCovData.linesFoundTag}${idx + 1}
${SourceFileCovData.linesHitTag}$idx
${SourceFileCovData.endOfRecordTag}''';
  Iterable<SourceFileCovData> buildSourceFilesCovData() => Iterable.generate(
        sourceFilesCount,
        (idx) => SourceFileCovData(
          raw: buildSourceFilesCovDataString(idx),
          sourceFile: buildSourceFile(idx),
          linesFound: idx + 1,
          linesHit: idx,
        ),
      );
  final tracefile = Tracefile(
    sourceFilesCovData: buildSourceFilesCovData(),
  );
  final tracefileString = Iterable.generate(
    sourceFilesCount,
    buildSourceFilesCovDataString,
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
        sourceFilesCovData: buildSourceFilesCovData(),
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
      // ARRANGE
      final expectedSourceFilesCovDataCollection = buildSourceFilesCovData();

      // ACT
      final result = tracefile.sourceFilesCovData;

      // ASSERT

      expect(result, isA<UnmodifiableListView<SourceFileCovData>>());
      expect(result.length, expectedSourceFilesCovDataCollection.length);
      expect(
        result,
        predicate<UnmodifiableListView<SourceFileCovData>>(
          (r) => r.foldIndexed(
            true,
            (idx, containSameElements, element) =>
                containSameElements &&
                element == expectedSourceFilesCovDataCollection.elementAt(idx),
          ),
        ),
      );
    },
  );

  test(
    '''

GIVEN a tracefile instance
WHEN its coverage percentage is requested
THEN its actual coverage value should be returned
''',
    () async {
      // ARRANGE
      const linesFound = (sourceFilesCount * (sourceFilesCount + 1)) / 2;
      const linesHit = linesFound - sourceFilesCount;
      const expectedCovPercentage = (linesHit * 100) / linesFound;

      // ACT
      final result = tracefile.coveragePercentage;

      // ASSERT
      expect(result, expectedCovPercentage);
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
      const expectedLinesHit = (sourceFilesCount * (sourceFilesCount - 1)) / 2;

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
      const expectedLinesFound =
          (sourceFilesCount * (sourceFilesCount + 1)) / 2;

      // ACT
      final result = tracefile.linesFound;

      // ASSERT
      expect(result, expectedLinesFound);
    },
  );
}
