import 'package:coverde/src/entities/cov_line.dart';
import 'package:test/test.dart';

void main() {
  test(
    '''

GIVEN two instances of coverage lines
├─ THAT hold the same data
WHEN they are compared with each other
THEN a positive result should be returned
''',
    () {
      // ARRANGE
      const lineNumber = 10;
      const hitsNumber = 24;
      final sourceFileCovData = CovLine(
        lineNumber: lineNumber,
        hitsNumber: hitsNumber,
        checksum: null,
      );
      final sameSourceFileCovData = CovLine(
        lineNumber: lineNumber,
        hitsNumber: hitsNumber,
        checksum: null,
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

  for (final hasLineDataTag in [true, false]) {
    test(
      '''

GIVEN a valid string representation of a coverage line
├─ THAT ${hasLineDataTag ? 'starts' : 'does not start'} with the line data tag
WHEN the string is parsed
THEN a source file coverage data instance should be returned
''',
      () async {
        // ARRANGE
        const lineNumber = 43;
        const hitsNumber = 64;
        final covLineString =
            '${hasLineDataTag ? 'DA:' : ''}$lineNumber,$hitsNumber';
        final expectedCovLine = CovLine(
          lineNumber: lineNumber,
          hitsNumber: hitsNumber,
          checksum: null,
        );

        // ACT
        final result = CovLine.parse(covLineString);

        // ASSERT
        expect(result, expectedCovLine);
      },
    );
  }
}
