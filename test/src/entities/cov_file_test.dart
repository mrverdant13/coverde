import 'package:coverde/src/entities/cov_file.dart';
import 'package:coverde/src/entities/cov_line.dart';
import 'package:coverde/src/entities/covfile_format.exception.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  // ARRANGE
  const sourcePath = 'path/to/source.file';
  final covLinesEntries = Iterable.generate(
    32,
    (idx) => MapEntry(idx + 1, idx + 1),
  );
  final rawCovFileData = '''
SF:$sourcePath
${covLinesEntries.map((covLineEntry) => 'DA:${covLineEntry.key},${covLineEntry.value}').join('\n')}''';
  final covLines = covLinesEntries.map(
    (covLineEntry) => CovLine(
      lineNumber: covLineEntry.key,
      hitsNumber: covLineEntry.value,
      checksum: null,
    ),
  );
  final covFile = CovFile(
    source: File(sourcePath),
    raw: rawCovFileData,
    covLines: covLines,
  );

  test(
    '''

GIVEN two file coverage data instances
├─ THAT hold the same data
WHEN they are compared with each other
THEN a positive result should be returned
''',
    () {
      final sameCovFile = CovFile(
        source: File(sourcePath),
        raw: rawCovFileData,
        covLines: covLines,
      );

      // ACT
      final valueComparisonResult = covFile == sameCovFile;
      final hashComparisonResult = covFile.hashCode == sameCovFile.hashCode;

      // ASSERT
      expect(valueComparisonResult, isTrue);
      expect(hashComparisonResult, isTrue);
    },
  );

  test(
    '''

GIVEN a valid string representation of a file coverage data
WHEN the string is parsed
THEN a file coverage data instance should be returned
''',
    () async {
      // ACT
      final result = CovFile.parse(rawCovFileData);

      // ASSERT
      expect(result, covFile);
    },
  );

  test(
    '''

GIVEN an invalid string representation of a file coverage data
WHEN the string is parsed
THEN an exception should be thrown
''',
    () async {
      // ARRANGE
      const rawCovFileString = '''
DA:1,3
DA:3,5''';

      // ACT
      void action() => CovFile.parse(rawCovFileString);

      // ASSERT
      expect(action, throwsA(isA<CovfileFormatException>()));
    },
  );
}
