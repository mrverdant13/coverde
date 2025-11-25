import 'package:coverde/src/entities/cov_file.dart';
import 'package:coverde/src/entities/cov_file_format.exception.dart';
import 'package:coverde/src/entities/cov_line.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  group('$CovFile', () {
    // ARRANGE
    final sourcePath = path.joinAll(['path', 'to', 'source.file']);
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
      '| supports value comparison',
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
      '| parses valid string representation',
      () async {
        // ACT
        final result = CovFile.parse(rawCovFileData);

        // ASSERT
        expect(result, covFile);
      },
    );

    test(
      '| throws exception when parsing invalid string representation',
      () async {
        // ARRANGE
        const rawCovFileString = '''
DA:1,3
DA:3,5''';

        // ACT
        void action() => CovFile.parse(rawCovFileString);

        // ASSERT
        expect(action, throwsA(isA<CovFileFormatException>()));
      },
    );
  });
}
