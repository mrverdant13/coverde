import 'dart:io';

import 'package:coverde/src/commands/check/min_coverage.exception.dart';
import 'package:coverde/src/entities/tracefile.dart';
import 'package:test/test.dart';

void main() {
//   group('''

// GIVEN a minimum coverage exception
// ├─ THAT includes a minimum coverage value
// ├─ AND holds a tracefile''', () {
  test(
    '''
GIVEN a minimum coverage exception
├─ THAT includes a minimum coverage value
├─ AND holds a tracefile
WHEN its string representation is requested
THEN a string holding the exception details should be returned
├─ BY including the expected coverage value
├─ AND including the actual coverage value
''',
    () {
      // ARRANGE
      const minCoverage = 40;
      const tracefileFilePath = 'test/fixtures/check/lcov.info';
      final tracefileFile = File(tracefileFilePath);
      final tracefile = Tracefile.parse(tracefileFile.readAsStringSync());
      final exception = MinCoverageException(
        minCoverage: minCoverage,
        tracefile: tracefile,
      );

      // ACT
      final result = exception.toString();

      // ASSERT
      expect(
        result.contains('Expected min coverage: $minCoverage'),
        isTrue,
      );
      expect(
        result.contains('Actual coverage: ${tracefile.coverageString}'),
        isTrue,
      );
    },
  );
  // },);
}
