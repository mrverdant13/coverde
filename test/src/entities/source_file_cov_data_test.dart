import 'package:cov_utils/src/entities/source_file_cov_data.dart';
import 'package:test/test.dart';

void main() {
  // ARRANGE
  const sourceFile = 'lib/a_file.dart';
  const linesFound = 4;
  const linesHit = 3;
  String buildSourceFileCovDataString({
    required int linesFound,
    required int? linesHit,
    required bool hideLinesHit,
  }) {
    final linesHitValue = linesHit != null ? '$linesHit' : '';
    final linesHitLine = '${SourceFileCovData.linesHitTag}$linesHitValue';
    return '''
${SourceFileCovData.sourceFileTag}$sourceFile
${SourceFileCovData.linesFoundTag}$linesFound
${hideLinesHit ? '' : linesHitLine}
${SourceFileCovData.endOfRecordTag}''';
  }

  final rawSourceFileCovData = buildSourceFileCovDataString(
    linesFound: linesFound,
    linesHit: linesHit,
    hideLinesHit: false,
  );
  final sourceFileCovData = SourceFileCovData(
    raw: rawSourceFileCovData,
    sourceFile: sourceFile,
    linesFound: linesFound,
    linesHit: linesHit,
  );

  test(
    '''

GIVEN two source file data instances
├─ THAT hold the same data
WHEN they are compared with each other
THEN a positive result should be returned
''',
    () {
      // ARRANGE
      final sameSourceFileCovData = SourceFileCovData(
        raw: rawSourceFileCovData,
        sourceFile: sourceFile,
        linesFound: linesFound,
        linesHit: linesHit,
      );

      // ACT
      final valueComparisonResult = sourceFileCovData == sameSourceFileCovData;
      final hashComparisonResult =
          sourceFileCovData.hashCode == sameSourceFileCovData.hashCode;

      // ASSERT
      expect(valueComparisonResult, isTrue);
      expect(hashComparisonResult, isTrue);
    },
  );

  test(
    '''

GIVEN a valid string representation of a source file coverage data
WHEN the string is parsed
THEN a source file coverage data instance should be returned
''',
    () async {
      // ARRANGE
      final sourceFileCovDataString = buildSourceFileCovDataString(
        linesFound: linesFound,
        linesHit: linesHit,
        hideLinesHit: false,
      );

      // ACT
      final result = SourceFileCovData.parse(
        sourceFileCovDataString,
      );

      // ASSERT
      expect(result, sourceFileCovData);
    },
  );

  test(
    '''

GIVEN an invalid string representation of a source file coverage data
├─ THAT does not include the hit lines number
WHEN the string is parsed
THEN an error indicating the issue should be thrown
''',
    () async {
      // ARRANGE
      final sourceFileCovDataString = buildSourceFileCovDataString(
        linesFound: linesFound,
        linesHit: linesHit,
        hideLinesHit: true,
      );

      // ACT
      SourceFileCovData action() => SourceFileCovData.parse(
            sourceFileCovDataString,
          );

      // ASSERT
      expect(action, throwsA(isA<StateError>()));
    },
  );

  test(
    '''

GIVEN an invalid string representation of a source file coverage data
├─ THAT does include the hit lines tag but not the number
WHEN the string is parsed
THEN an error indicating the issue should be thrown
''',
    () async {
      // ARRANGE
      final sourceFileCovDataString = buildSourceFileCovDataString(
        linesFound: linesFound,
        linesHit: null,
        hideLinesHit: false,
      );

      // ACT
      SourceFileCovData action() => SourceFileCovData.parse(
            sourceFileCovDataString,
          );

      // ASSERT
      expect(action, throwsA(isA<ArgumentError>()));
    },
  );

  test(
    '''

GIVEN an invalid string representation of a source file coverage data
├─ THAT includes the hit lines number greater than the found lines number
WHEN the string is parsed
THEN an error indicating the issue should be thrown
''',
    () async {
      // ARRANGE
      final sourceFileCovDataString = buildSourceFileCovDataString(
        linesFound: linesFound,
        linesHit: linesFound + 1,
        hideLinesHit: false,
      );

      // ACT
      SourceFileCovData action() => SourceFileCovData.parse(
            sourceFileCovDataString,
          );

      // ASSERT
      expect(action, throwsA(isA<RangeError>()));
    },
  );

  test(
    '''

GIVEN a source file coverage data instance
WHEN its coverage percentage is requested
THEN its actual coverage value should be returned
''',
    () async {
      // ARRANGE
      const expectedCovPercentage = (linesHit * 100) / linesFound;

      // ACT
      final result = sourceFileCovData.coveragePercentage;

      // ASSERT
      expect(result, expectedCovPercentage);
    },
  );
}
